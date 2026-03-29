/*
 * pyroveil_autodetect.cpp - Automatic game detection module for PyroVeil
 * 
 * Copyright (c) 2025 PyroVeil Contributors
 * SPDX-License-Identifier: MIT
 * 
 * This module provides automatic game detection capabilities for PyroVeil.
 * It eliminates the need for users to manually specify configuration files
 * by automatically detecting the running game through multiple methods:
 * 
 * Detection Priority (highest to lowest):
 * 1. PYROVEIL_CONFIG environment variable (user override)
 * 2. Steam AppID (from SteamAppId, STEAM_COMPAT_APP_ID environment variables)
 * 3. Process name (from /proc/self/comm)
 * 4. Executable path (from /proc/self/exe)
 * 
 * The module uses a JSON database (database.json) that maps game identifiers
 * to their corresponding PyroVeil configuration files. If the database is not
 * found, it falls back to a hardcoded list of known games.
 * 
 * Integration:
 * - Add this file to layer/CMakeLists.txt
 * - Call autoDetectConfigPath() in Instance::init()
 * - Ensure database.json is installed to ~/.local/share/pyroveil/
 */

#include "pyroveil_autodetect.hpp"
#include "path_utils.hpp"

#include <stdlib.h>     // getenv()
#include <unistd.h>     // readlink(), access(), getppid()
#include <fstream>      // std::ifstream
#include <sstream>      // std::stringstream
#include <algorithm>    // std::transform()
#include <errno.h>      // errno
#include <string.h>     // strerror()
#include <limits.h>     // PATH_MAX

namespace PyroVeil {
namespace AutoDetect {

/**
 * @brief Game information structure
 * 
 * Contains all metadata about a supported game including:
 * - Display name
 * - Configuration file path
 * - Steam AppID
 * - Alternative process names for detection
 * - Criticality level
 */
struct GameInfo {
    std::string name;                        ///< Human-readable game name
    std::string config;                      ///< Relative path to pyroveil.json config
    std::string steamAppId;                  ///< Steam Application ID (if applicable)
    std::vector<std::string> processNames;   ///< List of possible process names
    bool required;                           ///< Whether fixes are required vs optional
    std::string severity;                    ///< Criticality: critical|high|medium|low
    std::string description;                 ///< Brief description of fixes applied
};

/**
 * @brief Simple JSON parser for database.json
 * 
 * This is a lightweight parser specifically designed for our database format.
 * For production use, consider integrating RapidJSON which is already available
 * in the project dependencies.
 * 
 * @note This is a simplified implementation. In production, use RapidJSON
 *       which is already available in third_party/rapidjson/
 */
class SimpleJsonParser {
public:
    /**
     * @brief Parse database.json file
     * 
     * @param jsonPath Absolute path to database.json
     * @return Map of Steam AppID to GameInfo structures
     * 
     * @note Returns empty map on parse failure (non-critical, fallback exists)
     */
    static std::map<std::string, GameInfo> parseDatabase(const std::string& jsonPath) {
        std::map<std::string, GameInfo> games;
        
        // Attempt to open the database file
        std::ifstream file(jsonPath);
        if (!file.is_open()) {
            fprintf(stderr, "pyroveil: [AutoDetect] WARNING: Cannot open database: %s\n", 
                    jsonPath.c_str());
            return games;
        }
        
        // Read entire file into memory
        std::stringstream buffer;
        buffer << file.rdbuf();
        std::string content = buffer.str();
        
        // TODO: Implement full JSON parsing using RapidJSON
        // For now, this serves as a placeholder. The actual implementation
        // should use the RapidJSON library available in third_party/rapidjson/
        // 
        // Example integration:
        //   #include "rapidjson/document.h"
        //   rapidjson::Document doc;
        //   doc.Parse(content.c_str());
        //   if (!doc.HasParseError() && doc.HasMember("games")) {
        //       // Parse games object...
        //   }
        
        fprintf(stderr, "pyroveil: [AutoDetect] INFO: JSON parsing not yet implemented, using fallback\n");
        
        return games;
    }
};

/**
 * @brief Retrieve Steam AppID from environment variables
 * 
 * Steam/Proton sets various environment variables that contain the AppID.
 * We check them in priority order:
 * 1. SteamAppId - Primary variable set by Steam
 * 2. STEAM_COMPAT_APP_ID - Set by Proton for compatibility layer
 * 3. SteamGameId - Legacy variable (some older games)
 * 4. Parent process environment - Fallback check
 * 
 * @return Steam AppID as string, or empty string if not found
 */
static std::string getSteamAppId() {
    // Priority 1: SteamAppId (most common)
    const char* appId = getenv("SteamAppId");
    if (appId && strlen(appId) > 0) {
        return std::string(appId);
    }
    
    // Priority 2: STEAM_COMPAT_APP_ID (Proton compatibility)
    appId = getenv("STEAM_COMPAT_APP_ID");
    if (appId && strlen(appId) > 0) {
        return std::string(appId);
    }
    
    // Priority 3: SteamGameId (legacy)
    
    appId = getenv("SteamGameId");
    if (appId && strlen(appId) > 0) {
        return std::string(appId);
    }
    
    // Priority 4: Parent process environment (fallback)
    // Some launchers don't propagate environment variables to the game process,
    // so we check the parent process's environment as a last resort
    pid_t ppid = getppid();
    char envPath[256];
    snprintf(envPath, sizeof(envPath), "/proc/%d/environ", ppid);
    
    std::ifstream envFile(envPath);
    if (envFile.is_open()) {
        std::string line;
        // /proc/*/environ uses null bytes as separators
        while (std::getline(envFile, line, '\0')) {
            if (line.find("SteamAppId=") == 0) {
                return line.substr(11); // Skip "SteamAppId=" prefix
            }
        }
    }
    
    return ""; // No AppID found
}

/**
 * @brief Retrieve current process name
 * 
 * Reads the process name from /proc/self/comm which contains the
 * executable name (truncated to 15 characters by the kernel).
 * 
 * @return Process name, or "unknown" if unable to read
 */
static std::string getProcessName() {
    std::ifstream commFile("/proc/self/comm");
    if (commFile.is_open()) {
        std::string name;
        std::getline(commFile, name);
        return name;
    }
    
    // Fallback: Unable to read process name
    fprintf(stderr, "pyroveil: [AutoDetect] WARNING: Cannot read /proc/self/comm\n");
    return "unknown";
}

/**
 * @brief Retrieve full path to current executable
 * 
 * Uses /proc/self/exe symlink to get the absolute path to the
 * currently running executable. This is more reliable than process
 * name for detection since it includes the full path.
 * 
 * @return Absolute path to executable, or empty string on failure
 */
static std::string getExecutablePath() {
    char path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", path, sizeof(path) - 1);
    
    if (len != -1) {
        path[len] = '\0'; // Null-terminate the string
        return std::string(path);
    }
    
    // Log error for debugging
    fprintf(stderr, "pyroveil: [AutoDetect] WARNING: Cannot readlink /proc/self/exe: %s\n",
            strerror(errno));
    return "";
}

/**
 * @brief Determine base directory for configuration files
 * 
 * Searches for the PyroVeil configuration directory in the following order:
 * 1. PYROVEIL_CONFIG_BASE environment variable (user override)
 * 2. $HOME/.local/share/pyroveil/hacks (user installation)
 * 3. /usr/share/pyroveil/hacks (system-wide installation)
 * 
 * @return Absolute path to configuration base directory, or empty on failure
 * 
 * @note This function checks for read access (R_OK) to ensure the directory
 *       is actually usable before returning it
 */
static std::string getConfigBasePath() {
    // Priority 1: User-specified override
    const char* configBase = getenv("PYROVEIL_CONFIG_BASE");
    if (configBase && strlen(configBase) > 0) {
        // Validate that the path exists and is readable
        if (access(configBase, R_OK) == 0) {
            return std::string(configBase);
        }
        fprintf(stderr, "pyroveil: [AutoDetect] WARNING: PYROVEIL_CONFIG_BASE set but not accessible: %s\n",
                configBase);
    }
    
    // Priority 2: User installation directory
    const char* home = getenv("HOME");
    if (home && strlen(home) > 0) {
        std::string userPath = std::string(home) + "/.local/share/pyroveil/hacks";
        if (access(userPath.c_str(), R_OK) == 0) {
            return userPath;
        }
    }
    
    // Priority 3: System-wide installation directory
    const char* systemPath = "/usr/share/pyroveil/hacks";
    if (access(systemPath, R_OK) == 0) {
        return systemPath;
    }
    
    // No valid configuration directory found
    return "";
}

/**
 * @brief Locate database.json file
 * 
 * Searches for the game database in the following locations:
 * 1. PYROVEIL_DATABASE environment variable (user override)
 * 2. $HOME/.local/share/pyroveil/database.json (user installation)
 * 3. /usr/share/pyroveil/database.json (system-wide installation)
 * 
 * @return Absolute path to database.json, or empty string if not found
 */
static std::string getDatabasePath() {
    // Priority 1: User-specified database location
    const char* dbPath = getenv("PYROVEIL_DATABASE");
    if (dbPath && strlen(dbPath) > 0) {
        if (access(dbPath, R_OK) == 0) {
            return std::string(dbPath);
        }
        fprintf(stderr, "pyroveil: [AutoDetect] WARNING: PYROVEIL_DATABASE set but not accessible: %s\n",
                dbPath);
    }
    
    // Priority 2: User installation
    const char* home = getenv("HOME");
    if (home && strlen(home) > 0) {
        std::string userPath = std::string(home) + "/.local/share/pyroveil/database.json";
        if (access(userPath.c_str(), R_OK) == 0) {
            return userPath;
        }
    }
    
    // Priority 3: System-wide installation
    const char* systemPath = "/usr/share/pyroveil/database.json";
    if (access(systemPath, R_OK) == 0) {
        return systemPath;
    }
    
    return ""; // Database not found
}

/**
 * @brief Hardcoded fallback game configurations
 * 
 * This fallback database is used when database.json cannot be found or parsed.
 * It contains essential game-to-configuration mappings to ensure basic
 * functionality even without the database file.
 * 
 * @return Map of Steam AppID to configuration file paths
 * 
 * @note Keep this synchronized with database.json for critical games
 */
static std::map<std::string, std::string> getHardcodedGameConfigs() {
    std::map<std::string, std::string> configs;
    
    // Assassin's Creed Shadows - Critical fix for mesh shader crashes
    configs["2778720"] = "ac-shadows-nvidia-570-stable/pyroveil.json";
    
    // Final Fantasy VII Rebirth - Shader compilation fixes
    configs["2909400"] = "ffvii-rebirth-nvidia/pyroveil.json";
    
    // Monster Hunter Wilds Benchmark - Performance optimizations
    configs["3163110"] = "monster-hunter-wilds-benchmark-nv/pyroveil.json";
    
    // Note: This is a minimal fallback set. The full list is in database.json
    fprintf(stderr, "pyroveil: [AutoDetect] INFO: Using hardcoded fallback database\n");
    
    return configs;
}

/**
 * @brief Find configuration file by Steam AppID
 * 
 * Attempts to locate a configuration file for the given Steam AppID by:
 * 1. Searching database.json (if available)
 * 2. Falling back to hardcoded mappings
 * 3. Verifying the configuration file exists and is readable
 * 
 * @param appId Steam Application ID (e.g., "2778720")
 * @param basePath Base directory containing configuration files
 * @return Full path to configuration file, or empty string if not found
 */
static std::string findConfigByAppId(const std::string& appId, const std::string& basePath) {
    if (appId.empty() || basePath.empty()) {
        return "";
    }
    
    // Attempt 1: Load from database.json
    std::string dbPath = getDatabasePath();
    if (!dbPath.empty()) {
        auto games = SimpleJsonParser::parseDatabase(dbPath);
        auto it = games.find(appId);
        if (it != games.end()) {
            std::string fullPath = basePath + "/" + it->second.config;
            if (access(fullPath.c_str(), R_OK) == 0) {
                fprintf(stderr, "pyroveil: [AutoDetect] Found config for AppID %s: %s\n",
                        appId.c_str(), it->second.name.c_str());
                return fullPath;
            }
            // Config listed in database but file doesn't exist
            fprintf(stderr, "pyroveil: [AutoDetect] WARNING: Config for AppID %s not accessible: %s\n",
                    appId.c_str(), fullPath.c_str());
        }
    }
    
    // Attempt 2: Fallback to hardcoded mappings
    auto hardcoded = getHardcodedGameConfigs();
    auto it = hardcoded.find(appId);
    if (it != hardcoded.end()) {
        std::string fullPath = basePath + "/" + it->second;
        if (access(fullPath.c_str(), R_OK) == 0) {
            fprintf(stderr, "pyroveil: [AutoDetect] Found config for AppID %s (hardcoded fallback)\n",
                    appId.c_str());
            return fullPath;
        }
    }
    
    return ""; // No configuration found for this AppID
}

/**
 * @brief Find configuration file by process name
 * 
 * Searches for a configuration file matching the current process name.
 * Uses both exact matching and fuzzy substring matching (case-insensitive).
 * 
 * This function maintains a hardcoded process name to configuration mapping
 * for games that don't reliably provide Steam AppIDs.
 * 
 * @param processName Name of the process (from /proc/self/comm or argv[0])
 * @param basePath Base directory containing configuration files
 * @return Full path to configuration file, or empty string if not found
 * 
 * @note Priority order: exact match → case-insensitive partial match
 */
static std::string findConfigByProcessName(const std::string& processName, const std::string& basePath) {
    if (processName.empty() || processName == "unknown" || basePath.empty()) {
        return "";
    }
    
    // Hardcoded process name to configuration file mappings
    // This is a fallback for games where Steam AppID detection fails
    std::map<std::string, std::string> processToConfig;
    
    // Assassin's Creed Shadows variations
    processToConfig["ACshadows"] = "ac-shadows-nvidia-570-stable/pyroveil.json";
    processToConfig["acshadows"] = "ac-shadows-nvidia-570-stable/pyroveil.json";
    
    // Final Fantasy VII Rebirth variations
    processToConfig["FFVIIR"] = "ffvii-rebirth-nvidia/pyroveil.json";
    processToConfig["ff7r.exe"] = "ffvii-rebirth-nvidia/pyroveil.json";
    
    // Roadcraft variations
    processToConfig["Roadcraft"] = "roadcraft-nvidia-570-stable/pyroveil.json";
    processToConfig["roadcraft"] = "roadcraft-nvidia-570-stable/pyroveil.json";
    
    // Attempt 1: Exact match (case-sensitive)
    auto it = processToConfig.find(processName);
    if (it != processToConfig.end()) {
        std::string fullPath = basePath + "/" + it->second;
        if (access(fullPath.c_str(), R_OK) == 0) {
            fprintf(stderr, "pyroveil: [AutoDetect] Found config for process '%s' (exact match)\n",
                    processName.c_str());
            return fullPath;
        }
    }
    
    // Attempt 2: Fuzzy match (case-insensitive substring matching)
    // Convert process name to lowercase for comparison
    std::string lowerProcess = processName;
    std::transform(lowerProcess.begin(), lowerProcess.end(), lowerProcess.begin(), ::tolower);
    
    for (const auto& pair : processToConfig) {
        std::string lowerKey = pair.first;
        std::transform(lowerKey.begin(), lowerKey.end(), lowerKey.begin(), ::tolower);
        
        // Check bidirectional substring matching:
        // - Does process name contain the key?
        // - Does the key contain the process name?
        if (lowerProcess.find(lowerKey) != std::string::npos ||
            lowerKey.find(lowerProcess) != std::string::npos) {
            std::string fullPath = basePath + "/" + pair.second;
            if (access(fullPath.c_str(), R_OK) == 0) {
                fprintf(stderr, "pyroveil: [AutoDetect] Found config for process '%s' (fuzzy match: '%s')\n",
                        processName.c_str(), pair.first.c_str());
                return fullPath;
            }
        }
    }
    
    return ""; // No matching configuration found
}

/**
 * @brief Automatically detect and locate the configuration file for the current game
 * 
 * This is the main entry point for PyroVeil's auto-detection system. It attempts
 * to identify the running game and locate its corresponding configuration file
 * using multiple detection methods in priority order:
 * 
 * Detection Priority (highest to lowest):
 * 1. PYROVEIL_CONFIG environment variable (user manual override)
 * 2. Steam AppID (most reliable for Steam games)
 * 3. Process name matching (fallback for non-Steam or ambiguous cases)
 * 4. Executable name extraction (last resort)
 * 
 * @return Full path to the game's configuration file, or empty string if not found
 * 
 * @note On failure, the function logs comprehensive debug information to stderr
 *       to help users troubleshoot detection issues
 * 
 * @see getSteamAppId() for Steam AppID detection
 * @see getProcessName() for process name extraction
 * @see getExecutablePath() for executable path retrieval
 */
std::string autoDetectConfigPath() {
    fprintf(stderr, "pyroveil: [AutoDetect] ==========================================\n");
    fprintf(stderr, "pyroveil: [AutoDetect] Starting automatic game detection...\n");
    fprintf(stderr, "pyroveil: [AutoDetect] ==========================================\n");
    
    // ========================================
    // Step 1: Check for user manual override
    // ========================================
    const char* userConfig = getenv("PYROVEIL_CONFIG");
    if (userConfig && access(userConfig, R_OK) == 0) {
        fprintf(stderr, "pyroveil: [AutoDetect] SUCCESS: Using user-specified config via PYROVEIL_CONFIG\n");
        fprintf(stderr, "pyroveil: [AutoDetect]   Config path: %s\n", userConfig);
        return std::string(userConfig);
    }
    
    // ========================================
    // Step 2: Locate configuration base path
    // ========================================
    std::string basePath = getConfigBasePath();
    if (basePath.empty()) {
        fprintf(stderr, "pyroveil: [AutoDetect] ERROR: Configuration base directory not found!\n");
        fprintf(stderr, "pyroveil: [AutoDetect] Searched locations:\n");
        fprintf(stderr, "pyroveil: [AutoDetect]   - $PYROVEIL_CONFIG_BASE (environment variable)\n");
        fprintf(stderr, "pyroveil: [AutoDetect]   - $HOME/.local/share/pyroveil/hacks (user installation)\n");
        fprintf(stderr, "pyroveil: [AutoDetect]   - /usr/share/pyroveil/hacks (system-wide installation)\n");
        fprintf(stderr, "pyroveil: [AutoDetect] \n");
        fprintf(stderr, "pyroveil: [AutoDetect] Please ensure PyroVeil is properly installed.\n");
        return "";
    }
    
    fprintf(stderr, "pyroveil: [AutoDetect] Configuration base: %s\n", basePath.c_str());
    
    // ========================================
    // Step 3: Attempt Steam AppID detection
    // ========================================
    std::string appId = getSteamAppId();
    if (!appId.empty()) {
        fprintf(stderr, "pyroveil: [AutoDetect] Detected Steam AppID: %s\n", appId.c_str());
        
        std::string config = findConfigByAppId(appId, basePath);
        if (!config.empty()) {
            fprintf(stderr, "pyroveil: [AutoDetect] SUCCESS: Configuration found via Steam AppID\n");
            return config;
        }
        
        fprintf(stderr, "pyroveil: [AutoDetect] No configuration found for AppID %s in database\n", appId.c_str());
    } else {
        fprintf(stderr, "pyroveil: [AutoDetect] Steam AppID not detected (not running via Steam or env vars not set)\n");
    }
    
    // ========================================
    // Step 4: Attempt process name matching
    // ========================================
    std::string processName = getProcessName();
    fprintf(stderr, "pyroveil: [AutoDetect] Process name: %s\n", processName.c_str());
    
    std::string config = findConfigByProcessName(processName, basePath);
    if (!config.empty()) {
        fprintf(stderr, "pyroveil: [AutoDetect] SUCCESS: Configuration found via process name\n");
        return config;
    }
    
    // ========================================
    // Step 5: Attempt executable name matching
    // ========================================
    std::string exePath = getExecutablePath();
    if (!exePath.empty()) {
        fprintf(stderr, "pyroveil: [AutoDetect] Executable path: %s\n", exePath.c_str());
        
        // Extract just the filename from the full path
        size_t lastSlash = exePath.find_last_of('/');
        if (lastSlash != std::string::npos) {
            std::string exeName = exePath.substr(lastSlash + 1);
            
            // Strip .exe extension if present (for Wine/Proton games)
            size_t dotPos = exeName.find(".exe");
            if (dotPos != std::string::npos) {
                exeName = exeName.substr(0, dotPos);
            }
            
            fprintf(stderr, "pyroveil: [AutoDetect] Extracted executable name: %s\n", exeName.c_str());
            
            config = findConfigByProcessName(exeName, basePath);
            if (!config.empty()) {
                fprintf(stderr, "pyroveil: [AutoDetect] SUCCESS: Configuration found via executable name\n");
                return config;
            }
        }
    }
    
    // ========================================
    // Step 6: Detection failed - provide help
    // ========================================
    fprintf(stderr, "pyroveil: [AutoDetect] ==========================================\n");
    fprintf(stderr, "pyroveil: [AutoDetect] WARNING: No configuration found automatically\n");
    fprintf(stderr, "pyroveil: [AutoDetect] ==========================================\n");
    fprintf(stderr, "pyroveil: [AutoDetect] Game will run WITHOUT PyroVeil shader fixes.\n");
    fprintf(stderr, "pyroveil: [AutoDetect] \n");
    fprintf(stderr, "pyroveil: [AutoDetect] Detection Info:\n");
    fprintf(stderr, "pyroveil: [AutoDetect]   Steam AppID:    %s\n", 
            appId.empty() ? "not detected" : appId.c_str());
    fprintf(stderr, "pyroveil: [AutoDetect]   Process name:   %s\n", processName.c_str());
    fprintf(stderr, "pyroveil: [AutoDetect]   Executable:     %s\n", 
            exePath.empty() ? "not detected" : exePath.c_str());
    fprintf(stderr, "pyroveil: [AutoDetect] \n");
    fprintf(stderr, "pyroveil: [AutoDetect] Troubleshooting Steps:\n");
    fprintf(stderr, "pyroveil: [AutoDetect]   1. Check if your game is supported:\n");
    fprintf(stderr, "pyroveil: [AutoDetect]      $ pyroveil-auto-detect list\n");
    fprintf(stderr, "pyroveil: [AutoDetect] \n");
    fprintf(stderr, "pyroveil: [AutoDetect]   2. Update game database:\n");
    fprintf(stderr, "pyroveil: [AutoDetect]      $ pyroveil-update-database\n");
    fprintf(stderr, "pyroveil: [AutoDetect] \n");
    fprintf(stderr, "pyroveil: [AutoDetect]   3. Manually specify configuration file:\n");
    fprintf(stderr, "pyroveil: [AutoDetect]      $ export PYROVEIL_CONFIG=/path/to/config.json\n");
    fprintf(stderr, "pyroveil: [AutoDetect] \n");
    fprintf(stderr, "pyroveil: [AutoDetect]   4. Report on GitHub if game should be supported:\n");
    fprintf(stderr, "pyroveil: [AutoDetect]      https://github.com/user/pyroveil/issues\n");
    fprintf(stderr, "pyroveil: [AutoDetect] ==========================================\n");
    
    return ""; // No configuration found
}

} // namespace AutoDetect
} // namespace PyroVeil
