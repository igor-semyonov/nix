IMAGE=$(mktemp --suffix=.tif)
TEXT=${IMAGE}.txt
spectacle -nbro "$IMAGE"
tesseract -l eng "$IMAGE" "$IMAGE" # tesseract adds .txt to the output file
cat "$TEXT" | tts
