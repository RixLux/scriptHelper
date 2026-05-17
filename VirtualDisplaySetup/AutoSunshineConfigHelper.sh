#!/usr/bin/env bash

command -v jq >/dev/null 2>&1 || { echo >&2 "This script require 'jq' but it's not installed. Aborting."; exit 1; }

SUNSHINE_APPS="$HOME/.config/sunshine/apps.json"

# --- Visual Banner ---
print_banner() {
    local text="$1"

    if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
        figlet "$text" | lolcat -a
    elif command -v figlet >/dev/null 2>&1; then
        figlet "$text"
    else
        # Fallback to plain text if tools are missing
        echo "=== $text ==="
    fi
}
clear
echo "=========================================================="
print_banner "Sunshine"
print_banner "Config"
echo "=========================================================="
echo "                  Simplify --- Config                    "
echo "=========================================================="
echo

# Function to clean paths (removes quotes added by terminal drag & drop)
clean_path() {
    echo "$1" | sed "s/['\"]//g" | xargs
}

update_sunshine_json() {
    local name="$1"
    local img="$2"
    local do_cmd="$3"
    local undo_cmd="$4"

    cp "$SUNSHINE_APPS" "$SUNSHINE_APPS.bak"

    jq \
      --arg name "$name" \
      --arg img "$img" \
      --arg do "$do_cmd" \
      --arg undo "$undo_cmd" '
      .apps |= (
        if any(.[]; .name == $name) then
          map(
            if .name == $name then
              .["prep-cmd"] = [{ "do": $do, "undo": $undo }] | .["image-path"] = $img
            else .
            end
          )
        else
          . + [{
            "name": $name,
            "image-path": $img,
            "auto-detach": true,
            "wait-all": true,
            "exit-timeout": 5,
            "prep-cmd": [{ "do": $do, "undo": $undo }]
          }]
        end
      )
    ' "$SUNSHINE_APPS.bak" > "$SUNSHINE_APPS"
}

# --- Initialization ---
if [[ ! -f "$SUNSHINE_APPS" ]]; then
    echo "$SUNSHINE_APPS not found"
    exit 1
fi

# --- Profile Creation Loop ---
while true; do
    echo "----------------------------------------------------------"
    echo "Detecting displays..."
    mapfile -t OUTPUTS < <(kscreen-doctor -o | awk '/Output:/ {print $3}')
    for i in "${!OUTPUTS[@]}"; do echo "  [$i] ${OUTPUTS[$i]}"; done
    echo

    mapfile -t EXISTING_APPS < <(jq -r '.apps[].name' "$SUNSHINE_APPS")

    echo "EXISTING PROFILES:"
    for i in "${!EXISTING_APPS[@]}"; do echo "  [$i] ${EXISTING_APPS[$i]}"; done
    echo "  [n] Create New Profile"
    echo
    read -p "Selection: " APP_CHOICE

    # Reset variables
    CURRENT_IMG=""
    PREV_VIRT=""
    PREV_PRI=""
    PREV_SCALE=""

    if [[ "$APP_CHOICE" =~ ^[0-9]+$ ]] && [[ "$APP_CHOICE" -lt "${#EXISTING_APPS[@]}" ]]; then
        APP_NAME="${EXISTING_APPS[$APP_CHOICE]}"
        echo "Editing: $APP_NAME"

        # 1. Fetch existing Image
        CURRENT_IMG=$(jq -r ".apps[$APP_CHOICE][\"image-path\"]" "$SUNSHINE_APPS")

        # 2. Fetch existing DO command to extract old display names
        EXISTING_DO=$(jq -r ".apps[$APP_CHOICE][\"prep-cmd\"][0].do" "$SUNSHINE_APPS")

        # Extract Display Names using regex/sed from the command string
        # Logic: find 'output.NAME.disable' and 'output.NAME.enable'
        PREV_PRI=$(echo "$EXISTING_DO" | sed -n 's/.*output\.\([^ ]*\)\.disable.*/\1/p')
        PREV_VIRT=$(echo "$EXISTING_DO" | sed -n 's/.*output\.\([^ ]*\)\.enable.*/\1/p')
        PREV_SCALE=$(echo "$EXISTING_DO" | sed -n 's/.*scale\.\([0-9.]*\).*/\1/p')
    else
        read -p "Enter new Profile Name: " APP_NAME
        APP_NAME="${APP_NAME:-Desktop (Custom)}"
    fi

    # --- IMAGE PATH ---
    echo "Current Image: ${CURRENT_IMG:-None}"
    read -p "New Image (Drag & Drop or Enter to keep): " RAW_IMG_PATH
    APP_IMG=$(clean_path "$RAW_IMG_PATH")
    APP_IMG="${APP_IMG:-$CURRENT_IMG}"
    APP_IMG="${APP_IMG:-desktop.png}" # Absolute fallback

    # --- DISPLAY SELECTION ---
    echo "--- Select VIRTUAL display ---"
    [[ -n "$PREV_VIRT" ]] && echo "Current: $PREV_VIRT"
    read -p "Index (Enter to keep current): " VIRT_IDX
    if [[ -z "$VIRT_IDX" ]]; then
        VIRTUAL="$PREV_VIRT"
    else
        VIRTUAL="${OUTPUTS[$VIRT_IDX]}"
    fi

    echo "--- Select PRIMARY display (to disable) ---"
    [[ -n "$PREV_PRI" ]] && echo "Current: $PREV_PRI"
    read -p "Index (Enter to keep current): " PRI_IDX
    if [[ -z "$PRI_IDX" ]]; then
        PRIMARY="$PREV_PRI"
    else
        PRIMARY="${OUTPUTS[$PRI_IDX]}"
    fi

    # Check if there is still an empty variables (for new profiles)
    if [[ -z "$VIRTUAL" || -z "$PRIMARY" ]]; then
        echo "Error: You must select displays for a new profile!"
        continue
    fi

    read -p "Scale [Current: ${PREV_SCALE:-1}]: " SCALE
    SCALE="${SCALE:-$PREV_SCALE}"

    # Build commands
    DO_CMD="/usr/bin/kscreen-doctor output.$PRIMARY.disable output.$VIRTUAL.enable"
    [[ -n "$SCALE" ]] && DO_CMD+=" output.$VIRTUAL.scale.$SCALE"
    DO_CMD+=" output.$VIRTUAL.primary"

    UNDO_CMD="/usr/bin/kscreen-doctor output.$PRIMARY.enable output.$VIRTUAL.disable output.$PRIMARY.primary"

    echo "Updating Sunshine configuration..."
    update_sunshine_json "$APP_NAME" "$APP_IMG" "$DO_CMD" "$UNDO_CMD"
    echo "Success! Added/Updated: $APP_NAME"
    echo

    read -p "Add/Edit another? (y/N): " AGAIN
    [[ "$AGAIN" =~ ^[Yy]$ ]] || break
done

# --- Final Restart Prompt ---
echo "----------------------------------------------------------"
read -p "Restart Sunshine now to apply changes? (y/N): " RESTART

if [[ "$RESTART" =~ ^[Yy]$ ]]; then
    ERROR_MSG=$(systemctl --user restart homebrew.sunshine 2>&1 >/dev/null) || ERROR_MSG2=$(systemctl --user restart homebrew.sunshine-bet 2>&1 >/dev/null)

    if [ $? -eq 0 ]; then
        echo "Sunshine restarted successfully!"
    else
        echo "Error: Both stable and beta services failed to restart."
        echo "first error: $ERROR_MSG"
        echo "second error: $ERROR_MSG2"
        echo "Check this link : https://docs.bazzite.gg/Advanced/sunshine-brew/ for more detail because it seem you might have not set it up yet."
    fi
else
    echo "Note: You will need to restart Sunshine for changes to take effect."
fi
