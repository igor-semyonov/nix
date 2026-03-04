IMAGE=$(mktemp --suffix=.tif)
TEXT=${IMAGE}.txt
spectacle -nbfo "$IMAGE"
# shellcheck disable=SC1079
tesseract -l eng "$IMAGE" "$IMAGE" # tesseract adds .txt to the output file
cat "$TEXT" | tts
