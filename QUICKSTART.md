# Quick Start Guide

## What is PyroVeil?

A Vulkan layer that patches shaders on NVIDIA drivers to fix compatibility issues. Install it once, and supported games just work.

## Installation

### Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/HansKristian-Work/pyroveil/main/install-pyroveil.sh | bash
```

Or download manually:

```bash
wget https://raw.githubusercontent.com/HansKristian-Work/pyroveil/main/install-pyroveil.sh
chmod +x install-pyroveil.sh
./install-pyroveil.sh
```

Supported systems: Fedora/Bazzite (immutable), Arch Linux, Debian/Ubuntu, Generic Linux

## Usage

### Steam Games

PyroVeil auto-detects supported games. Just launch your game normally - no configuration needed.

To verify it's working:

```bash
steam 2>&1 | grep pyroveil

# You should see:
# pyroveil: [AutoDetect] Starting automatic game detection...
# pyroveil: [AutoDetect] Detected Steam AppID: 2778720
# pyroveil: [AutoDetect] Found config for AppID 2778720: Assassin's Creed Shadows
```

### Supported Games

| Game | Auto-Detect |
|------|-------------|
| Assassin's Creed Shadows | Yes |
| Final Fantasy VII Rebirth | Yes |
| Monster Hunter Wilds Benchmark | Yes |
| Roadcraft | Yes |
| Surviving Mars: Relaunched | Yes |

Check for updates:
```bash
pyroveil-auto-detect list
```

## Manual Configuration

For non-Steam games or custom configs:

```bash
export PYROVEIL_CONFIG=~/.local/share/pyroveil/hacks/GAME_NAME/pyroveil.json
./game_executable
```

Environment variables:

```bash
PYROVEIL_CONFIG=/path/to/pyroveil.json  # Manual config override
PYROVEIL_CONFIG_BASE=~/.local/share/pyroveil/hacks  # Custom config directory
PYROVEIL_DATABASE=~/.local/share/pyroveil/database.json  # Custom database
VK_LOADER_LAYERS_DISABLE=VK_LAYER_pyroveil  # Disable PyroVeil
```

## Troubleshooting

### PyroVeil Not Loading

Check installation:

```bash
ls -l ~/.local/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json
ls -l ~/.local/lib/libVkLayer_pyroveil_64.so
vulkaninfo --summary | grep pyroveil
```

### Game Not Detected

```bash
pyroveil-auto-detect list
SteamAppId=2778720 pyroveil-auto-detect test

# Find Steam AppID
ls ~/.steam/steam/steamapps/appmanifest_*.acf | sed 's/.*_\([0-9]*\)\.acf/\1/'
```

### No Shader Fixes Applied

```bash
VK_LOADER_DEBUG=all your_game 2>&1 | grep -i pyroveil
```

Common issues:
- Wrong config path (verify with `echo $PYROVEIL_CONFIG`)
- Missing database (check `~/.local/share/pyroveil/database.json`)
- Unsupported game (add to database)

## Adding New Games

Update database:

```bash
pyroveil-update-database
```

Or manually edit `~/.local/share/pyroveil/database.json`:

```json
{
  "games": {
    "YOUR_STEAM_APPID": {
      "name": "Game Name",
      "config": "path/to/pyroveil.json",
      "process": "game_process_name"
    }
  }
}
```

## Uninstall

Quick uninstall:

```bash
~/.local/share/pyroveil/scripts/uninstall_pyroveil.sh
```

Manual removal:

```bash
rm ~/.local/lib/libVkLayer_pyroveil_64.so
rm ~/.local/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json
rm -rf ~/.local/share/pyroveil
```

## Performance

Typical overhead:
- First launch: +50-200ms (shader compilation)
- Runtime: <1% FPS impact
- Memory: +50MB

## Build from Source

```bash
git clone https://github.com/HansKristian-Work/pyroveil.git
cd pyroveil
git submodule update --init --recursive
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
ninja -C build
ninja -C build install
```

Debug build:

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Debug
export VK_LOADER_DEBUG=all
```

## FAQ

**Q: Does PyroVeil work with Proton?**  
Yes, works with both native Linux games and Windows games through Proton.

**Q: Will this break my games?**  
No. PyroVeil only applies fixes to games that need them.

**Q: Does this void my warranty?**  
No. PyroVeil doesn't modify game files or drivers.

**Q: Can I use this with other Vulkan layers?**  
Yes, compatible with DXVK and other Vulkan layers.

**Q: Is this open source?**  
Yes, under MIT license.

## Reporting Issues

Found a bug? Submit to GitHub Issues: https://github.com/HansKristian-Work/pyroveil/issues

Include:
- Game name and Steam AppID
- Linux distribution and version
- NVIDIA driver version
- PyroVeil version
- Error messages from logs

## Additional Resources

- Full documentation: [README.md](README.md)
- Testing guide: [scripts/README-TESTING.md](scripts/README-TESTING.md)
- CI/CD examples: [CI-CD-EXAMPLES.md](CI-CD-EXAMPLES.md)
