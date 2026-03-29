# PyroVeil Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0-rc1] - 2026-03-29

### Added
- **Comprehensive internationalization**: Complete English translation of all user-facing messages and documentation
- **Enhanced game database**: Expanded from 5 to 53+ games with detailed metadata and version tracking
- **Flatpak Steam support**: Full integration for Flatpak Steam including PRESSURE_VESSEL_APP_ID detection
- **Immutable distribution support**: Automatic detection and configuration for Bazzite, Silverblue, and Kinoite
- **new `pyroveil-auto-detect.sh`**: Automatic game detection using multiple detection strategies
  - Environment variable priority detection (SteamAppId, STEAM_COMPAT_APP_ID, PRESSURE_VESSEL_APP_ID)
  - Process name and executable matching
  - Fallback to Steam AppID scanning
  - List and check utilities for database inspection
- **New `pyroveil-update-database.sh`**: Automatic database synchronization from repository
  - Network resilience with retry logic
  - Automatic backup and rollback on failure
  - Version-aware updates
  - Game list filtering by priority
- **Distro-specific installation guides**: Detailed instructions for:
  - Fedora (dnf-based)
  - Bazzite/Silverblue/Kinoite (immutable with layering)
  - Arch/EndeavourOS/Manjaro (pacman-based)
  - Debian/Ubuntu/Pop!_OS (apt-based)
  - openSUSE (zypper-based)
- **Detailed code documentation**: Comprehensive inline comments for all major C++ functions
  - ScratchAllocator documentation
  - Match rule system documentation
  - Device shader interception logic documentation
  - pNext chain copying and SPIR-V utilities documentation
- **New build utilities**:
  - `scripts/comprehensive-test.sh`: Full test suite with 10 test categories
  - `scripts/steam-game-scanner.sh`: Game library scanning and database generation

### Changed
- **Complete code cleanup**: Removed all Russian text from source code and documentation
- **Improved readability**: Added detailed comments to all header files (path_utils.hpp, string_helpers.hpp, dispatch_helper.hpp)
- **Enhanced README.md**: 
  - Added featured games list
  - Added Flatpak Steam configuration instructions
  - Added distro-specific auto-detection examples
  - Expanded troubleshooting section with environment variable documentation
  - Added maintenance and contribution guidelines
- **Refactored uninstall script**: Clean, coherent implementation with proper error handling
- **Updated database structure**: Added priority levels and multi-string process matching
- **Improved error messages**: Clear, actionable error reporting in all scripts

### Fixed
- **Broken profile append line in install script**: Fixed `echo " >> "$profile"` (invalid) to proper implementation
- **Shader module hash documentation**: Added clear explanation of Fossilize hash compatibility
- **VkBaseInStructure memory safety**: Documented pNext chain handling to prevent buffer overflows
- **Environment variable detection order**: Documented priority order for AppID detection

### Technical Improvements
- **Memory management**: ScratchAllocator explained for efficient shader processing
- **SPIR-V parsing**: Documented string extraction and execution model detection
- **Vulkan layer architecture**: Clarified Instance-Device relationship and dispatch table usage
- **Configuration file format**: Added JSON schema documentation for pyroveil.json
- **Cache system**: Documented roundtrip shader caching mechanism

### Documentation
- Added LICENSE copyright notices to all modified files
- Added extensive function documentation with examples
- Created comprehensive troubleshooting guides
- Added development setup documentation
- Created release process documentation

### Removed
- Russian language text from all files (installation scripts, code comments, documentation)
- Corrupted/duplicate content from uninstall script
- Unused build artifacts and CMake cache

## [1.0.0] - Previous Release

### Features (from previous version)
- Vulkan implicit layer for shader interception
- GLSL roundtrip compilation via SPIRV-Cross
- Configuration-based shader matching
- Hash-based, range-based, and string-based matching
- Shader caching system
- Extension disabling support

## Migration Guide from 1.0.0 to 2.0.0-rc1

### For Users
1. Uninstall previous version: `scripts/uninstall_pyroveil.sh`
2. Clean build artifacts: `rm -rf build/`
3. Run new installer: `bash install-pyroveil.sh`
4. Initialize database: `pyroveil-update-database.sh update`
5. Test detection: `pyroveil-auto-detect.sh check 2778720` (Assassin's Creed Shadows)

### For Configuration Files
- Old pyroveil.json format is still supported
- New features available through updated Database schema
- Recommend adding priority levels to game entries

### For Development
- All code comments now in English
- Enhanced documentation in header files
- Comprehensive function documentation with examples
- Follow the new build and test procedures documented in README-RELEASE.md

## Known Issues
- None reported for 2.0.0-rc1

## Future Roadmap
- [ ] Automated CI/CD pipeline for releases
- [ ] Per-game web configuration interface
- [ ] Shader statistics and performance metrics
- [ ] GUI configuration tool
- [ ] ProtonTricks integration
- [ ] AMD/Intel hardware support (prototype phase)

## Support
For bug reports and feature requests, please visit:
https://github.com/HansKristian-Work/pyroveil/issues

## License
See LICENSE file for copyright and permission details
