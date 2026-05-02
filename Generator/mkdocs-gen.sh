#!/bin/bash

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
    echo "Git Remote detected: $OWNER / $REPO"
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

# ---- README Management ----
README_FILE="README.md"
DOCS_LINK="$SITE_URL"
if [ -f "$README_FILE" ]; then
    # Check if the documentation link already exists to avoid duplicates
    if grep -q "$DOCS_LINK" "$README_FILE"; then
        echo "Documentation badge already exists in $README_FILE."
    else
        echo "Adding Documentation badge to the top of $README_FILE..."

        # Create a temporary file with the new header
        cat <<EOF > readme_temp
## Documentation

<a href="$DOCS_LINK">
    <img
      src="https://img.shields.io/badge/Docs-4051B5?style=for-the-badge&logo=MaterialForMkDocs&logoColor=white"
      alt="Docs"
    />
</a>

$(cat "$README_FILE")
EOF
        # Move temporary file to original README
        mv readme_temp "$README_FILE"
        echo "Successfully updated $README_FILE."
    fi
else
    echo "README.md not found at root. Skipping badge injection."
fi

# ---- Generate nav from docs ----
NAV_ITEMS=""

if [ -d docs ]; then
    # 1. Force index.md to the top if it exists
    if [ -f "docs/index.md" ]; then
        # We use a literal newline inside the variable
        NAV_ITEMS="
  - Home: index.md"
    fi

    # 2. Add all other files alphabetically
    FILES=$(find docs -type f -name "*.md" ! -name "index.md" | sort -V)
    for file in $FILES; do
        rel="${file#docs/}"
        name="$(basename "$file" .md)"
        title=$(echo "$name" | sed 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')

        # Append with a real newline
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

nav:$NAV_ITEMS
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
printf "[Desktop Entry]\nName=GitHub Repo\nType=Link\nURL=%s\nIcon=text-html\n" "$REPO_URL" > github.desktop
chmod +x github.desktop
# Text fallback
echo "$REPO_URL" > github.txt

# ---- .gitignore Management ----
echo ""

# Shortcut logic
printf "Do you want to add these shortcuts to .gitignore? (y/n): "
read -r IGNORE_CHOICE

# MkDocs logic
printf "Do you want to add MkDocs build files to .gitignore? (y/n): "
read -r MKDOCS_CHOICE

# Create .gitignore if it doesn't exist
touch .gitignore

# Process Shortcuts
if [[ "$IGNORE_CHOICE" =~ ^[Yy]$ ]]; then
    FILES_TO_IGNORE=("github.url" "github.desktop" "github.txt")
    for file in "${FILES_TO_IGNORE[@]}"; do
        if ! grep -qxF "$file" .gitignore; then
            echo "$file" >> .gitignore
            echo "Added $file to .gitignore"
        else
            echo "$file is already ignored."
        fi
    done
fi

# Process MkDocs
if [[ "$MKDOCS_CHOICE" =~ ^[Yy]$ ]]; then
    # Define patterns (removed the empty string from the array)
    MK_PATTERNS=("# --- MkDocs ---" "site/" "*/__pycache__/" "*.pyc")

    echo -e "\nConfiguring MkDocs ignores..."

    if [[ -s .gitignore ]] && [[ $(tail -c 1 .gitignore) != $'\n' ]]; then
        echo "" >> .gitignore
    fi
    echo "" >> .gitignore

    for pattern in "${MK_PATTERNS[@]}"; do
        if ! grep -qxF "$pattern" .gitignore; then
            echo "$pattern" >> .gitignore
            echo "Added $pattern to .gitignore"
        else
            echo "$pattern is already ignored."
        fi
    done
fi

if [[ ! "$IGNORE_CHOICE" =~ ^[Yy]$ ]] && [[ ! "$MKDOCS_CHOICE" =~ ^[Yy]$ ]]; then
    echo "No changes made to .gitignore."
fi

echo "------------------------------------------"

LINK_START="\e]8;;"
LINK_END="\e]8;;\e\\\\"
RESET="\e[0m"

printf "Done! : ${LINK_START}%s\e\\\\%s${LINK_END}\n" "$REPO_URL" "Open Repo"
