/**
 * @file pyroveil_autodetect.hpp
 * @brief Automatic game detection and configuration loading
 * 
 * This header defines the public API for PyroVeil's automatic game detection
 * system. The auto-detection module identifies the currently running game
 * and locates its corresponding shader patch configuration file.
 * 
 * @author PyroVeil Contributors
 * @date 2025
 * 
 * Detection Methods:
 * - Steam AppID (most reliable for Steam games)
 * - Process name matching
 * - Executable path analysis
 * - User manual override via environment variables
 * 
 * @see pyroveil_autodetect.cpp for implementation details
 */

#ifndef PYROVEIL_AUTODETECT_HPP
#define PYROVEIL_AUTODETECT_HPP

#include <string>
#include <map>
#include <vector>
#include <algorithm>

namespace PyroVeil {
namespace AutoDetect {

/**
 * @brief Automatically detect and load configuration for the current game
 * 
 * This is the main entry point for PyroVeil's auto-detection system. It identifies
 * the running game using multiple detection methods and locates the appropriate
 * configuration file containing shader patch rules.
 * 
 * Detection Priority (highest to lowest):
 * 1. **PYROVEIL_CONFIG** environment variable (user manual override)
 * 2. **Steam AppID** detection (from SteamAppId, STEAM_COMPAT_APP_ID, etc.)
 * 3. **Process name** matching (from /proc/self/comm or hardcoded mappings)
 * 4. **Executable path** analysis (from /proc/self/exe)
 * 
 * Configuration Search Paths:
 * - User installation: `$HOME/.local/share/pyroveil/hacks/`
 * - System-wide: `/usr/share/pyroveil/hacks/`
 * - Custom: `$PYROVEIL_CONFIG_BASE/`
 * 
 * @return Full absolute path to the game's configuration file (pyroveil.json),
 *         or empty string if no configuration could be found
 * 
 * @note On failure, detailed debug information is logged to stderr to assist
 *       users in troubleshooting detection issues
 * 
 * @warning This function performs file I/O and environment variable lookups.
 *          It should be called only once during Vulkan layer initialization.
 * 
 * @par Example Usage:
 * @code
 * std::string configPath = PyroVeil::AutoDetect::autoDetectConfigPath();
 * if (configPath.empty()) {
 *     fprintf(stderr, "No configuration found, running without shader patches\n");
 * } else {
 *     loadConfiguration(configPath);
 * }
 * @endcode
 * 
 * @par Environment Variables:
 * - **PYROVEIL_CONFIG**: Direct path to configuration file (highest priority)
 * - **PYROVEIL_CONFIG_BASE**: Custom base directory for configuration files
 * - **PYROVEIL_DATABASE**: Custom path to database.json
 * - **SteamAppId**: Steam Application ID (set by Steam client)
 * - **STEAM_COMPAT_APP_ID**: Proton compatibility AppID
 * - **SteamGameId**: Alternative Steam ID variable
 * - **PRESSURE_VESSEL_APP_ID**: Pressure Vessel (Flatpak) AppID
 * 
 * @see getSteamAppId() for Steam AppID detection logic
 * @see findConfigByAppId() for AppID-based configuration lookup
 * @see findConfigByProcessName() for process name matching
 */
std::string autoDetectConfigPath();

} // namespace AutoDetect
} // namespace PyroVeil

#endif // PYROVEIL_AUTODETECT_HPP
