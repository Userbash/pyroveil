#!/usr/bin/env bash
# pyroveil-auto-detect.sh
# Automatic game detection and PyroVeil config selection.
# Can be called from the layer or used directly by users.

set -euo pipefail

DATABASE_PATH="${PYROVEIL_DATABASE:-$HOME/.local/share/pyroveil/database.json}"
CONFIG_BASE="${PYROVEIL_CONFIG_BASE:-$HOME/.local/share/pyroveil/hacks}"

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[pyroveil-detect]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[pyroveil-detect]${NC} $*" >&2; }
error() { echo -e "${RED}[pyroveil-detect]${NC} $*" >&2; }
success() { echo -e "${GREEN}[pyroveil-detect]${NC} $*" >&2; }

# Check required dependencies
check_deps() {
    if ! command -v jq &>/dev/null; then
        error "jq is not installed. Install it with: sudo pacman -S jq or sudo dnf install jq"
        return 1
    fi

    if [[ ! -f "$DATABASE_PATH" ]]; then
        error "Database not found: $DATABASE_PATH"
        error "Run: pyroveil-update-database"
        return 1
    fi

    return 0
}

# Get current Steam AppID from common environment sources
get_steam_appid() {
    # Environment variable priority order
    local appid="${SteamAppId:-}"
    [[ -z "$appid" ]] && appid="${STEAM_COMPAT_APP_ID:-}"
    [[ -z "$appid" ]] && appid="${SteamGameId:-}"

    # Fallback: attempt to read parent process environment
    if [[ -z "$appid" ]]; then
        local parent_pid
        parent_pid=$(ps -o ppid= -p $$ | tr -d ' ')
        if [[ -f "/proc/$parent_pid/environ" ]]; then
            appid=$(tr '\0' '\n' < "/proc/$parent_pid/environ" | grep '^SteamAppId=' | cut -d= -f2)
        fi
    fi

    echo "$appid"
}

# Get current process name
get_process_name() {
    cat /proc/self/comm 2>/dev/null || echo "unknown"
}

# Get absolute executable path
get_executable_path() {
    readlink -f /proc/self/exe 2>/dev/null || echo ""
}

# Find config by Steam AppID
find_config_by_appid() {
    local appid=$1
    [[ -z "$appid" ]] && return 1

    local config
    config=$(jq -r --arg appid "$appid" \
        '.games[$appid].config // empty' "$DATABASE_PATH")

    if [[ -n "$config" ]]; then
        local full_path="$CONFIG_BASE/$config"
        if [[ -f "$full_path" ]]; then
            echo "$full_path"
            return 0
        fi
    fi

    return 1
}

# Find config by process name
find_config_by_process_name() {
    local process_name=$1
    [[ -z "$process_name" ]] && return 1

    # Find games where process_names contain this process name
    local config
    config=$(jq -r --arg name "$process_name" \
        '.games[] | select(.process_names[]? | test($name; "i")) | .config' \
        "$DATABASE_PATH" | head -1)

    if [[ -n "$config" ]]; then
        local full_path="$CONFIG_BASE/$config"
        if [[ -f "$full_path" ]]; then
            echo "$full_path"
            return 0
        fi
    fi

    return 1
}

# Find config by executable path
find_config_by_exe_path() {
    local exe_path=$1
    [[ -z "$exe_path" ]] && return 1

    local exe_name
    exe_name=$(basename "$exe_path" .exe 2>/dev/null || basename "$exe_path")

    # Match using executable name against process_names
    local config
    config=$(jq -r --arg name "$exe_name" \
        '.games[] | select(.process_names[]? | test($name; "i")) | .config' \
        "$DATABASE_PATH" | head -1)

    if [[ -n "$config" ]]; then
        local full_path="$CONFIG_BASE/$config"
        if [[ -f "$full_path" ]]; then
            echo "$full_path"
            return 0
        fi
    fi

    return 1
}

# Print detailed game info by AppID
get_game_info() {
    local appid=$1

    jq -r --arg appid "$appid" \
        '.games[$appid] | "Game: \(.name)\nDescription: \(.description)\nRequired: \(.required)\nPriority: \(.severity)"' \
        "$DATABASE_PATH"
}

# Main auto-detection flow
auto_detect() {
    log "Starting PyroVeil config auto-detection..."

    check_deps || return 1

    # 1. Respect manual override from PYROVEIL_CONFIG
    if [[ -n "${PYROVEIL_CONFIG:-}" ]]; then
        if [[ -f "$PYROVEIL_CONFIG" ]]; then
            success "Using user-provided config: $PYROVEIL_CONFIG"
            echo "$PYROVEIL_CONFIG"
            return 0
        else
            warn "PYROVEIL_CONFIG is set, but file not found: $PYROVEIL_CONFIG"
        fi
    fi

    # 2. Detect by Steam AppID
    local appid
    appid=$(get_steam_appid)
    if [[ -n "$appid" ]]; then
        log "Detected Steam AppID: $appid"

        local config
        config=$(find_config_by_appid "$appid")
        if [[ -n "$config" ]]; then
            success "Found config by AppID: $config"
            get_game_info "$appid" >&2
            echo "$config"
            return 0
        else
            warn "No config found in database for AppID $appid"
        fi
    fi

    # 3. Detect by process name
    local process_name
    process_name=$(get_process_name)
    if [[ -n "$process_name" && "$process_name" != "unknown" ]]; then
        log "Process name: $process_name"

        local config
        config=$(find_config_by_process_name "$process_name")
        if [[ -n "$config" ]]; then
            success "Found config by process name: $config"
            echo "$config"
            return 0
        fi
    fi

    # 4. Detect by executable path
    local exe_path
    exe_path=$(get_executable_path)
    if [[ -n "$exe_path" ]]; then
        log "Executable path: $exe_path"

        local config
        config=$(find_config_by_exe_path "$exe_path")
        if [[ -n "$config" ]]; then
            success "Found config by executable path: $config"
            echo "$config"
            return 0
        fi
    fi

    # 5. No match found
    warn "PyroVeil configuration was not detected automatically"
    warn "The game will run without PyroVeil fixes"
    warn ""
    warn "Debug information:"
    warn "  Steam AppID: ${appid:-not detected}"
    warn "  Process: ${process_name:-not detected}"
    warn "  Executable: ${exe_path:-not detected}"
    warn ""
    warn "If your game should be supported by PyroVeil:"
    warn "  1. Update database: pyroveil-update-database"
    warn "  2. Check supported games list"
    warn "  3. Set config manually: export PYROVEIL_CONFIG=/path/to/config.json"

    return 1
}

# Print list of supported games
list_games() {
    check_deps || return 1

    echo "Supported games:"
    echo "================"

    jq -r '.games | to_entries[] |
        "\(.key): \(.value.name)\n   Config: \(.value.config)\n   Priority: \(.value.severity)\n   Description: \(.value.description)\n"' \
        "$DATABASE_PATH"
}

# Validate config availability for one game
check_game() {
    local appid=$1
    check_deps || return 1

    local game_name
    game_name=$(jq -r --arg appid "$appid" '.games[$appid].name // "Not found"' "$DATABASE_PATH")

    if [[ "$game_name" == "Not found" ]]; then
        error "Game with AppID $appid was not found in database"
        return 1
    fi

    echo "Game information:"
    get_game_info "$appid"

    local config
    config=$(find_config_by_appid "$appid")
    if [[ -n "$config" ]]; then
        echo ""
        echo "Config: $config"
        echo "Status: ✓ Ready"

        # Optional cache directory status
        local config_dir
        config_dir=$(dirname "$config")
        if [[ -d "$config_dir/cache" ]]; then
            local cache_count
            cache_count=$(find "$config_dir/cache" -type f | wc -l)
            echo "Cache: $cache_count file(s)"
        fi
    else
        echo ""
        echo "Status: ✗ Config file not found"
        return 1
    fi
}

# Entry point
main() {
    case "${1:-detect}" in
        detect|auto)
            auto_detect
            ;;
        list)
            list_games
            ;;
        check)
            if [[ -z "${2:-}" ]]; then
                error "Usage: $0 check <steam_appid>"
                exit 1
            fi
            check_game "$2"
            ;;
        help|--help|-h)
            cat << EOF
PyroVeil Auto-Detect - Automatic configuration selection

Usage:
  $0 [command]

Commands:
  detect, auto    Automatically detect configuration (default)
  list            Show supported games
  check <appid>   Check configuration for one game
  help            Show this help

Examples:
  $0
  $0 list
  $0 check 2778720

Steam launch options example:
  PYROVEIL=1 PYROVEIL_CONFIG=\$(pyroveil-auto-detect) %command%

Environment variables:
  PYROVEIL_CONFIG        Manual config override (highest priority)
  PYROVEIL_DATABASE      Path to database.json
  PYROVEIL_CONFIG_BASE   Base directory for game configs
  SteamAppId             Steam AppID (usually set by Steam)

Database: $DATABASE_PATH
Configs:  $CONFIG_BASE
