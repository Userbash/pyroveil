# PyroVeil

Vulkan layer for shader compatibility on NVIDIA drivers. Intercepts shader creation calls and patches them on-the-fly using SPIRV-Cross/glslang pipeline or loads pre-patched versions from cache.

## Features

- Automatic game detection via Steam AppID
- Database-driven configuration (no manual setup for supported games)
- Works on immutable distributions (Bazzite, Fedora Silverblue)
- Shader roundtripping through SPIRV-Cross and glslang
- Pre-patched shader cache support

## Installation

### Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/HansKristian-Work/pyroveil/main/install-pyroveil.sh | bash
```

### Build from Source

Prerequisites: git, cmake, ninja, GCC or Clang

```bash
git clone https://github.com/HansKristian-Work/pyroveil.git
cd pyroveil
git submodule update --init --recursive
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/.local
ninja -C build install
```

For Steam Flatpak:
```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$HOME/.var/app/com.valvesoftware.Steam/.local
```

## Usage

### Automatic Detection

For supported games, just enable the layer in Steam launch options:

```
PYROVEIL=1 %command%
```

PyroVeil will detect your game via Steam AppID and load the correct configuration from the database.

### Manual Configuration Mode

If you need to specify a custom config:

```bash

Override auto-detection with a custom config:

```bash
PYROVEIL=1 PYROVEIL_CONFIG=/path/to/pyroveil.json %command%
```

### Verify Installation

Check Steam logs to confirm PyroVeil is active

You should see output like:
```
pyroveil: [AutoDetect] Starting auto-detection...
pyroveil: [AutoDetect] Detected Steam AppID: 2778720
pyroveil: [AutoDetect] Found config for AppID 2778720: Assassin's Creed Shadows
pyroveil: Auto-detected config: .../ac-shadows-nvidia-570-stable/pyroveil.json
```

### Utilities

**List supported games:**
```bash
pyroveil-auto-detect list
```
List supported games:
```bash
pyroveil-auto-detect list
```

Check configuration for a game:
```bash
pyroveil-auto-detect check <steam_appid>
```

Update game database:
## Supported Games

| Game | Steam AppID | Configuration |
|------|-------------|---------------|
| Assassin's Creed Shadows | 2778720 | ac-shadows-nvidia-570-stable |
| Final Fantasy VII Rebirth | 2909400 | ffvii-rebirth-nvidia |
| Monster Hunter Wilds Benchmark | 3163110 | monster-hunter-wilds-benchmark-nv |
| Roadcraft | - | roadcraft-nvidia-570-stable |
| Surviving Mars: Relaunched | - | surviving-mars-relaunched-nv-580-stable |

Run `pyroveil-auto-detect list` for the complete list.

## Testing

Run the validation suite before deploying:

```bash
# Run all validation checks (recommended before deployment)
./scripts/run-full-validation.sh

# Test specific components
./scripts/test-modules.sh       # Test individual modules
./scripts/test-logging.sh       # Verify logging infrastructure

./scripts/run-full-validation.sh    # Full suite
./scripts/test-modules.sh           # Module tests
./scripts/test-logging.sh           # Logging checks
./scripts/ci-validate.sh quick      # Fast CI check
```

Test categories include shell script validation, JSON config validation, build system checks, static analysis, module testing, logging verification, and documentation checks.

See [scripts/README-TESTING.md](scripts/README-TESTING.md) for details.
```json
{
    "version": 2,
    "type": "pyroveil",
    "matches": [
        {
            "opStringSearch": "shader_hash",
            "action": { "glsl-roundtrip": true }
        }
    ],
    "disabledExtensions": ["VK_NV_raw_access_chains"]
}
```

### Environment Variables

- `PYROVEIL=1` - Enable PyroVeil layer (required)
- `PYROVEIL_CONFIG=/path/to/config.json` - Override auto-detected config
- `PYROVEIL_CONFIG_BASE=/path/to/hacks` - Custom config directory
- `PYROVEIL_DATABASE=/path/to/database.json` - Custom game database
- `PYROVEIL_VERBOSE=1` - Enable verbose logging

## Architecture

```
Game Launch → Steam/Proton → Vulkan Loader → PyroVeil Layer
                                                    ↓
                                            Auto-Detection
                                            (Steam AppID)
                                                    ↓
                                            Load Config
                                            (database.json)
                                                    ↓
                                            Intercept Shaders
                                            (vkCreateShaderModule)
                                                    ↓
                                            Apply Fixes
                                            (SPIRV-Cross/Cache)
                                                    ↓
                                            Return Patched Shader
```

### How Detection Works

1. **Priority 1:** Check `PYROVEIL_CONFIG` environment variable
2. **Priority 2:** Detect Steam AppID from environment
3. **Priority 3:** Match process name from `/proc/self/comm`
4. **Priority 4:** Match executable path from `/proc/self/exe`
5. **Fallback:** Game runs without patches (logs warning)

## Installation Locations

After installation, PyroVeil files are located at:

```
~/.local/
├── bin/
│   ├── pyroveil-auto-detect      # Auto-detection utility
│   └── pyroveil-update-database  # Database updater
├── lib/
│   └── libVkLayer_pyroveil_64.so # Vulkan layer library
└── share/
    ├── vulkan/implicit_layer.d/
    │   └── VkLayer_pyroveil_64.json  # Layer manifest
    └── pyroveil/
        ├── database.json         # Game database
        └── hacks/                # Game configurations
            ├── ac-shadows-nvidia-570-stable/
            ├── ffvii-rebirth-nvidia/
            └── ...
```

## Troubleshooting

### PyroVeil not activating

1. Check `VK_LAYER_PATH` is set:
   ```bash
   echo $VK_LAYER_PATH
   `Detection Priority

1. Check `PYROVEIL_CONFIG` environment variable
2. Detect Steam AppID from environment
3. Match process name from `/proc/self/comm`
4. Match executable path from `/proc/self/exe`
5. Fallback: runn/implicit_layer.d/VkLayer_pyroveil_64.json
   ```

3. Check Steam logs:
   ```bash
   grep -i "pyroveil\|vulkan" ~/.steam/steam/logs/stderr.txt
   ```

### Game not auto-detected

1. Update database:
   ```bash
   pyroveil-update-database update
   ```

2. Check if game is supported:
   ```bash
   pyroveil-auto-detect list | grep "Your Game Name"
   ```

3. Manually specify config:
   ```bash
   PYROVEIL=1 PYROVEIL_CONFIG=~/.local/share/pyroveil/hacks/game/pyroveil.json %command%
   ```

### Build errors

Ensure all dependencies are installed:

- **Arch Linux:** `pacman -S git cmake ninja gcc`
- **Fedora:** `dnf install git cmake ninja-build gcc-c++`
- **Ubuntu/Debian:** `apt install git cmake ninja-build g++`

## Bottles (Flatpak) Setup

Some manual workarounds will be required to make this work with a Bottles setup.

Assuming you have gone through the [checkout and build](#checkout-and-build) section, you will now have two files in the `CMAKE_INSTALL_PREFIX` directory:
* `$CMAKE_INSTALL_PREFIX/lib/libVkLayer_pyroveil_64.so`
* `$CMAKE_INSTALL_PREFIX/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json`

By default Bottles will search several locations for Vulkan layer manifests, one of them is:
* `$HOME/.var/app/com.usebottles.bottles/config/vulkan/implicit_layer.d`

Copy over `VkLayer_pyroveil_64.json` into the location above. Open it and edit **ONLY** the `layer.library_path` field in the json like so (or any other path you like, as long as Bottles can access it):
```json
    "layer" : {
        "library_path": "/home/YOUR_USER/.var/app/com.usebottles.bottles/config/vulkan/lib/libVkLayer_pyroveil_64.so"
    }
```

For the final step it's suggested to copy the relevant hack to the `drive_c` folder of your game.

Finally, in the Bottles app, set the Launch options by clicking on the three dots next to your Program/Game, and clicking "Change Launch Options". Next add one of the hack locations:

`PYROVEIL=1 PYROVEIL_CONFIG=/home/YOUR_USER/.var/app/com.usebottles.bottles/data/bottles/bottles/YOUR_BOTTLE/drive_c/pyroveil.json %command%`

**NOTE:** If you are running an older version of a game, you might want to check the git history for that particular game's hack, and try an older version of the hack file.

## Development

### Building with Tests

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug \
    -DPYROVEIL_BUILD_TESTS=ON
ninja -C build
ctest --test-dir build --output-on-failure
```

### Adding New Game Support

1. Create configuration file in `hacks/your-game/pyroveil.json`
2. Add entry to `database.json`:
   ```json
   "steam_appid": {
       "name": "Game Name",
       "config": "your-game/pyroveil.json",
       "steam_appid": "steam_appid",
       "process_names": ["game.exe"],
       "required": true,
       "severity": "critical"
   }
   ```
3. Test with: `SteamAppId=steam_appid pyroveil-auto-detect`

### Code Style

- C++14 standard
- Follow existing patterns for consistency
- Document all public interfaces
- Include unit tests for new functionality

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

For bug reports or feature requests, please use [GitHub Issues](https://github.com/HansKristian-Work/pyroveil/issues).

## License

PyroVeil is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Credits

- **Original Author:** Hans-Kristian Arntzen (HansKristian-Work)
- **Contributors:** See GitHub contributors list
- **Dependencies:** SPIRV-Cross, glslang, RapidJSON, Vulkan Headers

## Links

- **GitHub:** https://github.com/HansKristian-Work/pyroveil
- **Issues:** https://github.com/HansKristian-Work/pyroveil/issues
- **ProtonDB:** https://www.protondb.com
