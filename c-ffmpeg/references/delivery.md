# FFmpeg — Delivery Checklist

Run before marking ANY file as final. Zero exceptions.

## Quick Verify Command

```bash
# Full stream info
ffprobe -v error -show_streams -of default "$FINAL" 2>&1 | grep -E "codec_name|width|height|r_frame_rate|sample_rate|bit_rate|duration"

# Duration only
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 "$FINAL"

# Check loudness
ffmpeg -i "$FINAL" -af loudnorm=print_format=json -f null - 2>&1 | tail -5
```

## 12-Point Checklist

| # | Check | Landscape | Portrait/Shorts |
|---|-------|-----------|----------------|
| 1 | Video codec | H.264 (libx264) | H.264 (libx264) |
| 2 | Pixel format | yuv420p | yuv420p |
| 3 | Audio codec | AAC | AAC |
| 4 | Audio loudness | -14 LUFS (±1) | -16 LUFS (±1) |
| 5 | Captions | Optional | Mandatory — burned in |
| 6 | Outro card | Optional | Mandatory (≥3s) |
| 7 | B-roll coverage | ≥ 70% | ≥ 80% |
| 8 | Resolution | 1920×1080 | 1080×1920 |
| 9 | No black frames | ✓ start/end | ✓ start/end |
| 10 | No audio drift | Check @1,3,5 min | Check @15,30s |
| 11 | Filename prefix | `ls-` | `pr-` or `sq-` |
| 12 | Location | `final/` | `final/` |

## Aspect Ratio Verification

```bash
# Get width and height
W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$FINAL")
H=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$FINAL")
echo "Resolution: ${W}x${H}, ratio: $(echo "scale=2; $W/$H" | bc)"
# Landscape: 1.78 (1920/1080)
# Portrait:  0.56 (1080/1920)
# Square:    1.00 (1080/1080)
```

## Common Delivery Fixes

### Wrong pixel format (green tint in some players)
```bash
ffmpeg -i "$INPUT" -c:v libx264 -pix_fmt yuv420p -c:a copy -y "$OUTPUT"
```

### No audio stream
```bash
# Add silent audio track
ffmpeg -i "$INPUT" -f lavfi -i anullsrc=r=48000:cl=stereo \
  -c:v copy -c:a aac -shortest -y "$OUTPUT"
```

### Audio too loud / too quiet (apply loudnorm)
```bash
# See audio-processing.md for two-pass loudnorm procedure
```

### Black frames at start (trim)
```bash
ffmpeg -ss 0.5 -i "$INPUT" -c copy -y "$OUTPUT"
```

### Portrait video pillarboxed in landscape player (do NOT fix — expected)
Portrait finals `pr-*.mp4` display with pillarbox on landscape screens. This is correct.

## Caption Burn-In (Shorts Mandatory)

```bash
ffmpeg -i "$VIDEO" -vf "subtitles=$SRT:force_style='FontName=Poppins,FontSize=22,Bold=1,PrimaryColour=&H00FFFFFF,OutlineColour=&H000000,Outline=2,Alignment=2,MarginV=60'" \
  -c:v libx264 -pix_fmt yuv420p -c:a copy -y "$OUTPUT"
```

Caption style notes:
- Portrait: bottom-center (Alignment=2), MarginV=60
- Landscape: top-center (Alignment=8), MarginV=60
- Active word highlight: yellow `&H0000FFFF` via ASS override tags

## File Naming Before Delivery

```bash
# Rename to standard convention
mv "$RAW_OUTPUT" "ls-$(basename $PROD)-final.mp4"    # landscape
mv "$RAW_OUTPUT" "pr-$(basename $PROD)-final.mp4"    # portrait

# Move to final/
mv "$OUTPUT" "$PROD/final/"
```
