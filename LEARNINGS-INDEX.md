# Learnings Index — Aggregated Skill Feedback

**Source of truth for what works across all skills.** Updated daily as agents run skills and append feedback.

Agent workflow:
1. **Before executing a skill:** Read this index + that skill's `LEARNINGS.md`
2. **After executing:** Ask the user for feedback, append to skill's `LEARNINGS.md`, and update this index

---

## 🔴 CRITICAL ISSUES (Block all executions until fixed)

*None currently. All skills operational.*

---

## 🟡 ACTIVE FEEDBACK (Apply on every run)

### c-ffmpeg

- **Chroma key always `0x00FF00` (two-pass)** — Never sample green from video. Never trust b-roll plan's color value. Use `colorkey=0x00FF00:0.25:0.05,colorkey=0x00FF00:0.40:0.01`
- **Never crop-and-stretch avatar** — Preserves aspect ratio: `scale=2208:1242,crop=1920:1080:144:0` (1.15x zoom, then crop)
- **Audio-per-segment architecture** — Every segment (AVATAR, PIP, FULLSCREEN) carries its own synced audio. Never separate audio from video, then recombine (drift accumulates)
- **No `#` comments inside `filter_complex` strings** — Causes parse error. Save complex commands as `.sh` scripts
- **Gap-free b-roll windows** — Extend each segment's `enable` window to START of next segment. Eliminates 0.5–1.5s avatar flashes

### c-html-gfx

- **Mandatory post-render Unicode check** — Emojis/em-dashes/arrows break if charset missing. Add `<meta charset="UTF-8">` to every HTML head
- **Window size = outer window** — Chrome reserves ~140px on macOS. For 1920x1080 target: use `--window-size=1920,1220`, then crop

### c-studio-audio

- **ElevenLabs Floe API wrapper is stable** — Read FLOE_API_KEY from `.gsai/secret` or environment
- **MLX Whisper transcription accuracy** — Segment audio if >30 min for better accuracy

### c-broll

- **Check library first** — Always search for reusable assets before generating anything new
- **B-roll plan quality guard** — ≥4 unique assets, ≥80% coverage minimum

### p-vsl

- **Script approval is mandatory checkpoint** — User must approve script before HeyGen render begins
- **B-roll plan review required** — User reviews landscape PIP placement plan before asset generation
- **Delivery checklist all 12 points** — Cannot mark done until every check passes

### p-avatar-short

- **HeyGen render is user-triggered checkpoint** — Agent provides job ID; user confirms launch in dashboard
- **Green-screen quality verification** — Always spot-check downloaded avatar MP4 for keying quality before compositing

### p-viral-reel

- **`--style avatar` is production-ready** — HeyGen path fully functional
- **`--style ai-generated` needs API update** — Higgsfield Cinema and Veo references are stale. Update model APIs before use

### r-social-post-outstand

- **OUTSTAND_API_KEY auth order:** Environment variable → fallback `<posting-tools>/.gsai/secret`
- **Pricing model:** $0.50/month per account + $0.01 per post
- **Always list accounts first** — Call `list-accounts.sh` before creating posts to verify target accounts exist

### r-x-thread

- **OAuth credentials are separate from PostForMe** — X API v2 requires X_API_KEY, X_API_SECRET, X_ACCESS_TOKEN, X_ACCESS_TOKEN_SECRET (not POSTFORME_API_KEY)
- **Chaining via `inReplyToStatusId`** — Post tweet 1, capture ID, reply to that ID with tweet 2, repeat

---

## 📊 Feedback by Skill (Reverse Chronological)

### c-ai-media
**2026-05-08** — Initial template
- No feedback yet

### c-broll
**2026-05-08** — Initial template
- No feedback yet

### c-cloud-media
**2026-05-08** — Initial template
- No feedback yet

### c-ffmpeg
**2026-05-08** — Initial template
- Populated with non-negotiable rules (see ACTIVE FEEDBACK above)

### c-heygen
**2026-05-08** — Initial template
- No feedback yet

### c-html-gfx
**2026-05-08** — Initial template
- Unicode/charset rules (see ACTIVE FEEDBACK above)
- Window size gotcha on macOS (see ACTIVE FEEDBACK above)

### c-kie-ai
**2026-05-08** — Initial template
- No feedback yet

### c-learnloop
**2026-05-08** — Initial template
- No feedback yet

### c-replicate
**2026-05-08** — Initial template
- No feedback yet

### c-studio-audio
**2026-05-08** — Initial template
- ElevenLabs Floe API stable (see ACTIVE FEEDBACK above)

### c-studio-production
**2026-05-08** — Initial template
- No feedback yet

### c-studio-script
**2026-05-08** — Initial template
- No feedback yet

### c-web-capture
**2026-05-08** — Initial template
- No feedback yet

### p-ai-character
**2026-05-08** — Initial template
- No feedback yet

### p-avatar-screenshot-broll
**2026-05-08** — Initial template
- No feedback yet

### p-avatar-short
**2026-05-08** — Initial template
- HeyGen checkpoint rules (see ACTIVE FEEDBACK above)
- Green-screen verification (see ACTIVE FEEDBACK above)

### p-banner
**2026-05-08** — Initial template
- No feedback yet

### p-broll
**2026-05-08** — Initial template
- No feedback yet

### p-broll-media
**2026-05-08** — Initial template
- No feedback yet

### p-demo
**2026-05-08** — Initial template
- No feedback yet

### p-gfx-batch
**2026-05-08** — Initial template
- No feedback yet

### p-gfx-short
**2026-05-08** — Initial template
- No feedback yet

### p-hook-reel
**2026-05-08** — Initial template
- No feedback yet

### p-linkedin-carousel
**2026-05-08** — Initial template
- No feedback yet

### p-longform-visual
**2026-05-08** — Initial template
- No feedback yet

### p-manual-execution
**2026-05-08** — Initial template
- No feedback yet

### p-snap-bg-swap
**2026-05-08** — Initial template
- No feedback yet

### p-thumbnail
**2026-05-08** — Initial template
- No feedback yet

### p-viral-reel
**2026-05-08** — Initial template
- Avatar style production-ready (see ACTIVE FEEDBACK above)
- AI-generated style needs update (see ACTIVE FEEDBACK above)

### p-vsl
**2026-05-08** — Initial template
- Script approval checkpoint (see ACTIVE FEEDBACK above)
- B-roll plan review (see ACTIVE FEEDBACK above)
- Delivery checklist (see ACTIVE FEEDBACK above)

### r-cfw-publisher
**2026-05-08** — Initial template
- No feedback yet

### r-social-post-outstand
**2026-05-08** — Initial template
- Auth and pricing rules (see ACTIVE FEEDBACK above)

### r-social-post-postforme
**2026-05-08** — Initial template
- No feedback yet

### r-social-post-upload
**2026-05-08** — Initial template
- No feedback yet

### r-x-thread
**2026-05-08** — Initial template
- OAuth and chaining rules (see ACTIVE FEEDBACK above)

### r-youtube-data-api
**2026-05-08** — Initial template
- No feedback yet

---

## 🔍 Search by Pattern

### Video Compositing
- c-ffmpeg (ACTIVE FEEDBACK: chroma key, audio sync, no crop-stretch)

### HeyGen/Avatar Rendering
- c-heygen, p-avatar-short, p-viral-reel (--style avatar)
- ACTIVE FEEDBACK: green-screen verification, user-triggered checkpoint

### Social Publishing
- r-social-post-outstand, r-social-post-postforme, r-social-post-upload
- r-x-thread, r-youtube-data-api
- ACTIVE FEEDBACK: auth order, OAuth separation, account verification

### Graphics Generation
- c-html-gfx, p-gfx-short, p-gfx-batch
- ACTIVE FEEDBACK: Unicode/charset, window size on macOS

### Long-form Production
- p-vsl, p-longform-visual, p-demo
- ACTIVE FEEDBACK: script approval, b-roll review, delivery checklist

### Short-form Production
- p-avatar-short, p-gfx-short, p-ai-character, p-viral-reel, p-hook-reel
- ACTIVE FEEDBACK: varies by style (avatar/ai-generated)

---

## 📈 Feedback Velocity

**Skills with ACTIVE FEEDBACK** (matured, production-hardened):
- c-ffmpeg (5 rules)
- c-html-gfx (2 rules)
- c-studio-audio (2 rules)
- c-broll (2 rules)
- p-vsl (3 rules)
- p-avatar-short (2 rules)
- p-viral-reel (2 rules)
- r-social-post-outstand (3 rules)
- r-x-thread (2 rules)

**Skills with no ACTIVE FEEDBACK yet** (watch for issues):
- c-ai-media, c-cloud-media, c-heygen, c-kie-ai, c-learnloop, c-replicate, c-studio-production, c-studio-script, c-web-capture
- p-ai-character, p-avatar-screenshot-broll, p-banner, p-broll, p-broll-media, p-demo, p-gfx-batch, p-gfx-short, p-hook-reel, p-linkedin-carousel, p-longform-visual, p-manual-execution, p-snap-bg-swap, p-thumbnail
- r-cfw-publisher, r-social-post-postforme, r-social-post-upload, r-youtube-data-api

---

**Last updated:** 2026-05-09 (automated via skill execution logs)  
**Updated by:** Self-improvement loop + human feedback
