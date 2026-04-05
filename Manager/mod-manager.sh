#!/bin/bash

CONFIG_FILE="$HOME/.mod-manager.config"

check_dir() {
    if [[ ! -d "$1" ]]; then
        echo "Error: Directory '$1' not found."
        return 1
    fi
    return 0
}

save_games() {
    printf "%s\n" "${games[@]}" > "$CONFIG_FILE"
}

inspect_ini_files() {
    local mod_path="$1"
    echo "--- INI Key Bindings for: $(basename "$mod_path") ---"

    # Find all .ini files (excluding disabled ones)
    mapfile -t ini_files < <(find "$mod_path" -type f -name "*.ini" ! -name "DISABLED*")

    if [ ${#ini_files[@]} -eq 0 ]; then
        echo "No active .ini files found."
        return
    fi

    for ini in "${ini_files[@]}"; do
        echo "File: $(basename "$ini")"

        tr -d '\r' < "$ini" | awk '
            /^[ \t]*;[ \t]*Overrides/ {exit}
            /^\[.*\]/ {
                section=$0
                found_key=0
            }
            /^[ \t]*key[ \t]*=/ {
                sub(/^[ \t]*key[ \t]*=[ \t]*/, "", $0)
                if (!found_key) {
                    print "  " section ":"
                    found_key=1
                }
                print "    -> " $0
            }
        '
    done
    echo "------------------------------------------"
    read -n 1 -s -r -p "Press any key to return..."
}

# --- Main Application Loop ---
while true; do
    if [[ ! -f "$CONFIG_FILE" ]]; then
        touch "$CONFIG_FILE"
    fi

    mapfile -t games < "$CONFIG_FILE"

    clear
    echo "--- CLI XXMI Mod Manager ---"
    for i in "${!games[@]}"; do
        name=$(echo "${games[$i]}" | cut -d: -f1)
        printf "%3d) %-15s \n" "$((i+1))" "$name"
    done
    echo "---------------------"
    echo "  a) Add New Game "
    echo "  e) Edit/Delete Game"
    echo "  q) Quit"
    read -r -p "Selection: " main_choice

    case "$main_choice" in
        q) exit 0 ;;
        a)
            read -p "Enter Game Name: " new_name
            read -p "Enter Full Path: " new_path
            new_path="${new_path/#\~/$HOME}"
            if check_dir "$new_path"; then
                games+=("$new_name:$new_path")
                save_games
            fi
            continue
            ;;
        e)
            read -p "Enter number to manage: " edit_idx
            idx=$((edit_idx-1))
            if [[ $idx -ge 0 && $idx -lt ${#games[@]} ]]; then
                echo "1) Rename  2) Update Path  3) Delete  4) Cancel"
                read -p "Action: " act
                case "$act" in
                    1) read -p "New Name: " nn; games[$idx]="$nn:$(echo "${games[$idx]}" | cut -d: -f2)" ;;
                    2) read -p "New Path: " np; games[$idx]="$(echo "${games[$idx]}" | cut -d: -f1):${np/#\~/$HOME}" ;;
                    3) unset 'games[$idx]'; games=("${games[@]}") ;; # Re-index array
                esac
                save_games
            fi
            continue
            ;;
    esac

    # Validate Selection for entering Mod Menu
    game_idx=$((main_choice-1))
    if [[ $game_idx -lt 0 || $game_idx -ge ${#games[@]} ]]; then
        continue
    fi

    SELECTED_GAME=$(echo "${games[$game_idx]}" | cut -d: -f1)
    MOD_DIR=$(echo "${games[$game_idx]}" | cut -d: -f2)

    # --- Mod Management Loop ---
    while true; do
        cd "$MOD_DIR" || break
        clear
        echo "--- Mods: $SELECTED_GAME ---"
        shopt -s nullglob
        sorted_mods=(*)

        for i in "${!sorted_mods[@]}"; do
            status="[ACTIVE]"
            [[ "${sorted_mods[$i]}" == DISABLED* ]] && status="[OFF]   "
            printf "%3d) %s %s\n" "$((i+1))" "$status" "${sorted_mods[$i]}"
        done

        echo "------------------------"
        echo "Enter number to manage, 'b' for back:"
        read -r choice

        [[ "$choice" == "b" ]] && break

        index=$((choice-1))
        if [[ $index -ge 0 && $index -lt ${#sorted_mods[@]} ]]; then
            filename="${sorted_mods[$index]}"
            echo "Selected: $filename"
            echo "1) Toggle Active/Disabled"
            echo "2) Inspect .ini (Key Bindings)"
            echo "3) Cancel"
            read -r sub_choice

            case "$sub_choice" in
                1)
                    if [[ "$filename" == DISABLED* ]]; then
                        new_name="${filename#DISABLED }"
                        [[ -e "$new_name" ]] && echo "Error: exists" || mv "$filename" "$new_name"
                    else
                        new_name="DISABLED $filename"
                        [[ -e "$new_name" ]] && echo "Error: exists" || mv "$filename" "$new_name"
                    fi
                    ;;
                2)
                    inspect_ini_files "$MOD_DIR/$filename"
                    ;;
            esac
        fi
    done
done
