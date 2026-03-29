#!/usr/bin/env bash

# Pyroveil installer for Assassin's Creed Shadows on Bazzite.
# Immutable-friendly: no host package install, everything builds in distrobox.

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
CONTAINER_NAME="pyroveil-build"
IMAGE_NAME="fedora:latest"
HOST_HOME="${HOME}"
HOST_PREFIX="${HOST_HOME}/.local"
HACK_NAME="ac-shadows-nvidia-570-stable"
HACK_DST="${HOST_PREFIX}/share/pyroveil/hacks/${HACK_NAME}"
REPO_URL="https://github.com/HansKristian-Work/pyroveil.git"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { printf "%b[%s]%b %s\n" "$BLUE" "$SCRIPT_NAME" "$NC" "$*"; }
ok() { printf "%b[%s]%b %s\n" "$GREEN" "$SCRIPT_NAME" "$NC" "$*"; }
warn() { printf "%b[%s]%b %s\n" "$YELLOW" "$SCRIPT_NAME" "$NC" "$*"; }
err() { printf "%b[%s]%b %s\n" "$RED" "$SCRIPT_NAME" "$NC" "$*" >&2; }

die() {
  err "$*"
  exit 1
}

cleanup_tmp() {
  local rc=$?
  if [[ -n "${TMP_FILE:-}" && -f "${TMP_FILE}" ]]; then
    rm -f "${TMP_FILE}" || true
  fi
  if [[ $rc -ne 0 ]]; then
    err "Script exited with error (code: $rc)."
  fi
}
trap cleanup_tmp EXIT

retry() {
  local tries="$1"
  local delay="$2"
  shift 2

  local i=1
  until "$@"; do
    if (( i >= tries )); then
      return 1
    fi
    warn "Command failed. Retry $i/$((tries - 1)) in ${delay}s: $*"
    sleep "$delay"
    ((i++))
  done
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Command not found: $1"
}

print_jobs() {
  cat <<'EOF'
Jobs and Steps:
1) Host preflight
  - Check required commands
  - Prepare paths in ~/.local
2) Distrobox lifecycle
  - Check if container exists
  - Create container if missing
3) Build and deploy in container
  - Install dependencies with retry
  - Clone repository with retry
  - Parallel steps:
    A) Initialize submodules
    B) Prepare and copy AC Shadows hack
  - Configure CMake (Ninja -> fallback Makefiles)
  - Build and install to host ~/.local
4) Validation and output
  - Check for layer .so/.json and hack config
  - Print Launch Options for Steam
EOF
}

container_exists() {
  distrobox list --no-color 2>/dev/null | awk '{print $1}' | grep -Fxq "$CONTAINER_NAME"
}

ensure_container() {
  log "Job 2/4: checking distrobox container"
  if container_exists; then
    ok "Container already exists: $CONTAINER_NAME"
    return
  fi

  log "Container not found, creating: $CONTAINER_NAME"
  retry 3 3 distrobox create -i "$IMAGE_NAME" -n "$CONTAINER_NAME" --additional-flags "--volume ${HOST_HOME}:/hosthome" -Y
  ok "Container created"
}

prepare_host_paths() {
  log "Job 1/4: preparing host paths"
  mkdir -p "$HOST_PREFIX/share/pyroveil/hacks"
  mkdir -p "$HOST_PREFIX/share/vulkan/implicit_layer.d"
  ok "Paths prepared"
}

build_inside_container() {
  log "Job 3/4: build and install inside container"

  TMP_FILE="$(mktemp)"

  cat >"$TMP_FILE" <<'CONTAINER_SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail

retry() {
  local tries="$1"
  local delay="$2"
  shift 2

  local i=1
  until "$@"; do
    if (( i >= tries )); then
      return 1
    fi
    echo "[container] retry $i/$((tries - 1)) for: $*"
    sleep "$delay"
    ((i++))
  done
}

PROJECT_DIR="/tmp/pyroveil"
PREFIX="/hosthome/.local"
HACK_NAME="ac-shadows-nvidia-570-stable"
HACK_DST="${PREFIX}/share/pyroveil/hacks/${HACK_NAME}"

echo "[container] Installing dependencies"
retry 3 3 sudo dnf -y clean all
retry 3 5 sudo dnf install -y git cmake ninja-build gcc gcc-c++ make

echo "[container] Cloning repository"
rm -rf "$PROJECT_DIR"
retry 3 3 git clone --depth 1 https://github.com/HansKristian-Work/pyroveil.git "$PROJECT_DIR"

cd "$PROJECT_DIR"

echo "[container] Running parallel steps: submodules + hack staging"
(
  set -Eeuo pipefail
  retry 3 3 git submodule update --init --depth 1
) &
pid_submodules=$!

(
  set -Eeuo pipefail
  mkdir -p "$HACK_DST"
  cp -a "hacks/${HACK_NAME}/." "$HACK_DST/"
) &
pid_hack=$!

wait "$pid_submodules"
wait "$pid_hack"

echo "[container] Configuring build"
if ! cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"; then
  echo "[container] Ninja configure failed, trying Unix Makefiles"
  cmake -S . -B build -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
fi

echo "[container] Building and installing"
if [[ -f build/build.ninja ]]; then
  retry 2 3 ninja -C build
  retry 2 3 ninja -C build install
else
  retry 2 3 cmake --build build -j"$(nproc)"
  retry 2 3 cmake --install build
fi

echo "[container] Build+install done"
CONTAINER_SCRIPT

  chmod +x "$TMP_FILE"

  retry 2 2 distrobox enter "$CONTAINER_NAME" -- bash "$TMP_FILE" || return 1
  ok "Build in container completed"
}

validate_install() {
  log "Job 4/4: validating install"

  local layer_so="$HOST_PREFIX/lib/libVkLayer_pyroveil_64.so"
  local layer_json="$HOST_PREFIX/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json"
  local hack_json="$HACK_DST/pyroveil.json"

  [[ -f "$layer_so" ]] || die "Layer .so file not found: $layer_so"
  [[ -f "$layer_json" ]] || die "Layer manifest not found: $layer_json"
  [[ -f "$hack_json" ]] || die "Hack config not found: $hack_json"

  ok "Validation passed: layer and hack config present"
}

print_launch_options() {
  local launch="PYROVEIL=1 PYROVEIL_CONFIG=${HACK_DST}/pyroveil.json PROTON_HIDE_NVIDIA_GPU=1 PROTON_ENABLE_NVAPI=1 %command%"
  printf "\n%s\n" "Steam Launch Options:"
  printf "%s\n\n" "$launch"
}

main() {
  print_jobs
  require_cmd distrobox
  require_cmd awk
  require_cmd grep

  prepare_host_paths
  ensure_container
  build_inside_container
  validate_install
  print_launch_options

  ok "Done: install completed without rpm-ostree layering"
}

main "$@"
