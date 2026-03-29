# PyroVeil

PyroVeil is a Vulkan layer for NVIDIA shader compatibility. It intercepts shader creation, applies game-specific fixes, and can cache patched shaders for faster startup.

## Features

- Automatic game detection (Steam AppID, process, path, runtime hints)
- Preconfigured fixes for many games
- Shader roundtrip pipeline with SPIRV-Cross and glslang
- Optional cache for already-patched shaders
- Works on mutable and immutable Linux distributions

## Requirements

- Vulkan-capable system with NVIDIA driver
- CMake + Ninja + C++ compiler
- Git (with submodules)
- jq (recommended for auto-detect and database tooling)

## Installation

### Fedora

```bash
sudo dnf install -y git cmake ninja-build gcc-c++ vulkan-headers jq

git clone https://github.com/HansKristian-Work/pyroveil.git
cd pyroveil
git submodule update --init --recursive
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/.local
ninja -C build install
```

### Bazzite / Fedora Silverblue / Kinoite

```bash
# Option A: quick installer (recommended for immutable systems)
curl -sSL https://raw.githubusercontent.com/HansKristian-Work/pyroveil/main/install-pyroveil.sh | bash
```

```bash
# Option B: manual layered dependencies + local build
rpm-ostree install git cmake ninja-build gcc-c++ vulkan-headers jq
systemctl reboot
```

### Arch Linux / EndeavourOS / Manjaro

```bash
sudo pacman -S --needed git cmake ninja gcc vulkan-headers jq

git clone https://github.com/HansKristian-Work/pyroveil.git
cd pyroveil
git submodule update --init --recursive
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/.local
ninja -C build install
```

### Debian / Ubuntu / Pop!_OS

```bash
sudo apt update
sudo apt install -y git cmake ninja-build g++ libvulkan-dev jq

git clone https://github.com/HansKristian-Work/pyroveil.git
cd pyroveil
git submodule update --init --recursive
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/.local
ninja -C build install
```

### openSUSE (Tumbleweed / Leap)

```bash
sudo zypper install -y git cmake ninja gcc-c++ vulkan-headers jq

git clone https://github.com/HansKristian-Work/pyroveil.git
cd pyroveil
git submodule update --init --recursive
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/.local
ninja -C build install
```

## Steam Usage

### Native Steam (all distributions)

Set this launch option for a game:

```bash
PYROVEIL=1 %command%
```

### Flatpak Steam

If you install PyroVeil into your user prefix and Steam runs in Flatpak, use:

```bash
PYROVEIL=1 VK_LAYER_PATH=$HOME/.local/share/vulkan/implicit_layer.d %command%
```

If you intentionally installed into Flatpak local path, use:

```bash
PYROVEIL=1 VK_LAYER_PATH=$HOME/.var/app/com.valvesoftware.Steam/.local/share/vulkan/implicit_layer.d %command%
```

### Lutris / Heroic

Set environment variables in the game launcher:

```bash
PYROVEIL=1
VK_LAYER_PATH=$HOME/.local/share/vulkan/implicit_layer.d
```

## Auto-Detection Tools

```bash
# List supported games from local database
scripts/pyroveil-auto-detect.sh list

# Test a specific Steam AppID
scripts/pyroveil-auto-detect.sh check 2778720

# Update game database
scripts/pyroveil-update-database.sh update
```

## Build and Test

```bash
# Full validation suite
scripts/run-full-validation.sh

# Comprehensive checks (supports --quick, --skip-build, --auto-fix)
scripts/comprehensive-test.sh --quick

# Module tests
scripts/test-modules.sh

# Logging tests
scripts/test-logging.sh
```

## Uninstall

```bash
scripts/uninstall_pyroveil.sh
```

Or with custom prefix:

```bash
scripts/uninstall_pyroveil.sh /path/to/prefix
```

## Troubleshooting

### Layer not loaded

```bash
vulkaninfo --summary | grep -i pyroveil
ls -l $HOME/.local/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json
ls -l $HOME/.local/lib/libVkLayer_pyroveil_64.so
```

### Auto-detection did not find a config

```bash
scripts/pyroveil-auto-detect.sh detect
scripts/pyroveil-auto-detect.sh list
```

### Manual config override

```bash
PYROVEIL=1 PYROVEIL_CONFIG=/absolute/path/to/pyroveil.json %command%
```

## License

MIT. See LICENSE.
