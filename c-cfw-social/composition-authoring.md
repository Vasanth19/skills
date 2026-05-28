# CFW Social — Composition Authoring Contract (for the calling agent)

How an agent (cfw-agent, or any external runtime) should create **compositions** so
they render and publish correctly: the right media sizes per platform, reel specs,
and per-platform caption formatting.

> **Read this before calling `propose_composition`.** The API is a *thin writer* — it
> stores exactly what you give it and does **no** resizing, cropping, caption
> shaping, or platform reasoning. If you pass one caption and one image, that's all
> the owner sees. The intelligence below is **your** job, not the API's.

---

## 1. The mental model (updated 2026-05-27)

A Composition (dish) is **multi-platform by design** — one dish holds N `Output` rows,
each tagged `metadata.platform` + `metadata.caption`. The approval page and inbox group
outputs by platform into chips. "Approve all" fans out one `Post` per output.

| Reality | Consequence for you |
|---|---|
| `Composition.platform` is the **primary/scalar** platform | Back-compat field. Set to `platforms[0]`. Do not use alone to infer all platforms. |
| `Composition.captions` is `{ [platform]: caption }` | Full per-platform caption map on the Composition row. |
| `Composition.platformCaptions` is `[{ platform, caption }]` | Array form; both are written by `propose_composition`. |
| `Composition.runId` is `@unique` (1 Run ↔ 1 Composition) | ONE `propose_composition` call → ONE Composition. Pass all platforms in one call. |
| `propose_composition` creates **one Output per platform** | Each output tagged `metadata.platform`. The approval phone preview switches between them via the platform bar chips. |
| `Output.metadata.platform` drives the inbox + dish-rows | Always populate it — the `platforms` array on `DishRow` is derived from outputs, not from `Composition.platform`. |

**"One post for Instagram + LinkedIn" = ONE `propose_composition` call with `platforms: ["instagram","linkedin"]`** and per-platform captions in `platformCaptions`. This produces one dish with two platform chips. Approve All → two Posts.

---

## 2. The correct authoring sequence

1. **Generate platform-sized media first** (via `run_skill` — ffmpeg, `c-html-gfx`,
   `c-broll`, etc.). Resize/crop to the platform's aspect ratio from §3. Upload to R2.
   Do **not** hand the API a generic 1:1 image and expect it to reframe for a 9:16 reel.
2. **Call `propose_composition` once with ALL target platforms**:
   ```jsonc
   {
     "workspaceId": "ws_...",
     "format": "post",
     "platforms": ["instagram", "linkedin"],   // ALL platforms in one call
     "captionIntent": "Fallback caption if no override",
     "mediaUrls": ["https://r2.../image.jpg"],
     "platformCaptions": [                     // per-platform overrides (recommended)
       { "platform": "instagram", "caption": "IG caption with hashtags 🚀" },
       { "platform": "linkedin",  "caption": "LinkedIn professional tone." }
     ]
   }
   ```
   Returns `{ compositions: [{ compositionId, platform, revisionId, caption }, ...] }`.
   Every entry has the **same `compositionId`** — pass it once to `request_approval`.
3. **For a carousel / multi-image:** call `attach_output_to_composition` with the
   `compositionId` and **all** slide URLs (see §4). This is what makes >1 image render.
4. Call `request_approval` once with the single `compositionId` (one token → all platforms).

> **Do not** call `propose_composition` again to add an image to an existing dish —
> that creates a *new* composition. Use `attach_output_to_composition`.

### REST alternative (operator/script use, added 2026-05-27)

`POST /api/v1/workspaces/{workspaceId}/compositions` accepts the same body (minus
`workspaceId`) and returns `{ compositionId, platforms, outputs }`. Auth: brand API key
(`x-api-key`) or master key (`cfw-api-key` + `x-cfw-brand`). To replace two fragmented
compositions with one unified dish:

```bash
# 1. Create merged composition
curl -X POST ".../api/v1/workspaces/{wsId}/compositions" \
  -H "cfw-api-key: <master>" -H "x-cfw-brand: <brandId>" \
  -d '{"format":"post","platforms":["instagram","linkedin"],"platformCaptions":[...],"mediaUrls":[...]}'

# 2. Delete old single-platform compositions
curl -X DELETE ".../api/v1/compositions/{oldIgId}" -H "cfw-api-key: <master>" -H "x-cfw-brand: <brandId>"
curl -X DELETE ".../api/v1/compositions/{oldLiId}" -H "cfw-api-key: <master>" -H "x-cfw-brand: <brandId>"
```

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

## 5b. Text-only posts (no media)

A **text-only post** (`format: "post"`, no `mediaUrls`) is valid — the API sets `kind: "text"`, `mimeType: "text/plain"`, and `cdnUrl: ""`. The phone preview hides the media container entirely (no camera-placeholder box).

**Not every platform supports text-only.** The API enforces this at creation time:

| Platform | Text-only supported? | Notes |
|---|---|---|
| **X / Twitter** | ✅ Yes | Native text tweet |
| **LinkedIn** | ✅ Yes | Text post, org or personal |
| **Facebook** | ✅ Yes | Text status |
| **Threads** | ✅ Yes | Text thread |
| **Bluesky** | ✅ Yes | Text post |
| **Instagram** | ❌ No | Requires image or video — API rejects |
| **TikTok** | ❌ No | Video required |
| **YouTube** | ❌ No | Video required |
| **Pinterest** | ❌ No | Image required |

**What the API does when you send a media-required platform with no media:**
`propose_composition.ts` has a `PLATFORMS_REQUIRING_MEDIA` set (`instagram`, `tiktok`, `youtube`, `pinterest`). If `!hasMedia`:
- Those platforms are **silently dropped** from the Output creation loop.
- If *all* requested platforms are media-required and there's no media → returns `error: "media_missing"` telling the agent to generate media first.
- If at least one text-capable platform remains → proceeds normally with just those platforms.

Rule for agents: **never include Instagram/TikTok/YouTube/Pinterest in `platforms[]` for a text-only post.** Filter them before calling the tool.

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
- [ ] If text-only (no media), **only include text-capable platforms** (X, LinkedIn, Facebook, Threads, Bluesky) — Instagram/TikTok/YouTube/Pinterest require media (§5b).
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
