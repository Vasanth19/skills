# Brand-Specific Parameters — p-reels-fmt6

## MGG Parameter Table

| Parameter | MGG Value | Notes |
|---|---|---|
| **ElevenLabs voiceId** | from `brand.yaml` (brand's cloned voice) | Pass to `c-audio`; override only for A/B tests. |
| **VO pace** | Set at generation in `c-audio` call | Prefer pace param over post-atempo. `speedMultiplier` defaults to `1.0`; only apply atempo if raw VO >50s. |
| Canvas color | `#0F172A` (dark navy) | Matches MGG theme; set as `<AbsoluteFill>` background in Remotion |
| Remotion size | `1080×1920` at `30fps` | No PIP safe-zone reserved — content can extend top-to-bottom |
| Outro | `brand-assets/outros/mgg-outro-vertical-5s.mp4` | Appended post-compose, adds ~5s |
| Caption strategy | Default (platform auto-caps + optional burned-in via Whisper→SRT) | Platform captions cover 80% of silent-watch case |
| Scene library | 7 scenes (see `scene-bank.md`) | Hook · ClaudeUiIdle · PromptTypewriter · ResponseReveal · Proof · CTA · DayCount |

**To adapt for another brand:** copy `.claude/skills/p-reels-fmt6/` into `vasanth-hq/<brand>/.claude/skills/p-reels-fmt6/`, update this table and the "Brand:" line in `SKILL.md`.

---

## Speed Override Math (optional atempo post-step)

`raw_seconds / multiplier ≈ final_VO_seconds`. Always verify with `ffprobe` after the atempo pass — drift >0.2s means the broll budget will mismatch.

- Raw <45s → `1.1×` may be fine
- Raw >50s → use `1.25×`

---

## Pipeline Overview

```
ElevenLabs TTS (c-audio)  →  loudnorm  →  VO (renders/vo.aac)
                                                   ↓
                                           Remotion 7-scene broll
                                                   ↓
                                 ffmpeg compose (video + VO + loudnorm)
                                                   ↓
                                      concat + outro  →  re-encode final
                                                   ↓
                                        extract cover.png  →  deliver
```

**Not a PIP pipeline.** No chroma-key, no avatar mask, no overlay.
