# Pyroveil Universal Rebuild Script
# Updates the Pyroveil source code and rebuilds the layer for the user environment.
set -Eeuo pipefail

PREFIX="$HOME/.local"
SRC_DIR="$HOME/pyroveil-src"

if [[ -d "$SRC_DIR" ]]; then
  cd "$SRC_DIR"
  # Update source code and submodules
  git pull
  git submodule update --init --recursive
  # Reconfigure and rebuild
  cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
  ninja -C build install
  echo "[auto-rebuild] Pyroveil has been rebuilt and reinstalled."
else
  echo "[auto-rebuild] ERROR: Source directory not found. Please run auto_install.sh first."
  exit 1
fi
#!/usr/bin/env bash
# Universal rebuild for Pyroveil (Arch, Bazzite, userland)
set -Eeuo pipefail

PREFIX="$HOME/.local"
SRC_DIR="$HOME/pyroveil-src"
if [[ -d "$SRC_DIR" ]]; then
  cd "$SRC_DIR"
  git pull
  git submodule update --init --recursive
  cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
  ninja -C build install
  echo "[auto-rebuild] Pyroveil rebuilt and reinstalled."
else
  echo "[auto-rebuild] Source not found. Run auto_install.sh first."
  exit 1
fi#!/usr/bin/env bash
# Universal rebuild for Pyroveil (Arch, Bazzite, userland)
set -Eeuo pipefail

PREFIX="$HOME/.local"
SRC_DIR="$HOME/pyroveil-src"
if [[ -d "$SRC_DIR" ]]; then
  cd "$SRC_DIR"
  git pull
  git submodule update --init --recursive
  cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
  ninja -C build install
  echo "[auto-rebuild] Pyroveil rebuilt and reinstalled."
else
  echo "[auto-rebuild] Source not found. Run auto_install.sh first."
  exit 1
fi
