#!/usr/bin/env bash
# PyroVeil full uninstall script.
# Removes installed layer files, local game database/configs, and shell env entries.

set -Eeuo pipefail

PREFIX="${1:-$HOME/.local}"
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.profile"

log() {
    echo "[uninstall_pyroveil] $*"
}

log "Starting full removal of PyroVeil and related files..."

# Remove layer library and manifest.
rm -vf "$PREFIX/lib/libVkLayer_pyroveil_64.so" || true
rm -vf "$PREFIX/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json" || true

# Remove PyroVeil data and helper scripts installed under PREFIX.
rm -rf "$PREFIX/share/pyroveil" || true
rm -vf "$PREFIX/bin/pyroveil-auto-detect" || true
rm -vf "$PREFIX/bin/pyroveil-update-database" || true

# Remove generated logs and cache.
rm -rf "$HOME/.cache/pyroveil" || true
rm -rf "$HOME/.ci/logs" || true

# Remove exported VK_LAYER_PATH lines from shell startup files.
sed -i '/# PyroVeil Vulkan Layer/d' "$BASHRC" 2>/dev/null || true
sed -i '/VK_LAYER_PATH/d' "$BASHRC" 2>/dev/null || true
sed -i '/# PyroVeil Vulkan Layer/d' "$PROFILE" 2>/dev/null || true
sed -i '/VK_LAYER_PATH/d' "$PROFILE" 2>/dev/null || true

log "Uninstall complete. Restart your shell session or run: source ~/.bashrc"
