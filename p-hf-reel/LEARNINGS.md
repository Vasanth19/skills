# p-hf-reel Learnings

> This file is the self-learning loop for `p-hf-reel`. Before executing this skill, the agent reads this file and applies all accumulated `Active Feedback`. After execution, the agent asks the user for feedback and appends it here.

> **certified: 2026-06-04** — owner-approved. This was the TEMPLATE cert (it established the
> 05-CERT-PROTOCOL on 2026-06-02): round 1 surfaced the scene-overlap + missing-b-roll failures,
> which became the scene-sequencing, local-media, and 6-frame Visual QA gates below. Owner signed off
> after review. Also benefits from the two platform fixes shipped during the FMT4 cert (specialist
> model → kimi-k2.6; worker validates the result URL resolves before marking a job done).

---

## Active Feedback (apply on every run)

- `[ACTIVE]` **Scene sequencing is mandatory — one text beat visible at a time.** A live render
  (screenshot-verified) stacked EVERY text beat on screen simultaneously ("YOU ARE ALREADY MOVING"
  jumbled over "YOUR COMPETITION SKIPPED THIS") because the scenes had no explicit clip timing.
  Each text beat MUST be its own timed scene (`data-start` + `data-duration`), consecutive beats on
  the SAME `data-track-index` so the framework forbids overlap, every non-first scene hidden until
  its entrance lands on its VO phrase timecode. See Step 2 § "Scene sequencing — MANDATORY".
- `[ACTIVE]` **B-roll must be downloaded local — never reference remote URLs.** The same render
  supplied 2 b-roll URLs that NEVER appeared because the composition pointed `<video src>` at the
  remote URLs, which don't load in the headless browser render. Always `curl -L -o broll_N.mp4`
  each clip first, ffprobe it, and reference ONLY the local relative path. B-roll scenes are
  full-bleed video + `rgba(15,23,42,0.55)` overlay; trim the scene window to the clip duration if
  the clip is shorter (never freeze-frame). See Step 2 § "B-roll handling — MANDATORY".
- `[ACTIVE]` **Visual QA Gate is mandatory — actually LOOK at the frames.** Both failures above are
  invisible to ffprobe. After every render, extract 6 frames (5/20/40/60/80/95% of duration), READ
  each with vision, and verify no overlapping text + b-roll actually visible + legible + correct
  brand colors. Fix and re-render until all 6 pass. NEVER upload an unlooked-at reel. See Step 5.

---

## Feedback Log

### 2026-06-02 — Live render incident: scenes overlapped + b-rolls missing
- A real render (screenshot-verified by the owner) failed two ways at once: (1) ALL text scenes
  rendered simultaneously — beats from different scenes stacked/jumbled on top of each other —
  because the composition lacked proper scene sequencing (no per-beat `data-start`/`data-duration`
  clip timing / GSAP autoAlpha sequencing); (2) the 2 supplied b-roll clips NEVER appeared because
  the composition referenced the remote URLs directly, which don't load in the headless render.
- Both are now mandatory gates in the skill: Step 2 "Scene sequencing — MANDATORY" (one beat
  visible at a time, same-track non-overlap, hidden initial state, SRT-mapped windows) + Step 2
  "B-roll handling — MANDATORY" (download local, full-bleed + dark overlay, trim-to-clip) +
  Step 5 "Visual QA Gate — MANDATORY" (read 6 sample frames with vision before upload). Three new
  anti-patterns added (no overlapping beats, no remote media URLs, never skip the Visual QA Gate).

### 2026-06-02 — Initial template
- Skill created. No feedback yet.
