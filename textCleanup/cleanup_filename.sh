#!/bin/bash

# Check target
if [ -z "$1" ]; then
    echo "Usage: ./cleanup_name.sh <file-or-directory>"
    exit 1
fi

TARGET="$1"

# Ask replacement
read -p "Replace spaces with (leave empty to remove): " REPLACE

# Default = remove spaces
if [ -z "$REPLACE" ]; then
    REPLACE=""
fi

rename_item() {
    local ITEM="$1"
    BASENAME=$(basename "$ITEM")
    DIRNAME=$(dirname "$ITEM")

    NEWNAME=$(echo "$BASENAME" | sed "s/ /$REPLACE/g")

    if [ "$BASENAME" != "$NEWNAME" ]; then
        mv -n "$ITEM" "$DIRNAME/$NEWNAME"
        echo "Renamed: $BASENAME -> $NEWNAME"
    fi
}

# If directory
if [ -d "$TARGET" ]; then
    find "$TARGET" -depth -print0 | while IFS= read -r -d '' file; do
        rename_item "$file"
    done

# If file
elif [ -f "$TARGET" ]; then
    rename_item "$TARGET"

else
    echo "Target not found."
fi
