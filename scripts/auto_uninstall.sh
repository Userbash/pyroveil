#!/usr/bin/env bash
# Pyroveil Universal Uninstaller Script
# Removes all traces of Pyroveil from the user environment, including binaries, configuration, and environment variables.
set -Eeuo pipefail

PREFIX="$HOME/.local"
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.profile"

# Remove Pyroveil shared library and manifest
rm -vf "$PREFIX/lib/libVkLayer_pyroveil_64.so" || true
rm -vf "$PREFIX/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json" || true
# Remove hacks and related configuration
rm -rf "$PREFIX/share/pyroveil" || true
rm -rf "$PREFIX/share/vulkan/implicit_layer.d" || true
rm -rf "$PREFIX/lib" || true
# Remove VK_LAYER_PATH from .bashrc and .profile
sed -i '/VK_LAYER_PATH/d' "$BASHRC" 2>/dev/null || true
sed -i '/VK_LAYER_PATH/d' "$PROFILE" 2>/dev/null || true
# Remove build logs, cache, and source directory
rm -rf "$HOME/.ci/logs" || true
rm -rf "$HOME/.cache/pyroveil" || true
rm -rf "$HOME/pyroveil-src" || true
echo "[auto-uninstall] Pyroveil has been completely removed. Please restart your session or run 'source ~/.bashrc' to clear environment variables."
#!/usr/bin/env bash
# Universal uninstall for Pyroveil (Arch, Bazzite, userland)
set -Eeuo pipefail

PREFIX="$HOME/.local"
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.profile"

rm -vf "$PREFIX/lib/libVkLayer_pyroveil_64.so" || true
rm -vf "$PREFIX/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json" || true
rm -rf "$PREFIX/share/pyroveil" || true
rm -rf "$PREFIX/share/vulkan/implicit_layer.d" || true
rm -rf "$PREFIX/lib" || true
sed -i '/VK_LAYER_PATH/d' "$BASHRC" 2>/dev/null || true
sed -i '/VK_LAYER_PATH/d' "$PROFILE" 2>/dev/null || true
rm -rf "$HOME/.ci/logs" || true
rm -rf "$HOME/.cache/pyroveil" || true
rm -rf "$HOME/pyroveil-src" || true
echo "[auto-uninstall] Pyroveil fully uninstalled. Please restart your session or source ~/.bashrc."#!/usr/bin/env bash
# Universal uninstall for Pyroveil (Arch, Bazzite, userland)
set -Eeuo pipefail

PREFIX="$HOME/.local"
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.profile"

rm -vf "$PREFIX/lib/libVkLayer_pyroveil_64.so" || true
rm -vf "$PREFIX/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json" || true
rm -rf "$PREFIX/share/pyroveil" || true
rm -rf "$PREFIX/share/vulkan/implicit_layer.d" || true
rm -rf "$PREFIX/lib" || true
sed -i '/VK_LAYER_PATH/d' "$BASHRC" 2>/dev/null || true
sed -i '/VK_LAYER_PATH/d' "$PROFILE" 2>/dev/null || true
rm -rf "$HOME/.ci/logs" || true
rm -rf "$HOME/.cache/pyroveil" || true
rm -rf "$HOME/pyroveil-src" || true
echo "[auto-uninstall] Pyroveil fully uninstalled. Please restart your session or source ~/.bashrc."
