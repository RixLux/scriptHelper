#!/usr/bin/env bash
set -e

DEFAULT_EDID_URL="https://git.linuxtv.org/v4l-utils.git/plain/utils/edid-decode/data/acer-xv273k-hdmi1"
DEFAULT_EDID_NAME="acer-xv273k-hdmi1"
FW_DIR="/usr/local/lib/firmware"
OUTPUT="HDMI-A-1"
TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

ensure_bin_suffix() {
    local name="$1"
    [[ "$name" == *.bin ]] && echo "$name" || echo "$name.bin"
}


echo "-----EDID setup Helper-----"
echo "You can:"
echo "  1) Use the default EDID (Acer XV273K HDMI)"
echo "  2) Pick your own EDID file"
echo

read -p "Choose [1/2] (default: 1): " choice
choice=${choice:-1}

if [[ "$choice" == "2" ]]; then
    echo
    echo "EDID Source link:"
    echo "https://git.linuxtv.org/v4l-utils.git/tree/utils/edid-decode/data"
    echo
    echo "📂 Download an EDID file, then DRAG & DROP it here:"

    read -r EDID_PATH

    if [[ ! -f "$EDID_PATH" ]]; then
        echo "❌ File not found"
        exit 1
    fi

    RAW_NAME="$(basename "$EDID_PATH")"
    EDID_NAME="$(ensure_bin_suffix "$RAW_NAME")"
    cp "$EDID_PATH" "$TMP_DIR/$EDID_NAME"


else
    echo
    echo "Downloading default EDID..."
    RAW_NAME="$DEFAULT_EDID_NAME"
    EDID_NAME="$(ensure_bin_suffix "$RAW_NAME")"
    curl -L "$DEFAULT_EDID_URL" -o "$TMP_DIR/$EDID_NAME"

fi

echo
echo "📁 Creating firmware directory..."
sudo mkdir -p "$FW_DIR"

echo "📦 Installing EDID firmware..."
sudo cp "$TMP_DIR/$EDID_NAME" "$FW_DIR/$EDID_NAME"

echo
echo "Appending kernel arguments..."
sudo rpm-ostree kargs \
  --append-if-missing="firmware_class.path=$FW_DIR" \
  --append-if-missing="drm.edid_firmware=$OUTPUT:$EDID_NAME" \
  --append-if-missing="video=$OUTPUT:e"

echo
echo "✅ EDID configured successfully!"
echo "🔁 Reboot required to apply changes."

read -p "Reboot now? (y/N): " r
[[ "$r" == "y" ]] && systemctl reboot
