# Pyroveil Full Manual Uninstall Script
# Removes all files, configuration, and environment variables related to Pyroveil from the user environment.
set -Eeuo pipefail

echo "[uninstall_pyroveil] Starting full removal of Pyroveil and all related files..."

PREFIX="${1:-$HOME/.local}"
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
# Remove build logs and cache
rm -rf "$HOME/.ci/logs" || true
rm -rf "$HOME/.cache/pyroveil" || true

echo "[uninstall_pyroveil] Pyroveil has been fully removed. Please restart your session or run 'source ~/.bashrc' to clear environment variables."
#!/usr/bin/env bash

set -Eeuo pipefail

echo "[uninstall_pyroveil] Полное удаление Pyroveil и всех следов..."

PREFIX="${1:-$HOME/.local}"
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.profile"

# Удаление файлов и директорий
rm -vf "$PREFIX/lib/libVkLayer_pyroveil_64.so" || true
rm -vf "$PREFIX/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json" || true
rm -rf "$PREFIX/share/pyroveil" || true
rm -rf "$PREFIX/share/vulkan/implicit_layer.d" || true
rm -rf "$PREFIX/lib" || true

# Удаление переменных из bashrc/profile
sed -i '/VK_LAYER_PATH/d' "$BASHRC" 2>/dev/null || true
sed -i '/VK_LAYER_PATH/d' "$PROFILE" 2>/dev/null || true

# Удаление логов и временных файлов
rm -rf "$HOME/.ci/logs" || true
rm -rf "$HOME/.cache/pyroveil" || true

echo "[uninstall_pyroveil] Удаление завершено. Рекомендуется перезапустить сессию или выполнить 'source ~/.bashrc' для сброса переменных."#!/usr/bin/env bash

set -Eeuo pipefail

echo "[uninstall_pyroveil] Полное удаление Pyroveil и всех следов..."

PREFIX="${1:-$HOME/.local}"
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.profile"

# Удаление файлов и директорий
rm -vf "$PREFIX/lib/libVkLayer_pyroveil_64.so" || true
rm -vf "$PREFIX/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json" || true
rm -rf "$PREFIX/share/pyroveil" || true
rm -rf "$PREFIX/share/vulkan/implicit_layer.d" || true
rm -rf "$PREFIX/lib" || true

# Удаление переменных из bashrc/profile
sed -i '/VK_LAYER_PATH/d' "$BASHRC" 2>/dev/null || true
sed -i '/VK_LAYER_PATH/d' "$PROFILE" 2>/dev/null || true

# Удаление логов и временных файлов
rm -rf "$HOME/.ci/logs" || true
rm -rf "$HOME/.cache/pyroveil" || true

echo "[uninstall_pyroveil] Удаление завершено. Рекомендуется перезапустить сессию или выполнить 'source ~/.bashrc' для сброса переменных."