#!/usr/bin/env bash
# Common utility functions and hooks for Pyroveil automation scripts
set -Eeuo pipefail

# Pre-install hook: check disk space, environment, Steam processes
pre_install_hook() {
  # Check free space (at least 500MB recommended)
  local free_mb=$(df --output=avail "$HOME" | tail -1)
  if [[ "$free_mb" -lt 512000 ]]; then
    echo "[pre-install] ERROR: Not enough free space in $HOME. At least 500MB required." >&2
    exit 1
  fi
  # Check if Steam is running
  if pgrep -x steam >/dev/null; then
    echo "[pre-install] WARNING: Steam is running. Please close Steam before installing Pyroveil." >&2
    return 1
  fi
  # Check VK_LAYER_PATH is not set to a conflicting value
  if [[ -n "${VK_LAYER_PATH:-}" && ! "$VK_LAYER_PATH" =~ pyroveil ]]; then
    echo "[pre-install] WARNING: VK_LAYER_PATH is set to a non-Pyroveil value: $VK_LAYER_PATH" >&2
    return 1
  fi
  return 0
}

# Post-install hook: verify VK_LAYER_PATH and layer files
post_install_hook() {
  # Check VK_LAYER_PATH in environment
  if ! printenv VK_LAYER_PATH | grep -q pyroveil; then
    echo "[post-install] ERROR: VK_LAYER_PATH is not set or does not contain 'pyroveil'." >&2
    return 1
  fi
  # Check layer files
  local so="$HOME/.local/lib/libVkLayer_pyroveil_64.so"
  local json="$HOME/.local/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json"
  if [[ ! -r "$so" ]]; then
    echo "[post-install] ERROR: Layer .so file not found or not readable: $so" >&2
    return 1
  fi
  if [[ ! -r "$json" ]]; then
    echo "[post-install] ERROR: Layer .json manifest not found or not readable: $json" >&2
    return 1
  fi
  return 0
}

# Pre-uninstall hook: warn if Steam or games are running
pre_uninstall_hook() {
  if pgrep -x steam >/dev/null; then
    echo "[pre-uninstall] WARNING: Steam is running. Please close Steam before uninstalling Pyroveil." >&2
    return 1
  fi
  return 0
}

# Post-uninstall hook: verify removal
post_uninstall_hook() {
  if [[ -e "$HOME/.local/lib/libVkLayer_pyroveil_64.so" || -e "$HOME/.local/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json" ]]; then
    echo "[post-uninstall] WARNING: Some Pyroveil files remain after uninstall." >&2
    return 1
  fi
  return 0
}

# Usage: source scripts/common.sh in all automation scripts
