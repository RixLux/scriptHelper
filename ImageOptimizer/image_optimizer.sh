#!/usr/bin/env bash

# ========= CONFIG =========
MAX_WIDTH=1600           # Max width in pixels
TARGET_SIZE_KB=300       # Target file size (JPEG only)
JPEG_QUALITY_START=88
JPEG_QUALITY_MIN=60
PNG_QUALITY=85
WEBP_QUALITY=82
OUTPUT_DIR="optimized"

# =========================
mkdir -p "$OUTPUT_DIR"

# If no arguments, process images in current directory
if [ "$#" -eq 0 ]; then
  set -- *.png *.jpg *.jpeg *.webp
fi

optimize_jpeg() {
  local input="$1"
  local output="$2"

  local quality=$JPEG_QUALITY_START
  while true; do
    magick "$input" \
      -auto-orient \
      -resize "${MAX_WIDTH}x>" \
      -strip \
      -quality "$quality" \
      "$output"

    size=$(du -k "$output" | cut -f1)
    [[ $size -le $TARGET_SIZE_KB || $quality -le $JPEG_QUALITY_MIN ]] && break

    quality=$((quality - 5))
  done
}

optimize_png() {
  local input="$1"
  local output="$2"

  magick "$input" \
    -auto-orient \
    -resize "${MAX_WIDTH}x>" \
    -strip \
    -define png:compression-level=9 \
    "$output"
}

optimize_webp() {
  local input="$1"
  local output="$2"

  magick "$input" \
    -auto-orient \
    -resize "${MAX_WIDTH}x>" \
    -strip \
    -quality "$WEBP_QUALITY" \
    "$output"
}

for img in "$@"; do
  [[ ! -f "$img" ]] && continue

  base=$(basename "$img")
  name="${base%.*}"
  ext="${base##*.}"
  ext="${ext,,}"

  echo "Optimizing: $img"

  case "$ext" in
    jpg|jpeg)
      optimize_jpeg "$img" "$OUTPUT_DIR/$name.$ext"
      ;;
    png)
      optimize_png "$img" "$OUTPUT_DIR/$name.png"
      ;;
    webp)
      optimize_webp "$img" "$OUTPUT_DIR/$name.webp"
      ;;
    *)
      echo "Skipping unsupported file: $img"
      ;;
  esac
done

echo "✅ Done. Optimized files in '$OUTPUT_DIR/'"
