# Brand-Specific Parameters — r-bottom-avatar-pip

## MGG Parameter Table

| Parameter | MGG Value | Notes |
|---|---|---|
| **Avatar speed** | **`1.0x` (no post-speed)** | HeyGen render is already pre-speedened upstream as of 2026-05-17. Do NOT re-speed in post. Skip the old Step 7. |
| Canvas color | `#0F172A` (dark navy) | Background when avatar is opaque / b-roll doesn't fill |
| **HeyGen green-screen** | **`#00FF00`** | Background for HeyGen render. Chroma-key out in post via `ffmpeg-colorkey-composite`. Never bake a non-keyable background. |
| Avatar PIP | 540×540 rounded (r=54), `overlay=270:1380` | 10% head radius |
| Cover prepend | 0.4s | See `first-frame-rule.md` |
| Outro | `creatives/brolls/outro/mgg-outro-vertical-5s.mp4` | Must have audio > -60 dB — see `creatives/brolls/outro/README.md` |

**To adapt for another brand:** copy this file, change the values here and update the "Brand:" line in `SKILL.md`.

---

## Avatar Background Detection

**Background is optional.** The recipe handles two paths based on what HeyGen returns:

1. **Green-screen source (`#00FF00` bg):** background removed via chroma-key → avatar becomes transparent PIP over b-roll (cleanest look).
2. **Non-green source (white/cream/studio bg):** chroma-key SKIPPED → avatar shown as-is in a square PIP frame; bg color becomes the PIP card. Still readable.

Either is valid. Detect and branch — never halt the pipeline on non-green bg.

**Detection (run on `heygen/avatar_1.1x.mp4`, never the raw):**

Sample 8 edge pixels at 3 timestamps (0.5s, midway, last-1s) and compute dominant edge color:
- Dominant edge RGB close to `#00FF00` (hue ~120°, sat > 70%) → `bg_type=green_screen`, proceed to chroma-key
- Anything else → `bg_type=opaque`, set `skip_colorkey=true`

---

## Canvas Layout Spec

- **Base canvas:** 1080×1920, dark navy `0x0F172A`
- **B-roll safe zone:** y=0 to y=1380 (top 72%). All primary content — headlines, logos, payoff numbers — must stay inside this zone.
- **Dead zone:** y=1380–1920 (540px). Secondary elements (small captions, hint arrows) only. No core composition.
- **PIP zone:** y=1380–1920, avatar is always the last overlay (on top of everything).

**PIP shape (canonical as of VAS-22 v2, 2026-04-18):**
- 540×540 square, rounded corners radius 54px (≈10%)
- `overlay=270:1380` on 1080×1920
- Source 16:9 avatar is center-cropped to square (face-weighted), scaled to 540×540, masked via pre-rendered rounded-corner alpha PNG

**History:** v1 = 540×960 rectangle (too heavy, occluded b-roll). v2 = 360×360 square no rounding. VAS-22 review → current spec. Do not port v1 or v2 shape from prior productions.
