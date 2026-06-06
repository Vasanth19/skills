# Acceptance (Definition of Done) — p-reels-fmt6

- [ ] Single MP4 at `creatives/productions/MM.DD-<title>/final/short.mp4`
- [ ] Final duration: 35-51s (35-46s body + ~5s outro). Flag to CMO if over 46s body — acceptable, but document.
- [ ] VO audio file (`renders/vo.aac`) exists; if atempo was applied, verify `ffprobe` duration matches `raw / multiplier ± 0.2s`
- [ ] Cover at `final/cover.png` — timestamp is mid-PromptReveal or start-of-ResponseReveal (NOT Hook scene)
- [ ] All 7 Remotion scenes present and in order (verify via frame inspection or Remotion render log)
- [ ] Audio: aac 48kHz stereo, loudnorm'd to -16 LUFS
- [ ] Video: 1080×1920, 30fps CFR, `time_base=1/30000`, `start_time=0.000`, no B-frames
- [ ] PIP safe zone: N/A — document "no PIP by design" in delivery checklist
- [ ] All 12 checks in `ffmpeg-delivery-checklist` pass
- [ ] CMO handoff note filed (including any duration drift, speed multiplier used, scene deviations)
- [ ] MemPalace drawer dropped for this production (see `scene-bank.md` post-mortem pointer)
