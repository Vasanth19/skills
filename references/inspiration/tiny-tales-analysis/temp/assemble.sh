#!/bin/bash
set -e

PROD="/Users/vasanth/MarketingMr/creative-studio/productions/wip/research--tiny-tales-analysis"
TEMP="$PROD/temp"
VIDEO="$PROD/video"

# Step 1: Trim each scene to 3.5s and scale to 1080x1920
for i in 01 02 03 04; do
  echo "Processing scene $i..."
  ffmpeg -y -i "$VIDEO/scene-${i}.mp4" \
    -t 3.5 \
    -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black" \
    -c:v libx264 -crf 18 -pix_fmt yuv420p -an \
    "$TEMP/s${i}.mp4"
done

# Step 2: Create concat list
cat > "$TEMP/concat.txt" << EOF
file '$TEMP/s01.mp4'
file '$TEMP/s02.mp4'
file '$TEMP/s03.mp4'
file '$TEMP/s04.mp4'
EOF

# Step 3: Concat all scenes
echo "Concatenating scenes..."
ffmpeg -y -f concat -safe 0 -i "$TEMP/concat.txt" \
  -c:v libx264 -crf 18 -pix_fmt yuv420p \
  "$TEMP/scenes-concat.mp4"

# Step 4: Add audio
echo "Adding audio track..."
ffmpeg -y \
  -i "$TEMP/scenes-concat.mp4" \
  -i "$PROD/goldfish-audio.mp3" \
  -c:v copy -c:a aac -b:a 192k \
  -map 0:v:0 -map 1:a:0 \
  -shortest \
  -movflags +faststart \
  "$VIDEO/goldfish-rescue-final.mp4"

echo "Done!"
ffprobe -v quiet -show_entries format=duration -show_entries stream=width,height -of compact "$VIDEO/goldfish-rescue-final.mp4"
