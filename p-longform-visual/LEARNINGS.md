# p-longform-visual Learnings

> This file is the self-learning loop for `p-longform-visual`. Before executing this skill, the agent reads this file and applies all accumulated `Active Feedback`. After execution, the agent asks the user for feedback and appends it here.

---

## Active Feedback (apply on every run)

*None yet — add feedback below and it becomes part of this skill's behavior.*

---

## Feedback Log

### 2026-05-08 — Initial template
- Skill created. No feedback yet.


### 2026-05-25 — COM-40 PAL v3 Module 1 batch production
- AI-generated broll (HTML terminal mockups → Chrome headless screenshots at 1920x1080) is a valid and fully autonomous substitute for screen recordings in "fully AI-generated" tutorial videos.
- Freeze-frame approach: PNG → freeze-frame video segment with ffmpeg `-loop 1 -tune stillimage -r 30 -pix_fmt yuv420p`. 4 screenshots per lesson mapped to script sections.
- Concat.txt must be written with `printf` and the ffmpeg concat must run `cd "$VIDEO_DIR"` so relative file paths resolve correctly.
- Two-pass loudnorm on the final + volume trim gets within ±0.5 LUFS of -14 target on speech TTS.
