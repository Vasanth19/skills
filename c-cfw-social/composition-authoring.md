# CFW Social — Composition Authoring Contract (for the calling agent)

How an agent (cfw-agent, or any external runtime) should create **compositions** so
they render and publish correctly: the right media sizes per platform, reel specs,
and per-platform caption formatting.

> **Read this before calling `propose_composition`.** The API is a *thin writer* — it
> stores exactly what you give it and does **no** resizing, cropping, caption
> shaping, or platform reasoning. If you pass one caption and one image, that's all
> the owner sees. The intelligence below is **your** job, not the API's.

---

## 1. The mental model the API actually enforces (today)

The data model is **one platform per Composition**, not one dish fanned across platforms.

| Reality | Consequence for you |
|---|---|
| `Composition.platform` is a **scalar string** | One composition = one platform. There is no multi-platform composition. |
| `Composition.runId` is `@unique` (1 Run ↔ 1 Composition) | **Never pass >1 platform to a single `propose_composition` call** — it creates the first composition, then throws a unique-constraint error on the second. |
| `propose_composition` creates exactly **one `Output`** with `cdnUrl = mediaUrls[0]` | Extra images in `mediaUrls` are **dropped from the preview**. A carousel needs one `Output` per slide (see §4). |
| `captions` is stored as `{ [platform]: captionIntent }`; `platformCaptions[]` is **not** populated | The single `captionIntent` string is the whole caption. Shape it per platform yourself. |

**So "one post for Instagram + Facebook + TikTok" is N separate compositions, one per
platform** — that is the current design, not a bug to route around. Give each platform
its own correctly-sized media and its own correctly-formatted caption.

---

## 2. The correct authoring sequence

For each platform you're publishing to:

1. **Generate platform-sized media first** (via `run_skill` — ffmpeg, `c-html-gfx`,
   `c-broll`, etc.). Resize/crop to the platform's aspect ratio from §3. Upload to R2.
   Do **not** hand the API a generic 1:1 image and expect it to reframe for a 9:16 reel.
2. **Call `propose_composition` once for that platform**:
   ```jsonc
   {
     "workspaceId": "ws_...",
     "format": "post",                 // post | carousel | reel | story | thread | multi_image
     "platforms": ["instagram"],       // EXACTLY ONE — never a list
     "captionIntent": "<caption already formatted for Instagram>",
     "mediaUrls": ["https://r2.../ig-1080x1350.jpg"]   // first/cover image
   }
   ```
   It returns `{ compositions: [{ compositionId, platform, revisionId, caption }] }`.
3. **For a carousel / multi-image:** call `attach_output_to_composition` with the
   `compositionId` and **all** slide URLs (see §4). This is what makes >1 image render.
4. Repeat 1–3 per platform, then `request_approval` with each `compositionId`
   (dish-scoped approval).

> **Do not** call `propose_composition` again to add an image to an existing dish —
> that creates a *new* composition. Use `attach_output_to_composition` (its description
> says exactly this).

---

## 3. Image sizes & aspect ratios by platform

Produce media at these dimensions **before** attaching. The preview phone and the
publisher pass URLs straight through — wrong aspect ratio = cropped/letterboxed post.

| Platform | Feed image | Portrait (preferred) | Story / Reel / vertical | Aspect notes |
|---|---|---|---|---|
| **Instagram** | 1080×1080 (1:1) | **1080×1350 (4:5)** | 1080×1920 (9:16) | 4:5 wins most feed real estate. Carousel: **all slides same aspect**. |
| **Facebook** | 1080×1080 (1:1) | 1080×1350 (4:5) | 1080×1920 (9:16) | Link previews 1200×630 (1.91:1). |
| **LinkedIn** | 1200×627 (1.91:1) | 1080×1080 (1:1) | — | Carousels = uploaded **PDF** ("document post"), not image slides. |
| **X / Twitter** | 1600×900 (16:9) | 1080×1080 (1:1) | — | In-stream crops to 16:9; design safe-area centered. |
| **TikTok** | — | — | **1080×1920 (9:16)** | Video only. No still-image posts. |
| **YouTube** | 1920×1080 (16:9) regular | — | **1080×1920 (9:16) Shorts** | Thumbnail 1280×720. |
| **Threads** | 1080×1080 (1:1) | 1080×1350 (4:5) | 1080×1920 (9:16) | Mirrors Instagram. |
| **Pinterest** | — | **1000×1500 (2:3)** | — | 2:3 strongly preferred. |
| **Bluesky** | 1200×675 (16:9) | 1080×1080 (1:1) | — | Mirrors X. |
| **Google Business** | 1200×900 (4:3) | — | — | 1 image. |

Rule of thumb: **1080px on the short edge minimum**, JPEG/PNG, sRGB.

### ⚠️ Media URLs must be on the CSP allowlist

The approval/preview pages enforce a Content-Security-Policy `img-src` allowlist. An
image on any other host is **silently blocked** and shows as a broken placeholder —
this is a top cause of "media not showing up." Allowed image hosts:

```
'self'  data:  blob:
https://*.r2.dev
https://*.r2.cloudflarestorage.com
https://*.cdn.cloudflare.net
https://media.cfw.social
https://i.ytimg.com   https://*.ytimg.com
```

**Always upload generated media to R2 first and pass the R2 / `media.cfw.social` URL.**
Never pass an arbitrary third-party image URL (stock sites, picsum, hot-linked CDNs) —
it will be blocked by CSP even though the composition saves fine. (Verified live
2026-05-27: a `picsum.photos` URL saved correctly but rendered as a broken image; the
identical flow with a `media.cfw.social` URL rendered the full carousel.)

---

## 4. Carousels & multi-image — the part that silently breaks

The preview renders a swipeable gallery by collecting `cdnUrl` from **every `Output`**
tagged to the same platform/composition (`RowPreview.tsx` `buildPreviewOutputs`). So:

- `propose_composition` makes **one** Output → only slide 1 shows. ❌
- You must add the remaining slides as their own Outputs.

**Correct carousel flow:**
```jsonc
// 1. Create the dish (cover slide as the first Output)
propose_composition {
  "workspaceId": "ws_...", "format": "carousel", "platforms": ["instagram"],
  "captionIntent": "<ig caption>", "mediaUrls": ["https://r2/.../slide-1.jpg"]
}
// → returns compositionId "cmp_abc"

// 2. Attach the rest as separate Outputs (one per slide URL)
attach_output_to_composition {
  "compositionId": "cmp_abc",
  "mediaIds": [
    "https://r2/.../slide-2.jpg",
    "https://r2/.../slide-3.jpg",
    "https://r2/.../slide-4.jpg"
  ]
}
// At ≥2 image Outputs the API auto-sets Composition.type = "carousel"
// and it renders as a swipeable multi-image post — no extra flag needed.
```

- All slides **must share the same aspect ratio** (Instagram crops the whole carousel
  to slide 1's ratio).
- Caption is **one caption for the whole carousel** — set it on `captionIntent`, not per slide.
- Max **10** slides (Instagram/Facebook/Threads); X = 4; LinkedIn carousel = a PDF, not slides.

---

## 5. Reels / short-form video

When `format: "reel"`, the API only sets `kind: "video"`, `mimeType: "video/mp4"`. It
does **not** validate or transcode. Produce the video to spec **before** attaching:

| Spec | Value |
|---|---|
| Aspect / resolution | **9:16, 1080×1920** |
| Container / codec | MP4, H.264 video + AAC audio |
| Frame rate | 30 fps (24/60 acceptable) |
| Duration | Instagram Reels 15–90s · TikTok 15s–10min · YouTube Shorts ≤60s |
| Audio | Always include an audio track (silent reels get suppressed) |
| Cover frame | Provide a 1080×1920 cover image as the first attached Output if a custom thumbnail is wanted |
| Safe area | Keep text/logos clear of the bottom ~250px and right ~120px (UI overlays) |

Pass the single video URL in `propose_composition.mediaUrls` (one Output is correct for
a reel — it's not a gallery). Use `attach_output_to_composition` only to add a separate
**cover image** Output if needed.

---

## 6. Captions — format per platform, then send

Send the **already-formatted** caption as `captionIntent`. The API does no trimming or
hashtag handling. One `propose_composition` call = one platform = one caption.

| Platform | Caption limit | Hashtags | Links | Style |
|---|---|---|---|---|
| **Instagram** | 2,200 | 3–5 (max 30); end of caption or first comment | **Not clickable** — say "link in bio" | Hook in first line (feed truncates ~125 chars). Line breaks fine. |
| **Facebook** | 63,206 | 1–2 | Clickable | Conversational; short performs better despite the limit. |
| **LinkedIn** | 3,000 | 3–5 inline | Clickable (but in-comment links rank better) | Whitespace/line breaks reward dwell time. Professional tone. |
| **X / Twitter** | 280 (4,800 premium) | 1–2 | Clickable (counts ~23 chars) | Terse. For long-form use a thread via `r-x-thread`. |
| **TikTok** | 2,200 | 3–5 trend tags | Not clickable | Punchy hook; tags drive discovery. |
| **YouTube** | 5,000 (desc); title 100 | In description | Clickable | First 2 lines show above the fold. |
| **Threads** | 500 | 1–3 | Clickable | Short, conversational. |
| **Pinterest** | 500 | 2–3 | Clickable | Keyword-rich (SEO surface). |
| **Bluesky** | 300 | 1–2 | Clickable | Terse like X. |
| **Google Business** | 1,500 | Avoid | Clickable + CTA button | Local/offer framing. |

Practical rules when shaping `captionIntent`:
- **Trim to the platform limit** yourself — the API will store an over-limit string and
  the publisher will reject it at post time.
- **Lead with the hook** — IG/TikTok/YouTube truncate above the fold.
- **No clickable links on Instagram/TikTok** — route to "link in bio".
- **Match the dish type** — a reel caption is a hook, not the full essay; a LinkedIn
  post can carry the long-form body.

---

## 7. Quick checklist before `request_approval`

- [ ] One `propose_composition` call **per platform** (never a platform list).
- [ ] Media pre-sized to the platform's aspect ratio (§3) and uploaded to **R2 / media.cfw.social** (CSP-allowlisted host — see §3 warning).
- [ ] Carousel slides each attached as their own Output via `attach_output_to_composition` (§4).
- [ ] Reels are 9:16 1080×1920 H.264 MP4 with audio (§5).
- [ ] Caption formatted + length-trimmed for that specific platform (§6).
- [ ] `request_approval` called with each returned `compositionId`.

---

## Known API limitations (file as backlog if they block you)

These live in `cfw-social/src/lib/openclaw/tools/propose-composition.ts`:

1. **No multi-platform composition.** `platform` is scalar + `runId` is `@unique`, so
   one dish can't span platforms. A true "one dish → many platform variants" model
   would need a schema change (platform set / child rows) — out of scope here.
2. **`mediaUrls[1..]` is dropped** by `propose_composition` (only `[0]` becomes an
   Output). Use `attach_output_to_composition` for the rest.
3. **No per-platform caption fan-out.** `platformCaptions[]` exists in the schema but is
   never written by the MCP tools — captions are per-composition (i.e. per-platform
   because the composition is per-platform).
4. **No server-side resize/transcode.** All sizing/format work is the agent's.

## See also

- `data-model.md` — `Composition` / `Output` field glossary
- `workspace-operations.md` — composition types × platforms, platform constraint table
- `publishing.md` — how approved compositions become Posts and publish
- `c-cfw-agent` skill — the MCP tools (`propose_composition`, `attach_output_to_composition`, `request_approval`)
