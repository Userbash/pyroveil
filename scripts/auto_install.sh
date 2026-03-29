#!/usr/bin/env bash
# Pyroveil Universal Installer Script
# Installs Pyroveil Vulkan layer in user environment and sets VK_LAYER_PATH globally.
set -Eeuo pipefail

PREFIX="$HOME/.local"
SRC_DIR="$HOME/pyroveil-src"

# Check for required dependencies
git --version >/dev/null 2>&1 || { echo "[auto-install] ERROR: Please install git."; exit 1; }
cmake --version >/dev/null 2>&1 || { echo "[auto-install] ERROR: Please install cmake."; exit 1; }
ninja --version >/dev/null 2>&1 || { echo "[auto-install] ERROR: Please install ninja."; exit 1; }

# Remove previous source directory if it exists
if [[ -d "$SRC_DIR" ]]; then
  rm -rf "$SRC_DIR"
fi

# Clone Pyroveil source code
git clone --depth 1 https://github.com/HansKristian-Work/pyroveil.git "$SRC_DIR"
cd "$SRC_DIR"
git submodule update --init --recursive
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
ninja -C build install

# Register VK_LAYER_PATH globally for all sessions
LAYER_PATH="$PREFIX/share/vulkan/implicit_layer.d"
ENV_LINE="export VK_LAYER_PATH=\"$LAYER_PATH\""
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.profile"
if ! grep -q "VK_LAYER_PATH" "$BASHRC" 2>/dev/null; then
  echo "$ENV_LINE" >> "$BASHRC"
  echo "[auto-install] VK_LAYER_PATH added to $BASHRC."
fi
if [[ -f "$PROFILE" ]] && ! grep -q "VK_LAYER_PATH" "$PROFILE" 2>/dev/null; then
  echo "$ENV_LINE" >> "$PROFILE"
  echo "[auto-install] VK_LAYER_PATH added to $PROFILE."
fi
source "$BASHRC" 2>/dev/null || true
export VK_LAYER_PATH="$LAYER_PATH"
echo "[auto-install] Pyroveil was successfully installed and VK_LAYER_PATH is set. You can now use Pyroveil with any Vulkan application."
#!/usr/bin/env bash
# Universal auto install for Pyroveil (Arch, Bazzite, userland)
set -Eeuo pipefail

PREFIX="$HOME/.local"
SRC_DIR="$HOME/pyroveil-src"

if ! command -v git || ! command -v cmake || ! command -v ninja; then
  echo "[auto-install] Please install git, cmake, ninja first (pacman -S git cmake ninja or dnf install ...)"
  exit 1
fi

if [[ -d "$SRC_DIR" ]]; then
  rm -rf "$SRC_DIR"
fi

git clone --depth 1 https://github.com/HansKristian-Work/pyroveil.git "$SRC_DIR"
cd "$SRC_DIR"
git submodule update --init --recursive
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
ninja -C build install

# Register VK_LAYER_PATH globally
LAYER_PATH="$PREFIX/share/vulkan/implicit_layer.d"
ENV_LINE="export VK_LAYER_PATH=\"$LAYER_PATH\""
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.profile"
if ! grep -q "VK_LAYER_PATH" "$BASHRC" 2>/dev/null; then
  echo "$ENV_LINE" >> "$BASHRC"
fi
if [[ -f "$PROFILE" ]] && ! grep -q "VK_LAYER_PATH" "$PROFILE" 2>/dev/null; then
  echo "$ENV_LINE" >> "$PROFILE"
fi
source "$BASHRC" 2>/dev/null || true
export VK_LAYER_PATH="$LAYER_PATH"
echo "[auto-install] Pyroveil installed and VK_LAYER_PATH set."#!/usr/bin/env bash
# Universal auto install for Pyroveil (Arch, Bazzite, userland)
set -Eeuo pipefail

PREFIX="$HOME/.local"
SRC_DIR="$HOME/pyroveil-src"

if ! command -v git || ! command -v cmake || ! command -v ninja; then
  echo "[auto-install] Please install git, cmake, ninja first (pacman -S git cmake ninja or dnf install ...)"
  exit 1
fi

if [[ -d "$SRC_DIR" ]]; then
  rm -rf "$SRC_DIR"
fi

git clone --depth 1 https://github.com/HansKristian-Work/pyroveil.git "$SRC_DIR"
cd "$SRC_DIR"
git submodule update --init --recursive
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
ninja -C build install

# Register VK_LAYER_PATH globally
LAYER_PATH="$PREFIX/share/vulkan/implicit_layer.d"
ENV_LINE="export VK_LAYER_PATH=\"$LAYER_PATH\""
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.profile"
if ! grep -q "VK_LAYER_PATH" "$BASHRC" 2>/dev/null; then
  echo "$ENV_LINE" >> "$BASHRC"
fi
if [[ -f "$PROFILE" ]] && ! grep -q "VK_LAYER_PATH" "$PROFILE" 2>/dev/null; then
  echo "$ENV_LINE" >> "$PROFILE"
fi
source "$BASHRC" 2>/dev/null || true
export VK_LAYER_PATH="$LAYER_PATH"
echo "[auto-install] Pyroveil installed and VK_LAYER_PATH set."