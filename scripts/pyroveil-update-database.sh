#!/usr/bin/env bash
# pyroveil-update-database.sh - Update local PyroVeil game database and configs

set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/HansKristian-Work/pyroveil/main"
LOCAL_BASE="${PYROVEIL_HOME:-$HOME/.local/share/pyroveil}"
LOCAL_DB="$LOCAL_BASE/database.json"
HACKS_DIR="$LOCAL_BASE/hacks"

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[pyroveil-update]${NC} $*"; }
warn() { echo -e "${YELLOW}[pyroveil-update]${NC} $*"; }
error() { echo -e "${RED}[pyroveil-update]${NC} $*" >&2; }
success() { echo -e "${GREEN}[pyroveil-update]${NC} $*"; }

# Check required tools
check_deps() {
    if ! command -v curl &>/dev/null; then
        error "curl is not installed. Install it with: sudo pacman -S curl or sudo dnf install curl"
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        warn "jq is not installed - some features will be unavailable"
        warn "Install it with: sudo pacman -S jq or sudo dnf install jq"
    fi
}

# Download helper with retry
# Arguments: URL OUTPUT_PATH
download_file() {
    local url=$1
    local output=$2
    local retries=3

    for i in $(seq 1 "$retries"); do
        if curl -fsSL "$url" -o "$output"; then
            return 0
        fi

        if [[ "$i" -lt "$retries" ]]; then
            warn "Attempt $i failed, retrying..."
            sleep 2
        fi
    done

    return 1
}

# Get remote database version
get_remote_version() {
    curl -fsSL "$REPO_URL/database.json" | jq -r '.version // 0' 2>/dev/null || echo "0"
}

# Get local database version
get_local_version() {
    if [[ -f "$LOCAL_DB" ]]; then
        jq -r '.version // 0' "$LOCAL_DB" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Download one game config from repository
# Argument: relative path under hacks/
download_game_config() {
    local config_path=$1
    local local_path="$HACKS_DIR/$config_path"
    local remote_path="$REPO_URL/hacks/$config_path"

    mkdir -p "$(dirname "$local_path")"

    log "Downloading $config_path..."

    if download_file "$remote_path" "$local_path"; then
        success "✓ $config_path"
        return 0
    else
        warn "✗ Failed to download $config_path"
        return 1
    fi
}

# Update local database and game configs
update_database() {
    log "Checking for PyroVeil database updates..."

    mkdir -p "$LOCAL_BASE"
    mkdir -p "$HACKS_DIR"

    local remote_version
    local local_version
    remote_version=$(get_remote_version)
    local_version=$(get_local_version)

    log "Local version:  $local_version"
    log "Remote version: $remote_version"

    if [[ "$remote_version" -gt "$local_version" ]] || [[ "$local_version" == "0" ]]; then
        log "Update available. Downloading database..."

        # Backup current DB before replacing it
        if [[ -f "$LOCAL_DB" ]]; then
            cp "$LOCAL_DB" "$LOCAL_DB.backup"
            log "Backup created: $LOCAL_DB.backup"
        fi

        if download_file "$REPO_URL/database.json" "$LOCAL_DB"; then
            success "✓ Database updated"

            # Download referenced game config files
            if command -v jq &>/dev/null; then
                log "Updating game config files..."

                local configs
                local count=0
                local total
                configs=$(jq -r '.games[].config' "$LOCAL_DB")
                total=$(echo "$configs" | wc -l)

                while IFS= read -r config; do
                    ((count++))
                    log "[$count/$total] Processing $config..."
                    download_game_config "$config" || true
                done <<< "$configs"

                success "Processed $count config file(s)"
            else
                warn "jq is not installed - config files were not updated"
                warn "Install jq to enable automatic config updates"
            fi
        else
            error "Failed to download database"

            # Restore backup on failure
            if [[ -f "$LOCAL_DB.backup" ]]; then
                mv "$LOCAL_DB.backup" "$LOCAL_DB"
                log "Database restored from backup"
            fi

            exit 1
        fi
    else
        success "Database is already up to date (version $local_version)"
    fi
}

# Force full refresh by removing local DB first
force_update() {
    log "Forcing full update..."
    rm -f "$LOCAL_DB"
    update_database
}

# Show local database metadata
show_info() {
    if [[ ! -f "$LOCAL_DB" ]]; then
        error "Database not found. Run update first: $0 update"
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        error "jq is not installed"
        exit 1
    fi

    echo "PyroVeil Database Information"
    echo "============================="
    echo ""
    echo "File:          $LOCAL_DB"
    echo "Version:       $(jq -r '.version' "$LOCAL_DB")"
    echo "Last updated:  $(jq -r '.last_updated' "$LOCAL_DB")"
    echo "Total games:   $(jq -r '.metadata.total_games' "$LOCAL_DB")"
    echo ""
    echo "By priority:"
    echo "  Critical:    $(jq -r '.metadata.critical_fixes' "$LOCAL_DB")"
    echo "  High:        $(jq -r '.metadata.high_priority' "$LOCAL_DB")"
    echo "  Medium:      $(jq -r '.metadata.medium_priority' "$LOCAL_DB")"
    echo "  Low:         $(jq -r '.metadata.low_priority' "$LOCAL_DB")"
    echo ""
}

# List all supported games from local DB
list_games() {
    if [[ ! -f "$LOCAL_DB" ]]; then
        error "Database not found. Run update first: $0 update"
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        error "jq is not installed"
        exit 1
    fi

    echo "Supported games:"
    echo "================"
    echo ""

    jq -r '.games | to_entries[] |
        "[\(.value.severity | ascii_upcase)] \(.value.name)\n   AppID: \(.key)\n   Config: \(.value.config)\n   Required: \(if .value.required then \"Yes\" else \"No\" end)\n   Description: \(.value.description)\n"' \
        "$LOCAL_DB"
}

# Entry point
main() {
    check_deps

    case "${1:-update}" in
        update|up)
            update_database
            ;;
        force)
            force_update
            ;;
        info)
            show_info
            ;;
        list|ls)
            list_games
            ;;
        help|--help|-h)
            cat << 'HELP'
PyroVeil Database Updater

Usage:
  $0 [command]

Commands:
  update, up     Update database (default)
  force          Force full update of database and config files
  info           Show local database metadata
  list, ls       List supported games
  help           Show this help

Examples:
  $0
  $0 force
  $0 list
  $0 info
HELP
            echo ""
            echo "Database: $LOCAL_DB"
            echo "Configs:  $HACKS_DIR"
            ;;
        *)
            error "Unknown command: $1"
            error "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
