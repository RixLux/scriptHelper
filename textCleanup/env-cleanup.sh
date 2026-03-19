#!/usr/bin/env bash

INPUT_FILE="$1"

if [ -z "$INPUT_FILE" ]; then
  echo "Usage: bash env-clean.sh <path-to-.env>"
  exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: file not found -> $INPUT_FILE"
  exit 1
fi

OUTPUT_FILE="$(dirname "$INPUT_FILE")/.env.example"

sed 's/=.*$/=/' "$INPUT_FILE" > "$OUTPUT_FILE"

echo " Created: $OUTPUT_FILE"
