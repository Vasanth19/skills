# Acceptance (Definition of Done) — r-bottom-avatar-pip

- [ ] Exactly one MP4 at `creatives/productions/MM.DD-<title>/final/short.mp4` with duration matching the script target (±0.5s)
- [ ] **Speed check:** `heygen/avatar_1.1x.mp4` exists AND its duration ≈ `heygen/raw-avatar.mp4` duration / 1.1 (±0.1s). If the 1.1x file doesn't exist OR its duration matches raw within 0.5s → Step 6.5 was skipped → short must be re-rendered. See VAS-34 / `productions/ord-20260420-001-nemoclaw-vs-openclaw/logs/`.
- [ ] 1080×1920 resolution confirmed by `ffmpeg-verify-output`
- [ ] **First frame is NOT a solid dark/black canvas.** Run b-roll-zone brightness check (`MAX_BROLL > 0x30`); must pass. See `first-frame-rule.md`.
- [ ] Avatar PIP is **540×540 square with rounded corners (radius 54)**, flush bottom-center at `overlay=270:1380`
- [ ] Avatar is the last overlay (on top of b-roll)
- [ ] Head has ~10% headroom inside the 540×540 square crop; shoulders visible
- [ ] All b-roll primary content (headlines, logos, nodes, payoff numbers) stays within **safe zone y=0–1380**
- [ ] No primary b-roll content rendered into y=1380–1920
- [ ] All 12 checks in `ffmpeg-delivery-checklist` pass
- [ ] Re-run with same script skips HeyGen render (cache hit)
- [ ] Issue comments log any skill-missing / failure with paths + reasons; no silent workarounds
