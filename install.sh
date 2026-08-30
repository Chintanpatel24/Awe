#!/usr/bin/env bash

set -e

CONFIG_DIR="${HOME}/.config/quickshell"
AUTOSTART_DIR="${HOME}/.config/autostart"
DESKTOP_FILE="${AUTOSTART_DIR}/quickshell-widgets.desktop"

echo "Installing Quickshell Material 3 Desktop Widgets..."

mkdir -p "$CONFIG_DIR"
mkdir -p "$AUTOSTART_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Copying widget files to ${CONFIG_DIR}..."
cp -r "${SCRIPT_DIR}"/*.qml "${CONFIG_DIR}/"

if [ -f "${SCRIPT_DIR}/widget_settings.json" ] && [ ! -f "${CONFIG_DIR}/widget_settings.json" ]; then
    cp "${SCRIPT_DIR}/widget_settings.json" "${CONFIG_DIR}/"
fi

echo "Creating autostart entry at ${DESKTOP_FILE}..."
cat << 'EOF' > "$DESKTOP_FILE"
[Desktop Entry]
Type=Application
Name=Quickshell Desktop Widgets
Comment=Material 3 Wayland Desktop Widgets
Exec=quickshell -c ~/.config/quickshell/shell.qml
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

chmod +x "$DESKTOP_FILE"

echo "Installation complete!"
echo "You can launch the widgets now with: quickshell -c ~/.config/quickshell/shell.qml"
