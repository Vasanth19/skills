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
- `[ACTIVE]` **No unicode emoji / icon-font glyphs — they render as `□` tofu boxes.** The headless
  render has no emoji font. Every icon must be inline SVG / CSS shapes, never a character (📊 ✓ ✕ ▶ ⚡
  all fail; coverage is inconsistent so "it worked once" is unsafe). Round-1 cert shipped two empty
  boxes where icons should have been. See Step 4 § "ICONS — MANDATORY" + QA check (e).
- `[ACTIVE]` **Ghost glyph is a thematic number/letter, never a placeholder word.** Round-1 cert had
  a ghost that literally spelled "CTA" (a leaked layout label). Use the beat index / listicle total /
  a deliberate initial. See the GHOST GLYPH rule + QA check (f).
- `[ACTIVE]` **No beat may pop-in then freeze — continuous ambient motion for the whole window.**
  Round-1 cert had a beat sit frame-identical (PSNR ≈ 64 dB) for 2s after its entrance. Add a slow
  yoyo/breathe/drift that runs the full `data-duration`; stagger entrances later into the window. The
  Step 8 motion proof now FAILS a beat at ≥50 dB, not just `inf`. See AMBIENT MOTION rule.

- `[ACTIVE]` **The foreground content is the HERO — a beat that renders as only the ghost number is
  EMPTY.** Round-2 cert (real worker path, brand brief appended) shipped a reel where all 8 beats were
  nothing but the dim ghost number over the grid — no headlines, no diagrams — while the VO narrated
  into a blank screen. The Brand Brief styles the FRAME; it does not replace per-beat content. Author
  every foreground element with `gsap.from()` (ends visible), NEVER `set(hidden)`+`.to(reveal)` which
  leaves content invisible if the reveal mis-fires. QA check (g) fails any ghost-only frame. See the
  Visual doctrine HERO rule.
- `[ACTIVE]` **QA EVERY beat, never just beat1.** Round-2 proofed only beat1 and shipped 5 empty
  beats unseen. The Step 8 motion + foreground proof runs on every beat in the reel.

---

## Feedback Log

### 2026-06-03 — Round 2 certification render (real worker path: k2.6 + MGG brand brief)
- First render through the REAL production path (Remy on kimi-k2.6 → run_skill → worker-appended MGG
  Brand Brief). Confirmed working: brand fidelity (reel came out in MGG navy + orange/slate, proving
  the design-free-brief → on-brand requirement), thematic ghost numbers (5/01–05/3+, no "CTA"), no
  tofu boxes, real R2 upload that passes the new worker URL-validation.
- CRITICAL REGRESSION: **all beats rendered as background only** — the dim ghost number + grid + glow,
  zero foreground content (no headline/chart/card/checklist) for the entire 34.8s. Work-dir forensics:
  VO correct, body 34.8s, but only `beat1` was motion-proofed (the model's self-QA checked one beat
  and shipped the rest empty). Likely cause: the brand-brief background system was built and the
  per-beat foreground hero was never authored/revealed.
- Fixes (v4.2.0 → v4.3.0): HERO rule (foreground dominant, ghost subordinate; a ghost-only beat =
  hard fail), `gsap.from()`-ends-visible rule (no hide-then-reveal), QA check (g) fails ghost-only
  frames, Step 8 now requires proofing EVERY beat not one, two anti-patterns. NOT yet certified —
  round 3 pending.

### 2026-06-03 — Round 1 certification render (Script A: "5 Signs You Should Fire Your Marketing Agency")
- First real render produced via direct skill invocation on kimi-k2.6 (38.8s, 1080×1920, 8 animated
  HyperFrames beats, clean decode, resolves on R2). The recipe SHAPE is good — genuine motion graphics,
  clear data viz (impressions-vs-revenue bars, month-6 card, checklist), proper brand outro.
- Owner-visible defects → now permanent gates: (1) **`□` tofu boxes** from unicode emoji icons on 2
  beats; (2) **ghost text spelled "CTA"** (placeholder leak) on the checklist beat; (3) **frozen
  mid-beat holds** (PSNR ≈64 dB) — elements popped in then sat static. Added ICONS-SVG-only rule,
  GHOST-GLYPH rule, AMBIENT-MOTION rule, two new QA checks (e)+(f), tightened the motion-proof
  threshold (fail ≥50 dB), three anti-patterns. v4.1.0 → v4.2.0.
- Caveat logged: this render BYPASSED the production-worker, so the MGG Brand Brief was NOT appended
  — palette was the dark-premium default, not the brand's. The "design-free brief → on-brand"
  certification requirement is therefore still UNPROVEN; needs one real worker run (after Remy's model
  fix) to close. Two infra defects also surfaced (specialist kimi-k2.5 fabricated a fake R2 URL instead
  of running the skill; worker marks done on any .mp4 string with no HEAD check) — fixed outside this
  skill.

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
