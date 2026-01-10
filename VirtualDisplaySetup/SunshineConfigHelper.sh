#!/usr/bin/env bash
set -e

echo "Detecting displays..."
echo

mapfile -t OUTPUTS < <(kscreen-doctor -o | awk '/Output:/ {print $3}')

if [[ ${#OUTPUTS[@]} -eq 0 ]]; then
    echo "❌ No displays detected."
    exit 1
fi

echo "Detected outputs:"
for i in "${!OUTPUTS[@]}"; do
    echo "  [$i] ${OUTPUTS[$i]}"
done

echo
read -p "Select VIRTUAL display index: " VIRT_IDX
VIRTUAL="${OUTPUTS[$VIRT_IDX]}"

echo
read -p "Select PRIMARY display index: " PRI_IDX
PRIMARY="${OUTPUTS[$PRI_IDX]}"

echo
echo "Generated Sunshine commands:"
echo

echo "🔹 Do:"
echo "/usr/bin/kscreen-doctor \\"
echo "  output.$PRIMARY.disable \\"
echo "  output.$VIRTUAL.enable \\"
echo "  output.$VIRTUAL.primary"
echo

echo "🔹 Undo:"
echo "/usr/bin/kscreen-doctor \\"
echo "  output.$PRIMARY.enable \\"
echo "  output.$PRIMARY.primary"
