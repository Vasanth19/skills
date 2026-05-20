#!/bin/bash
set -e

PROD="/Users/vasanth/MarketingMr/creative-studio/productions/wip/research--tiny-tales-analysis"
TEMP="$PROD/temp"
VIDEO="$PROD/video"

SCENE_DUR=3.2
FADE=0.3

# Step 1: Trim each scene to 3.2s and scale to 1080x1920
for i in 01 02 03 04 05; do
  echo "Processing scene $i..."
  ffmpeg -y -i "$VIDEO/v2-scene-${i}.mp4" \
    -t $SCENE_DUR \
    -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black" \
    -c:v libx264 -crf 18 -pix_fmt yuv420p -r 24 -an \
    "$TEMP/v2-s${i}.mp4"
done

# Step 2: Crossfade transitions
# Offset math: each xfade offset = accumulated_duration - fade_duration
# xfade1: 3.2-0.3=2.9, result=6.1
# xfade2: 6.1-0.3=5.8, result=9.0
# xfade3: 9.0-0.3=8.7, result=11.9
# xfade4: 11.9-0.3=11.6, result=14.8
echo "Applying crossfade transitions..."
ffmpeg -y \
  -i "$TEMP/v2-s01.mp4" \
  -i "$TEMP/v2-s02.mp4" \
  -i "$TEMP/v2-s03.mp4" \
  -i "$TEMP/v2-s04.mp4" \
  -i "$TEMP/v2-s05.mp4" \
  -filter_complex \
  "[0:v][1:v]xfade=transition=fade:duration=0.3:offset=2.9[v01]; \
   [v01][2:v]xfade=transition=fade:duration=0.3:offset=5.8[v02]; \
   [v02][3:v]xfade=transition=fade:duration=0.3:offset=8.7[v03]; \
   [v03][4:v]xfade=transition=fade:duration=0.3:offset=11.6[vout]" \
  -map "[vout]" -c:v libx264 -crf 18 -pix_fmt yuv420p \
  "$TEMP/v2-scenes-crossfade.mp4"

echo "Crossfade video duration:"
ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$TEMP/v2-scenes-crossfade.mp4"

# Step 3: Add audio
echo "Adding audio track..."
ffmpeg -y \
  -i "$TEMP/v2-scenes-crossfade.mp4" \
  -i "$PROD/goldfish-audio.mp3" \
  -c:v copy -c:a aac -b:a 192k \
  -map 0:v:0 -map 1:a:0 \
  -shortest \
  -movflags +faststart \
  "$VIDEO/goldfish-rescue-v2-final.mp4"

echo "=== FINAL OUTPUT ==="
ffprobe -v quiet -show_entries format=duration -show_entries stream=width,height -of compact "$VIDEO/goldfish-rescue-v2-final.mp4"
ls -lh "$VIDEO/goldfish-rescue-v2-final.mp4"
