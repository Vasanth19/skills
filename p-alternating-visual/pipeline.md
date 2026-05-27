# Pipeline — r-alternating-visual

Full skill sequence. For segment structure and HeyGen render notes see `segments.md`. For HeyGen mode decision see `heygen-workflow.md`. For DoD see `acceptance.md`.

---

1. **`task-create-production-folders`** — create `MM.DD-<title>/` (month.day + kebab-title, e.g. `05.14-knowai-gemini-docs`)
2. **`script-write-short`** — draft full script (~85-110 words for 35s)
3. **`script-preprocess-tts`** — clean for HeyGen
4. **Split script by segment** — identify 3 HeyGen chunks (segments 1/3/5). No dedicated skill — CD plans the split based on segment purposes in `segments.md`.
5. **HeyGen rendering** — see `heygen-workflow.md` for mode decision (human / mcp / api).
6. **Segment 2 (Remotion):**
   - `remotion-render` — render a motion-graphic composition from `<ord>/gfx/remotion/` to `segment-2.mp4`
   - First run: scaffold from `/Users/vasanth/MarketingMr/creative-studio/_scratch/gsai-test-20s-clip/` (copy into `<ord>/gfx/remotion/`)
7. **Segment 4 (Remotion OR NanoBanana):**
   - IF `segment4Type: remotion` → `remotion-render`
   - IF `segment4Type: nanobanana` → `nanobanana-image-gen` (generates PNG via Gemini/mcp-image) → `ffmpeg-image-to-clip` for Ken Burns animation → `production/gfx/nano/segment-4.mp4`
8. **Segment 6 (Outro):** pull from `creatives/brolls/outro/`, used by `ffmpeg-outro-append` during assembly
9. **`ffmpeg-trim-clip`** — trim each segment to exact target duration
10. **`ffmpeg-concat`** — stitch segments 1→2→3→4→5 in order
11. **`ffmpeg-outro-append`** — append segment 6 (brand outro)
12. **`caption-burn`** — (optional) burn word-level captions
13. **`ffmpeg-loudnorm`** — normalize audio
14. **`ffmpeg-verify-output`** + **`ffmpeg-delivery-checklist`** — QA (12 mandatory checks)
15. **`cover-frame-generate`** — thumbnail
16. Final → `creatives/productions/MM.DD-<title>/final/short.mp4`
17. **`cloud-r2-upload`** (optional) — publish

---

## Caching

Each segment's render is cached at its path:
- HeyGen: `production/heygen/segment-<N>.mp4`
- Remotion: `production/gfx/remotion/segment-<N>.mp4`
- NanoBanana: `production/gfx/nano/segment-<N>.mp4`

On re-run, only re-render segments whose inputs changed. Segment 6 (outro) is pulled fresh from brolls each time (cheap).
