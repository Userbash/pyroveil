#!/usr/bin/env bash
#
# steam-game-scanner.sh - Steam library scanner for PyroVeil
#
# This utility scans Steam library folders to find installed games
# and their AppIDs. It supports:
# - Native Steam installations
# - Flatpak Steam (~/.var/app/com.valvesoftware.Steam/)
# - Multiple Steam libraries
# - ACF (appmanifest) file parsing
# - Immutable system compatibility (Bazzite, Silverblue, etc.)
#
# Usage:
#   steam-game-scanner.sh [options]
#
# Options:
#   list                  - List all installed Steam games with AppIDs
#   find <game_name>      - Search for a specific game by name
#   check <appid>         - Check if a game with AppID is installed
#   paths                 - Show all detected Steam library paths
#   supported             - Show PyroVeil supported games installed
#   export-db             - Export installed games to JSON database
#
# Copyright (c) 2025 PyroVeil Contributors
# SPDX-License-Identifier: MIT

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Script directories
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly DATABASE_PATH="${DATABASE_PATH:-$PROJECT_ROOT/database.json}"

#######################################
# Print colored log message
# Arguments:
#   $1 - Message to print
#######################################
log() {
    echo -e "${CYAN}[Steam Scanner]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

#######################################
# Find all Steam library paths
# Returns:
#   Array of Steam library paths
#######################################
find_steam_libraries() {
    local libraries=()
    
    # Native Steam paths
    local native_paths=(
        "$HOME/.local/share/Steam"
        "$HOME/.steam/steam"
        "$HOME/.steam/debian-installation"
    )
    
    # Flatpak Steam paths
    local flatpak_paths=(
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
        "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"
    )
    
    # Check native paths
    for path in "${native_paths[@]}"; do
        if [[ -d "$path/steamapps" ]]; then
            libraries+=("$path")
        fi
    done
    
    # Check Flatpak paths
    for path in "${flatpak_paths[@]}"; do
        if [[ -d "$path/steamapps" ]]; then
            libraries+=("$path")
        fi
    done
    
    # Parse libraryfolders.vdf for additional libraries
    for base_path in "${native_paths[@]}" "${flatpak_paths[@]}"; do
        local vdf_file="$base_path/steamapps/libraryfolders.vdf"
        if [[ -f "$vdf_file" ]]; then
            # Extract paths from VDF file (simplified parser)
            while IFS= read -r line; do
                if [[ "$line" =~ \"path\"[[:space:]]*\"([^\"]+)\" ]]; then
                    local library_path="${BASH_REMATCH[1]}"
                    if [[ -d "$library_path/steamapps" ]]; then
                        libraries+=("$library_path")
                    fi
                fi
            done < "$vdf_file"
        fi
    done
    
    # Remove duplicates
    local unique_libraries=($(printf '%s\n' "${libraries[@]}" | sort -u))
    
    printf '%s\n' "${unique_libraries[@]}"
}

#######################################
# Parse ACF file to extract game info
# Arguments:
#   $1 - Path to ACF file
# Returns:
#   Game info in format: appid|name|installdir
#######################################
parse_acf() {
    local acf_file="$1"
    local appid=""
    local name=""
    local installdir=""
    
    while IFS= read -r line; do
        # Remove leading/trailing whitespace and quotes
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '"')
        
        if [[ "$line" =~ ^appid[[:space:]]+(.*) ]]; then
            appid="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^name[[:space:]]+(.*) ]]; then
            name="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^installdir[[:space:]]+(.*) ]]; then
            installdir="${BASH_REMATCH[1]}"
        fi
    done < "$acf_file"
    
    if [[ -n "$appid" && -n "$name" ]]; then
        echo "$appid|$name|$installdir"
    fi
}

#######################################
# List all installed Steam games
#######################################
list_games() {
    log "Scanning Steam libraries..."
    
    local libraries
    mapfile -t libraries < <(find_steam_libraries)
    
    if [[ ${#libraries[@]} -eq 0 ]]; then
        log_error "No Steam libraries found!"
        log_error "Make sure Steam is installed (native or Flatpak)"
        return 1
    fi
    
    log "Found ${#libraries[@]} Steam library location(s)"
    
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}                    Installed Steam Games                      ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────┬──────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC}  AppID   ${CYAN}│${NC}  Game Name                                           ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────┼──────────────────────────────────────────────────────┤${NC}"
    
    local game_count=0
    
    for library in "${libraries[@]}"; do
        local steamapps="$library/steamapps"
        
        # Find all appmanifest files
        while IFS= read -r -d '' acf_file; do
            local game_info
            game_info=$(parse_acf "$acf_file")
            
            if [[ -n "$game_info" ]]; then
                IFS='|' read -r appid name installdir <<< "$game_info"
                
                # Truncate name if too long (max 48 chars)
                if [[ ${#name} -gt 48 ]]; then
                    name="${name:0:45}..."
                fi
                
                printf "${CYAN}│${NC} %-8s ${CYAN}│${NC} %-52s ${CYAN}│${NC}\n" "$appid" "$name"
                ((game_count++))
            fi
        done < <(find "$steamapps" -maxdepth 1 -name 'appmanifest_*.acf' -print0 2>/dev/null)
    done
    
    echo -e "${CYAN}└──────────┴──────────────────────────────────────────────────────┘${NC}"
    echo ""
    log_success "Found $game_count installed games"
}

#######################################
# Find game by name (case-insensitive)
# Arguments:
#   $1 - Game name (substring match)
#######################################
find_game() {
    local search_term="$1"
    
    if [[ -z "$search_term" ]]; then
        log_error "Please provide a game name to search for"
        return 1
    fi
    
    log "Searching for games matching: '$search_term'"
    
    local libraries
    mapfile -t libraries < <(find_steam_libraries)
    
    if [[ ${#libraries[@]} -eq 0 ]]; then
        log_error "No Steam libraries found!"
        return 1
    fi
    
    local found=0
    
    for library in "${libraries[@]}"; do
        local steamapps="$library/steamapps"
        
        while IFS= read -r -d '' acf_file; do
            local game_info
            game_info=$(parse_acf "$acf_file")
            
            if [[ -n "$game_info" ]]; then
                IFS='|' read -r appid name installdir <<< "$game_info"
                
                # Case-insensitive substring match
                if [[ "${name,,}" == *"${search_term,,}"* ]]; then
                    echo ""
                    echo -e "${GREEN}✓${NC} Found: $name"
                    echo -e "  AppID:       $appid"
                    echo -e "  Install Dir: $installdir"
                    echo -e "  Library:     $library"
                    ((found++))
                fi
            fi
        done < <(find "$steamapps" -maxdepth 1 -name 'appmanifest_*.acf' -print0 2>/dev/null)
    done
    
    echo ""
    if [[ $found -eq 0 ]]; then
        log_warn "No games found matching '$search_term'"
        return 1
    else
        log_success "Found $found matching game(s)"
    fi
}

#######################################
# Check if game with specific AppID is installed
# Arguments:
#   $1 - Steam AppID
#######################################
check_appid() {
    local target_appid="$1"
    
    if [[ -z "$target_appid" ]]; then
        log_error "Please provide an AppID to check"
        return 1
    fi
    
    local libraries
    mapfile -t libraries < <(find_steam_libraries)
    
    if [[ ${#libraries[@]} -eq 0 ]]; then
        log_error "No Steam libraries found!"
        return 1
    fi
    
    for library in "${libraries[@]}"; do
        local acf_file="$library/steamapps/appmanifest_${target_appid}.acf"
        
        if [[ -f "$acf_file" ]]; then
            local game_info
            game_info=$(parse_acf "$acf_file")
            
            if [[ -n "$game_info" ]]; then
                IFS='|' read -r appid name installdir <<< "$game_info"
                
                echo ""
                log_success "Game installed!"
                echo -e "  ${GREEN}✓${NC} AppID:       $appid"
                echo -e "  ${GREEN}✓${NC} Name:        $name"
                echo -e "  ${GREEN}✓${NC} Install Dir: $installdir"
                echo -e "  ${GREEN}✓${NC} Library:     $library"
                echo ""
                return 0
            fi
        fi
    done
    
    log_error "Game with AppID $target_appid is not installed"
    return 1
}

#######################################
# Show all detected Steam library paths
#######################################
show_paths() {
    log "Detecting Steam library paths..."
    
    local libraries
    mapfile -t libraries < <(find_steam_libraries)
    
    if [[ ${#libraries[@]} -eq 0 ]]; then
        log_error "No Steam libraries found!"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}Steam Library Paths:${NC}"
    echo ""
    
    for library in "${libraries[@]}"; do
        echo -e "  ${GREEN}✓${NC} $library"
    done
    
    echo ""
    log_success "Found ${#libraries[@]} library location(s)"
}

#######################################
# Show PyroVeil supported games that are installed
#######################################
show_supported() {
    if [[ ! -f "$DATABASE_PATH" ]]; then
        log_error "Database not found: $DATABASE_PATH"
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is required for this command"
        log_error "Install it using: sudo dnf install jq  (Fedora/Bazzite)"
        log_error "                  sudo apt install jq  (Debian/Ubuntu)"
        log_error "                  sudo pacman -S jq    (Arch)"
        return 1
    fi
    
    log "Checking PyroVeil supported games..."
    
    local libraries
    mapfile -t libraries < <(find_steam_libraries)
    
    if [[ ${#libraries[@]} -eq 0 ]]; then
        log_error "No Steam libraries found!"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}┌───────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}        PyroVeil Supported Games (Installed)                      ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────┬────────────────────────────────┬───────────────────────┤${NC}"
    echo -e "${CYAN}│${NC}  AppID   ${CYAN}│${NC}  Game Name                     ${CYAN}│${NC}  Severity              ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────┼────────────────────────────────┼───────────────────────┤${NC}"
    
    local found_count=0
    
    # Get all AppIDs from database
    local db_appids
    mapfile -t db_appids < <(jq -r '.games | keys[]' "$DATABASE_PATH")
    
    for appid in "${db_appids[@]}"; do
        # Check if this AppID is installed
        local installed=false
        
        for library in "${libraries[@]}"; do
            if [[ -f "$library/steamapps/appmanifest_${appid}.acf" ]]; then
                installed=true
                break
            fi
        done
        
        if [[ "$installed" == "true" ]]; then
            local game_name severity
            game_name=$(jq -r ".games[\"$appid\"].name" "$DATABASE_PATH")
            severity=$(jq -r ".games[\"$appid\"].severity" "$DATABASE_PATH")
            
            # Truncate name if too long
            if [[ ${#game_name} -gt 30 ]]; then
                game_name="${game_name:0:27}..."
            fi
            
            # Color-code severity
            local severity_color="$NC"
            case "$severity" in
                critical) severity_color="$RED" ;;
                high)     severity_color="$YELLOW" ;;
                medium)   severity_color="$BLUE" ;;
                low)      severity_color="$GREEN" ;;
            esac
            
            printf "${CYAN}│${NC} %-8s ${CYAN}│${NC} %-30s ${CYAN}│${NC} ${severity_color}%-21s${NC} ${CYAN}│${NC}\n" \
                   "$appid" "$game_name" "$severity"
            ((found_count++))
        fi
    done
    
    echo -e "${CYAN}└──────────┴────────────────────────────────┴───────────────────────┘${NC}"
    echo ""
    
    if [[ $found_count -eq 0 ]]; then
        log_warn "No PyroVeil supported games found in your Steam library"
        log_warn "This is normal if you don't own any of the supported titles"
    else
        log_success "Found $found_count PyroVeil supported game(s) installed"
        echo ""
        echo "To enable PyroVeil for these games, add to Steam launch options:"
        echo -e "  ${GREEN}PYROVEIL=1 %command%${NC}"
    fi
}

#######################################
# Export installed games to JSON database format
#######################################
export_database() {
    log "Exporting installed games to JSON..."
    
    local libraries
    mapfile -t libraries < <(find_steam_libraries)
    
    if [[ ${#libraries[@]} -eq 0 ]]; then
        log_error "No Steam libraries found!"
        return 1
    fi
    
    local output_file="${1:-$PROJECT_ROOT/installed_games.json}"
    
    echo "{" > "$output_file"
    echo '  "version": 1,' >> "$output_file"
    echo "  \"generated\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," >> "$output_file"
    echo '  "description": "Installed Steam games (auto-generated by steam-game-scanner)",' >> "$output_file"
    echo '  "games": {' >> "$output_file"
    
    local first=true
    
    for library in "${libraries[@]}"; do
        local steamapps="$library/steamapps"
        
        while IFS= read -r -d '' acf_file; do
            local game_info
            game_info=$(parse_acf "$acf_file")
            
            if [[ -n "$game_info" ]]; then
                IFS='|' read -r appid name installdir <<< "$game_info"
                
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo "," >> "$output_file"
                fi
                
                # Escape quotes in name
                name="${name//\"/\\\"}"
                
                cat >> "$output_file" <<EOF
    "$appid": {
      "name": "$name",
      "installdir": "$installdir",
      "library_path": "$library"
    }
EOF
            fi
        done < <(find "$steamapps" -maxdepth 1 -name 'appmanifest_*.acf' -print0 2>/dev/null)
    done
    
    echo "" >> "$output_file"
    echo "  }" >> "$output_file"
    echo "}" >> "$output_file"
    
    log_success "Exported to: $output_file"
}

#######################################
# Show usage information
#######################################
show_usage() {
    cat <<EOF
${CYAN}Steam Game Scanner${NC} - Find installed Steam games and AppIDs

${YELLOW}Usage:${NC}
  steam-game-scanner.sh [command] [options]

${YELLOW}Commands:${NC}
  ${GREEN}list${NC}                List all installed Steam games
  ${GREEN}find${NC} <name>         Search for games by name (substring match)
  ${GREEN}check${NC} <appid>       Check if game with AppID is installed
  ${GREEN}paths${NC}               Show all detected Steam library paths
  ${GREEN}supported${NC}           Show PyroVeil supported games (installed)
  ${GREEN}export-db${NC} [file]    Export installed games to JSON
  ${GREEN}help${NC}                Show this help message

${YELLOW}Examples:${NC}
  ./steam-game-scanner.sh list
  ./steam-game-scanner.sh find "Cyberpunk"
  ./steam-game-scanner.sh check 1091500
  ./steam-game-scanner.sh supported
  ./steam-game-scanner.sh export-db installed.json

${YELLOW}Supported Systems:${NC}
  - Native Steam installations
  - Flatpak Steam (com.valvesoftware.Steam)
  - Multiple Steam library locations
  - Immutable distributions (Bazzite, Silverblue, etc.)

${YELLOW}Notes:${NC}
  - Automatically detects all Steam library folders
  - Parses libraryfolders.vdf for custom library paths
  - Compatible with Proton and native Linux games
EOF
}

#######################################
# Main entry point
#######################################
main() {
    local command="${1:---help}"
    
    case "$command" in
        list)
            list_games
            ;;
        find)
            shift
            find_game "$@"
            ;;
        check)
            shift
            check_appid "$@"
            ;;
        paths)
            show_paths
            ;;
        supported)
            show_supported
            ;;
        export-db)
            shift
            export_database "$@"
            ;;
        --help|help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
