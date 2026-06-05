# LEARNINGS — p-gfx-carousel

## Active Feedback
<!-- [ACTIVE]-prefixed items here are non-negotiable rules applied on every run. -->

- [ACTIVE] Render ALL slides in ONE `render-carousel.mjs` invocation. Never
  screenshot slides one at a time — that burns the step budget and ships a
  cover-only "carousel" (the exact loop this skill was built to kill, MGG
  7-slide carousel, 2026-06-04).
- [ACTIVE] This skill is NON-INTERACTIVE. It runs off-turn in the production
  worker. Never stop to ask for outline/slide approval.
- [ACTIVE] End the reply with every slide URL plainly, one per line, in order.
  The worker scrapes R2 URLs from the reply — missing URLs = dropped slides.

## Log

### 2026-06-04 — created
Built to fix carousels looping in production: the old path had no autonomous
multi-slide renderer (p-linkedin-carousel is a checkpoint-gated PDF flow;
c-gfx-batch has interactive review gates), so the production specialist
freelanced and only ever produced the cover. This skill renders N PNG slides
deterministically (headless chromium → R2) in a single pass.
