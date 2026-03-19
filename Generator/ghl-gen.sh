#!/bin/bash

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: Not a Git repo."
    exit 1
fi

REMOTE_URL=$(git remote get-url origin 2>/dev/null)
CLEAN_URL=$(echo "$REMOTE_URL" | sed -E 's|git@github.com:|https://github.com/|' | sed 's|.git$||')

echo "Detected: $CLEAN_URL"

echo "Generating shortcut files..."

# --- Windows (.url file) ---
printf "[InternetShortcut]\r\nURL=$CLEAN_URL\r\n" > github.url

# --- Linux (.desktop file) ---
cat <<EOF > github.desktop
[Desktop Entry]
Name=GitHub Repo
Type=Link
URL=$CLEAN_URL
Icon=text-html
EOF
chmod +x github.desktop

# --- Generic (.txt file) ---
echo "$CLEAN_URL" > github.txt

echo "Done! Created: github.url, github.desktop, and github.txt"
