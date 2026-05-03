#!/usr/bin/env bash

command -v jq >/dev/null 2>&1 || { echo >&2 "This script require 'jq' but it's not installed. Aborting."; exit 1; }

SUNSHINE_APPS="$HOME/.config/sunshine/apps.json"

# --- Visual Banner ---
clear
echo "=========================================================="
echo "  ____                _     _             "
echo " / ___| _   _ _ __  _| |__ (_)_ __   ___  "
echo " \___ \| | | | '_ \| __| '_ \| | '_ \ / _ \ "
echo "  ___) | |_| | | | | |_| | | | | | | |  __/ "
echo " |____/ \__,_|_| |_|\__|_| |_|_|_| |_|\___| "
echo "  ____             _____ _         _   _      "
echo " / ___|___  _ __  |  ___(_) __ _  | | | | ___ | |_ __   ___ _ __ "
echo "| |   / _ \| '_ \ | |_  | |/ _\` | | |_| |/ _ \| | '_ \ / _ \ '__|"
echo "| |__| (_) | | | ||  _| | | (_| | |  _  |  __/| | |_) |  __/ |   "
echo " \____\___/|_| |_||_|   |_|\__, | |_| |_|\___||_|_.__/ \___|_|   "
echo "                           |___/                                 "
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

echo "Detecting displays..."
mapfile -t OUTPUTS < <(kscreen-doctor -o | awk '/Output:/ {print $3}')

# --- Profile Creation Loop ---
while true; do
    echo "----------------------------------------------------------"
    echo "-- CURRENT DISPLAYS DETECTED:"
    for i in "${!OUTPUTS[@]}"; do echo "  [$i] ${OUTPUTS[$i]}"; done
    echo

    # DETECT EXISTING APPS
    mapfile -t EXISTING_APPS < <(jq -r '.apps[].name' "$SUNSHINE_APPS")

    echo "EXISTING SUNSHINE PROFILE:"
    for i in "${!EXISTING_APPS[@]}"; do
        echo "  [$i] ${EXISTING_APPS[$i]}"
    done
    echo "  [n] Create New Profile"
    echo

    read -p "Select index to update OR 'Any key' for new: " APP_CHOICE

    if [[ "$APP_CHOICE" =~ ^[0-9]+$ ]] && [[ "$APP_CHOICE" -lt "${#EXISTING_APPS[@]}" ]]; then
        APP_NAME="${EXISTING_APPS[$APP_CHOICE]}"
        echo "Updating: $APP_NAME"
    else
        read -p "Enter new Profile Name: " NEW_NAME
        APP_NAME="${NEW_NAME:-Desktop (Custom)}"
    fi

    # DRAG & DROP SECTION
    while true; do
        echo "Drag and drop the image into the terminal (or type path):"
        read -r RAW_IMG_PATH
        APP_IMG=$(clean_path "$RAW_IMG_PATH")
        APP_IMG="${APP_IMG:-desktop.png}"

        if [[ "$APP_IMG" == *.png ]] || [[ "$APP_IMG" == *.jpg ]]; then
             if [[ "$APP_IMG" == */* ]] && [[ ! -f "$APP_IMG" ]]; then
                echo "File not found at: $APP_IMG. Try again."
                continue
             fi
        fi
        break
    done

    echo
    read -p "Select VIRTUAL display index: " VIRT_IDX
    VIRTUAL="${OUTPUTS[$VIRT_IDX]}"

    read -p "Select PRIMARY display index: " PRI_IDX
    PRIMARY="${OUTPUTS[$PRI_IDX]}"

    read -p "Scale (e.g. 1.25, 1.5 or leave blank): " SCALE



    # Build commands
    DO_CMD="/usr/bin/kscreen-doctor output.$PRIMARY.disable output.$VIRTUAL.enable"
    [[ -n "$SCALE" ]] && DO_CMD+=" output.$VIRTUAL.scale.$SCALE"
    DO_CMD+=" output.$VIRTUAL.primary"

    UNDO_CMD="/usr/bin/kscreen-doctor output.$PRIMARY.enable output.$VIRTUAL.disable output.$PRIMARY.primary"

    echo "Updating Sunshine configuration..."
    update_sunshine_json "$APP_NAME" "$APP_IMG" "$DO_CMD" "$UNDO_CMD"
    echo "Success! Added/Updated: $APP_NAME"
    echo

    read -p "Add another profile? (y/N): " AGAIN
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
