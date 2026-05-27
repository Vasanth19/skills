# Brand-Specific Parameters — r-screen-rec-vo

## MGG Parameter Table

| Parameter | MGG Value | Notes |
|---|---|---|
| **Avatar speed** | **`1.25x` default** (override to hit 35-46s) | Raw HeyGen usually lands 50-55s; at 1.25× lands 40-44s. Still intelligible (atempo pitch-preserved). |
| Canvas color | `#0F172A` (dark navy) | Matches MGG theme; set as `<AbsoluteFill>` background in Remotion |
| Remotion size | `1080×1920` at `30fps` | No PIP safe-zone reserved — content can extend top-to-bottom |
| Outro | `brand-assets/outros/mgg-outro-vertical-5s.mp4` | Appended post-compose, adds ~5s |
| Caption strategy | Default (platform auto-caps + optional burned-in via Whisper→SRT) | Platform captions cover 80% of silent-watch case |
| Scene library | 7 scenes (see `scene-bank.md`) | Hook · ClaudeUiIdle · PromptTypewriter · ResponseReveal · Proof · CTA · DayCount |

**To adapt for another brand:** copy `.claude/skills/r-screen-rec-vo/` into `vasanth-hq/<brand>/.claude/skills/r-screen-rec-vo/`, update this table and the "Brand:" line in `SKILL.md`.

---

## Speed Override Math

`raw_seconds / multiplier ≈ final_VO_seconds`. Always verify with `ffprobe` after the atempo pass — drift >0.2s means the broll budget will mismatch.

- Raw <45s → `1.1×` may be fine
- Raw >50s → use `1.25×`

---

## Pipeline Overview

```
HeyGen render  →  speed-adjust (ffmpeg atempo)  →  extract audio (VO)
                                                            ↓
                                                    Remotion 7-scene broll
                                                            ↓
                                          ffmpeg overlay (video + VO + loudnorm)
                                                            ↓
                                               concat + outro  →  re-encode final
                                                            ↓
                                             extract cover.png  →  deliver
```

**Not a PIP pipeline.** The HeyGen render is discarded post-audio-extraction. No chroma-key, no avatar mask, no overlay.
