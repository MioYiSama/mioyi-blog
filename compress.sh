find ./content ./static -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) -print0 | while IFS= read -r -d '' f; do
  cwebp -q 80 "$f" -o "${f%.*}.webp"
done