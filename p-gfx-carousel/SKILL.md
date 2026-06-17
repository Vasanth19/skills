---
name: p-gfx-carousel
description: Render a swipeable multi-slide IMAGE carousel — N separate brand-styled 1080×1350 PNG slides (cover → content → CTA) for Instagram/LinkedIn. Renders ALL slides in one deterministic pass via headless chromium and uploads each to R2. Trigger on "carousel", "carousel post", "swipe post", "X-slide carousel", "Instagram carousel", "LinkedIn carousel".
when-to-use: Use when the user wants a multi-slide swipeable image carousel (2–10 ordered slides delivered as separate images). NOT for a single graphic (use p-gfx-image-posts) and NOT for a PDF document carousel (use p-linkedin-carousel).
version: 1.0.0
kind: pipeline
visibility: deprecated
deprecated: true
supersededBy: p-carousel
produces:
  dish: Image Carousel
  format: 1080×1350 PNG slides (2–10)
  duration: n/a
inputs: [brief]
dependsOn: [c-html-gfx, c-cloud-media]
---

> # ⛔ DEPRECATED (2026-06-16) — use **`p-carousel`**
> `p-carousel` is the unified carousel recipe: it builds slides as AI image (`c-ai-media`),
> HTML-GFX (`c-html-gfx`), or **HyperFrames** (`f-hyperframes`) — or a mix — and assembles a
> carousel/PDF. This HTML-GFX-PNG-only recipe is superseded; kept for reference only. Do not
> use for new work.

# pipeline-gfx-carousel — Multi-Slide Image Carousel

Produces a swipeable carousel as **N separate PNG slides** (one image per slide),
rendered from HTML by headless chromium and uploaded to R2. The deliverable is the
ordered list of slide URLs — the production worker forwards every URL so the
Director can assemble a `format:"carousel"` composition (one post, N images).

> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, summarize any feedback into 1–3 bullet points and
>    append to `LEARNINGS.md` with today's date (do NOT pause to ask — this runs
>    unattended inside the production worker).

> **⚠️ NON-INTERACTIVE — NO CHECKPOINTS.** This skill runs OFF-TURN in the
> production worker; there is no user watching to approve an outline or review
> slides mid-render. NEVER stop to ask for approval. Build the spec, render every
> slide, upload, and print the URLs in one unbroken pass. A half-rendered
> "carousel" (cover only) is the exact failure this skill exists to kill.

## Why one script, not slide-by-slide

Rendering slides one at a time burns the agent's step budget and ships a 1-of-N
carousel (the cover), which the worker then loops on forever. So you do NOT
screenshot slides yourself. You produce ONE JSON spec and run ONE script that
renders + uploads **all** slides. That is the whole job.

## Step 1 — Build the slide spec

From the production brief, write the carousel as a JSON file at
`/tmp/carousel-spec.json`. Map the brief's per-slide content onto this shape
(keep author text verbatim where the brief gives exact copy):

```json
{
  "size":  { "w": 1080, "h": 1350 },
  "theme": {
    "bg": "#0F172A",
    "accent": "#F97316",
    "text": "#FFFFFF",
    "titleFont": "'Barlow Condensed', sans-serif",
    "labelFont": "'JetBrains Mono', monospace"
  },
  "slides": [
    {
      "kind": "cover",
      "eyebrow": "MOST COMPANIES ARE DOING THIS WRONG",
      "headline": "MOST PRODUCTS FAIL BEFORE THEY SHIP",
      "accentWords": ["FAIL"],
      "body": "Not because of talent. Because of fragmented decisions and feedback loops too slow for the market.",
      "ghost": "FAIL",
      "glow": "center"
    },
    {
      "kind": "content",
      "eyebrow": "STAGE 01 — DECIDE",
      "headline": "DECIDE WITH CONVICTION, NOT GUT FEEL",
      "body": "AI processes millions of voice-of-consumer signals in real time.",
      "stat": "91% of product failures trace back to misreading market needs.",
      "ghost": "DECIDE",
      "glow": "bottom-right"
    },
    {
      "kind": "hero",
      "eyebrow": "THE REAL UNLOCK",
      "headline": "THE MULTIPLIER IS THE INTEGRATION LAYER",
      "body": "When the stages talk to each other, data silos break.",
      "nodes": ["DECIDE", "DEVELOP", "SCALE", "SUSTAIN"],
      "ghost": "INTEGRATE",
      "glow": "center"
    },
    {
      "kind": "cta",
      "eyebrow": "SAVE THIS",
      "headline": "WHICH STAGE IS YOUR BOTTLENECK?",
      "body": "Save this framework. Comment your stage — I'll share the AI tools that fix it.",
      "footer": "Mr. Growth Guide"
    }
  ]
}
```

**Field guide** (every field except `headline` is optional):

| Field | Meaning |
|-------|---------|
| `kind` | `cover` \| `content` \| `hero` \| `cta`. Defaults: slide 1 → cover, last → cta, else content. Drives layout (cover = oversized headline; cta drops the ghost layer). |
| `eyebrow` | Small mono uppercase label (accent-colored). |
| `headline` | The slide's main line (rendered condensed-900 uppercase). |
| `accentWords` | Words inside `headline` to paint in the accent color. |
| `body` | Supporting sentence(s). |
| `stat` | Optional accent-bordered stat callout. |
| `nodes` | Optional array → a horizontal `A → B → C` node flow (use on the hero/integration slide). |
| `ghost` | Optional huge faint background keyword. |
| `glow` | Radial glow position: `top-left`, `top-right`, `center`, `center-right`, `bottom-left`, `bottom-center`, `bottom-right`. |
| `footer` | Brand lockup (use on the cta slide). |

Rules:
- **2–10 slides.** Instagram/LinkedIn carousels cap at 10; the renderer refuses more.
- Honor the brief's visual identity (`bg`, `accent`, fonts) via `theme`.
- Don't invent slides the brief didn't ask for; don't drop slides it did.

## Step 2 — Render + upload ALL slides (one command)

```bash
node "$(dirname "$0")/scripts/render-carousel.mjs" <BRAND_ID> <TASK_ID> /tmp/carousel-spec.json
```

- `<BRAND_ID>` — the **Brand slug** from the brief (e.g. `cmpt8h9bt000004gvjhe1bnms`).
- `<TASK_ID>` — the production task id if the brief carries one, else `carousel-$(date +%s)`.
- The script writes each slide's HTML, screenshots it at exactly 1080×1350 with
  headless chromium, uploads each PNG to R2 at
  `<BRAND_ID>/carousels/<TASK_ID>/slide-NN.png`, and prints every public URL.
- If ANY slide fails to render or upload, the script exits non-zero. Do NOT
  paper over it — report the failure plainly so the worker fails the job rather
  than shipping a partial carousel.

Find the skill directory first if `$0` isn't set in your shell context:
```bash
SKILL_DIR=$(dirname "$(find /home/node/.claude/skills -name render-carousel.mjs -path '*p-gfx-carousel*' 2>/dev/null | head -1)")
node "$SKILL_DIR/render-carousel.mjs" <BRAND_ID> <TASK_ID> /tmp/carousel-spec.json
```

## Step 3 — Deliver

The script prints the slide URLs between `CAROUSEL_SLIDES_BEGIN` and
`CAROUSEL_SLIDES_END`. End your reply with those URLs **plainly, one per line,
in order** — nothing else around them. The worker scrapes every R2 URL from your
reply, so all N must appear or slides will be dropped from the carousel.

Example final reply:
```
Rendered 7 carousel slides.
https://media.cfw.social/<brand>/carousels/<task>/slide-01.png
https://media.cfw.social/<brand>/carousels/<task>/slide-02.png
... (all slides, in order) ...
```

**NEVER end the run without uploading.** A local file path is not a deliverable.
Echo a brief, a b-roll, or any input URL as the result and the carousel is wrong —
the result is the freshly rendered, uploaded slides and only those.
