#!/bin/sh

echo "=== MkDocs YAML & Shortcut Generator ==="
echo ""

# ---- Auto-Detect Logic ----
# Try to get the remote URL from git
REMOTE_URL=$(git remote get-url origin 2>/dev/null)

if [ -n "$REMOTE_URL" ]; then
    # Parse Owner and Repo from URL (handles HTTPS and SSH)
    # Extracts "Owner/Repo" from "https://github.com/Owner/Repo.git"
    # or "git@github.com:Owner/Repo.git"
    REPO_FULL=$(echo "$REMOTE_URL" | sed -E 's|.*github.com[:/](.*)|\1|' | sed 's|.git$||')
    OWNER=$(echo "$REPO_FULL" | cut -d'/' -f1)
    REPO=$(echo "$REPO_FULL" | cut -d'/' -f2)
    echo "Autodetected: $OWNER / $REPO"
else
    echo "Git repo not detected. Please enter manually:"
    printf "Repo owner (e.g. RixLux): "
    read -r OWNER
    printf "Repo name (e.g. scriptHelper): "
    read -r REPO
fi

OWNER_LC=$(printf "%s" "$OWNER" | tr '[:upper:]' '[:lower:]')

SITE_NAME="$REPO Documentation"
SITE_DESC="Documentation"
SITE_URL="https://${OWNER_LC}.github.io/${REPO}/"
REPO_NAME="${OWNER}/${REPO}"
REPO_URL="https://github.com/${OWNER}/${REPO}"

# ---- Generate nav from docs ----
NAV_ITEMS=""

if [ -d docs ]; then
    # Using find and sort to build the navigation list
    FILES=$(find docs -type f -name "*.md" | sort)
    for file in $FILES; do
        rel="${file#docs/}"
        name="$(basename "$file" .md)"
        # Convert file-name to Title Case
        title=$(echo "$name" | sed 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
        NAV_ITEMS="$NAV_ITEMS
  - $title: $rel"
    done
else
    NAV_ITEMS="
  - Home: index.md"
fi

# ---- Generate mkdocs.yml ----
cat <<EOF > mkdocs.yml
site_name: "$SITE_NAME"
site_description: "$SITE_DESC"
site_url: "$SITE_URL"

repo_name: "$REPO_NAME"
repo_url: "$REPO_URL"

theme:
  name: material
  language: en
  features:
    - navigation.tabs
    - navigation.sections
    - navigation.top
    - search.highlight
    - search.suggest
    - search.share
    - content.code.copy

  palette:
    - media: "(prefers-color-scheme: light)"
      scheme: default
      primary: deep-purple
      accent: indigo
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode

    - media: "(prefers-color-scheme: dark)"
      scheme: slate
      primary: black
      accent: blue
      toggle:
        icon: material/brightness-4
        name: Switch to light mode

nav:$NAV_ITEMS

markdown_extensions:
  - admonition
  - pymdownx.details
  - pymdownx.superfences
  - pymdownx.tabbed:
      alternate_style: true
  - attr_list
  - md_in_html

plugins:
  - search

extra_css:
  - stylesheets/extra.css
EOF

# ---- Generate CSS Template ----
mkdir -p docs/stylesheets

echo ""
echo "Choose a CSS Color Template:"
echo "1) Purple"
echo "2) High Contrast"
echo "3) Minimalist"
printf "Selection (1-3): "
read -r CSS_CHOICE

case $CSS_CHOICE in
  2) LIGHT_COLOR="#1a1a1a"; LIGHT_ACCENT="#d32f2f"; DARK_COLOR="#ffffff" ;;
  3) LIGHT_COLOR="#37474f"; LIGHT_ACCENT="#263238"; DARK_COLOR="#cfd8dc" ;;
  *) LIGHT_COLOR="#7E56C2"; LIGHT_ACCENT="#4D21CB"; DARK_COLOR="#e5e9f0" ;;
esac

cat <<EOF > docs/stylesheets/extra.css
:root { --md-typeset-color: $LIGHT_COLOR; }
[data-md-color-scheme="default"] {
    --md-typeset-color: $LIGHT_COLOR;
    --md-code-fg-color: $LIGHT_ACCENT;
    --md-typeset-a-color: $LIGHT_ACCENT;
    --md-default-fg-color--light: $LIGHT_ACCENT;
}
[data-md-color-scheme="slate"] { --md-typeset-color: $DARK_COLOR; }
EOF

# ---- Generate Shortcut Files ----
echo ""
echo "Creating shortcut files..."
# Windows
printf "[InternetShortcut]\r\nURL=$REPO_URL\r\n" > github.url
# Linux
echo "[Desktop Entry]\nName=GitHub Repo\nType=Link\nURL=$REPO_URL\nIcon=text-html" > github.desktop
chmod +x github.desktop
# Text fallback
echo "$REPO_URL" > github.txt

# ----.gitignore Management ----
echo ""
printf "Do you want to add these shortcuts to .gitignore? (y/n): "
read -r IGNORE_CHOICE

if [[ "$IGNORE_CHOICE" =~ ^[Yy]$ ]]; then
    FILES_TO_IGNORE=("github.url" "github.desktop" "github.txt")

    # Create .gitignore if it doesn't exist
    touch .gitignore

    for file in "${FILES_TO_IGNORE[@]}"; do
        if ! grep -qxF "$file" .gitignore; then
            echo "$file" >> .gitignore
            echo "Added $file to .gitignore"
        else
            echo "$file is already ignored."
        fi
    done
else
    echo "Shortcuts left visible. You can now 'git add' them if you wish."
fi

echo "------------------------------------------"
echo "Done! Clickable Link: \e]8;;$REPO_URL\e\\Open Repo\e]8;;\e\\"
