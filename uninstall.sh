#!/usr/bin/env bash

set -e

CONFIG_DIR="${HOME}/.config/quickshell"
AUTOSTART_DIR="${HOME}/.config/autostart"
DESKTOP_FILE="${AUTOSTART_DIR}/quickshell-widgets.desktop"

echo "Uninstalling Quickshell Material 3 Desktop Widgets..."

if pgrep -f "quickshell" >/dev/null 2>&1; then
    echo "Stopping running quickshell instances..."
    pkill -f "quickshell" 2>/dev/null || true
fi

if [ -f "$DESKTOP_FILE" ]; then
    echo "Removing autostart entry..."
    rm -f "$DESKTOP_FILE"
fi

if [ -d "$CONFIG_DIR" ]; then
    echo "Removing widget files from ${CONFIG_DIR}..."
    rm -f "${CONFIG_DIR}"/*.qml
fi

echo "Uninstallation complete!"
