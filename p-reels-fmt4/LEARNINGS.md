# p-reels-fmt4 Learnings

> This file is the self-learning loop for `p-reels-fmt4`. Before executing this skill, the agent reads this file and applies all accumulated `Active Feedback`. After execution, the agent asks the user for feedback and appends it here.

---

## Active Feedback (apply on every run)

- `[ACTIVE]` **Scene sequencing is mandatory — one text beat visible at a time.** Inherited from the
  p-hf-reel certification (2026-06-02): a live render stacked EVERY text beat on screen
  simultaneously because the scenes had no explicit clip timing. In fmt4 the default architecture
  (one composition per beat, concatenated) enforces this between beats — do NOT lump all beats into
  one untimed composition. Within a beat, later elements start hidden (`autoAlpha: 0`) and are
  revealed by their entrance tween. See Step 4 § "Scene sequencing — MANDATORY".
- `[ACTIVE]` **All media must be downloaded local — never reference remote URLs.** Inherited from
  the p-hf-reel certification: remote `http(s)://` URLs inside compositions silently fail to load
  in the headless render and come out blank. `curl -L` + ffprobe every asset first; reference only
  local relative paths. See Step 4 § "Local media — MANDATORY".
- `[ACTIVE]` **Visual QA Gate is mandatory — actually LOOK at the frames AND prove motion.** Both
  failure classes above are invisible to ffprobe. After every render: extract 6 frames
  (5/20/40/60/80/95% of duration), READ each with vision (no overlapping text, brand graphics not
  photos/blanks, legible, on-brand colors), AND run the per-beat two-frame PSNR motion proof
  (finite dB = motion; `inf` = a frozen still = FAIL). Fix and re-render until everything passes.
  NEVER upload an unlooked-at reel. See Step 8.
- `[ACTIVE]` **Always upload to R2 and print the URL as the final line.** The production-worker
  recovers the deliverable by scraping the reply text for an R2/CDN media URL. A perfect render
  left on local disk = the job FAILS as "finished without producing an asset". See Step 9.
- `[ACTIVE]` **Visual identity comes from the BRAND, never from this skill or the brief.** Resolve
  via the Visual Identity Gate (Brand Brief → DESIGN.md → named style → dark-premium default). The
  old hard-coded MGG navy/green palette was removed from this skill in v4.1.0 — do not resurrect it.
  If the brand's display font does not auto-resolve in the HyperFrames compiler (e.g. Barlow
  Condensed), substitute the closest auto-resolving face (Oswald) and report the substitution.

---

## Feedback Log

### 2026-06-02 — Gates ported from the p-hf-reel certification (pre-round-1 of 05-CERT-FMT4)
- Ported the 3 mandatory gates hardened during p-hf-reel's certification (scene sequencing, local
  media, 6-frame Visual QA Gate) plus two fmt4-specific additions: the per-beat proof-of-motion
  PSNR check folded into the QA gate (this format's certification criterion is that every beat
  genuinely animates), and a new Step 9 R2-upload requirement (fmt4 previously ended at a local
  file, which fails in the production-worker flow).
- Replaced the hard-coded MGG navy/green palette with the Brand-Brief-driven Visual Identity Gate
  (protocol learning #1: information flows from the brand, never from briefs or skills).
- No certification rounds run yet — this is the pre-round-1 hardening required by 05-CERT-FMT4.

### 2026-05-27 — v4 created
- v4 fixed the v3 still+Ken-Burns failure; verified end-to-end on the MGG "Top 20 Claude Code
  Skills" listicle (44.1s, 7 compositions, proof-of-motion PSNR finite).
