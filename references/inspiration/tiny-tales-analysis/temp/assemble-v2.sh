#!/bin/bash
set -e

PROD="/Users/vasanth/MarketingMr/creative-studio/productions/wip/research--tiny-tales-analysis"
TEMP="$PROD/temp"
VIDEO="$PROD/video"

# Step 1: Trim each scene to 2.8s and scale to exactly 1080x1920
for i in 01 02 03 04 05; do
  echo "Processing scene $i..."
  ffmpeg -y -i "$VIDEO/v2-scene-${i}.mp4" \
    -t 2.8 \
    -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black" \
    -c:v libx264 -crf 18 -pix_fmt yuv420p -r 24 -an \
    "$TEMP/v2-s${i}.mp4"
done

# Step 2: Crossfade transitions (0.3s fade between scenes)
echo "Applying crossfade transitions..."
ffmpeg -y \
  -i "$TEMP/v2-s01.mp4" \
  -i "$TEMP/v2-s02.mp4" \
  -i "$TEMP/v2-s03.mp4" \
  -i "$TEMP/v2-s04.mp4" \
  -i "$TEMP/v2-s05.mp4" \
  -filter_complex \
  "[0:v][1:v]xfade=transition=fade:duration=0.3:offset=2.5[v01]; \
   [v01][2:v]xfade=transition=fade:duration=0.3:offset=4.7[v02]; \
   [v02][3:v]xfade=transition=fade:duration=0.3:offset=6.9[v03]; \
   [v03][4:v]xfade=transition=fade:duration=0.3:offset=9.1[vout]" \
  -map "[vout]" -c:v libx264 -crf 18 -pix_fmt yuv420p \
  "$TEMP/v2-scenes-crossfade.mp4"

echo "Crossfade video duration:"
ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$TEMP/v2-scenes-crossfade.mp4"

# Step 3: Add audio (trim to match video duration)
echo "Adding audio track..."
VID_DUR=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$TEMP/v2-scenes-crossfade.mp4")
ffmpeg -y \
  -i "$TEMP/v2-scenes-crossfade.mp4" \
  -i "$PROD/goldfish-audio.mp3" \
  -c:v copy -c:a aac -b:a 192k \
  -map 0:v:0 -map 1:a:0 \
  -shortest \
  -movflags +faststart \
  "$VIDEO/goldfish-rescue-v2-final.mp4"

echo "Done!"
ffprobe -v quiet -show_entries format=duration -show_entries stream=width,height -of compact "$VIDEO/goldfish-rescue-v2-final.mp4"
