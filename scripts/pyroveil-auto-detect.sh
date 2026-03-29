#!/usr/bin/env bash
# pyroveil-auto-detect.sh
# Автоматическое определение игры и выбор конфигурации PyroVeil
# Может быть вызван из слоя или использован пользователем

set -euo pipefail

DATABASE_PATH="${PYROVEIL_DATABASE:-$HOME/.local/share/pyroveil/database.json}"
CONFIG_BASE="${PYROVEIL_CONFIG_BASE:-$HOME/.local/share/pyroveil/hacks}"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[pyroveil-detect]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[pyroveil-detect]${NC} $*" >&2; }
error() { echo -e "${RED}[pyroveil-detect]${NC} $*" >&2; }
success() { echo -e "${GREEN}[pyroveil-detect]${NC} $*" >&2; }

# Проверка наличия jq
check_deps() {
    if ! command -v jq &>/dev/null; then
        error "jq не установлен. Установите: sudo pacman -S jq или sudo dnf install jq"
        return 1
    fi
    
    if [[ ! -f "$DATABASE_PATH" ]]; then
        error "База данных не найдена: $DATABASE_PATH"
        error "Выполните: pyroveil-update-database"
        return 1
    fi
    
    return 0
}

# Получить текущий Steam AppID
get_steam_appid() {
    # Приоритет переменных окружения
    local appid="${SteamAppId:-}"
    [[ -z "$appid" ]] && appid="${STEAM_COMPAT_APP_ID:-}"
    [[ -z "$appid" ]] && appid="${SteamGameId:-}"
    
    # Попытка прочитать из командной строки родительского процесса
    if [[ -z "$appid" ]]; then
        local parent_pid=$(ps -o ppid= -p $$ | tr -d ' ')
        if [[ -f "/proc/$parent_pid/environ" ]]; then
            appid=$(tr '\0' '\n' < "/proc/$parent_pid/environ" | grep '^SteamAppId=' | cut -d= -f2)
        fi
    fi
    
    echo "$appid"
}

# Получить имя процесса
get_process_name() {
    cat /proc/self/comm 2>/dev/null || echo "unknown"
}

# Получить путь к исполняемому файлу
get_executable_path() {
    readlink -f /proc/self/exe 2>/dev/null || echo ""
}

# Поиск конфига по Steam AppID
find_config_by_appid() {
    local appid=$1
    [[ -z "$appid" ]] && return 1
    
    local config=$(jq -r --arg appid "$appid" \
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

# Поиск конфига по имени процесса
find_config_by_process_name() {
    local process_name=$1
    [[ -z "$process_name" ]] && return 1
    
    # Ищем все игры, у которых process_name совпадает
    local config=$(jq -r --arg name "$process_name" \
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

# Поиск конфига по пути к исполняемому файлу
find_config_by_exe_path() {
    local exe_path=$1
    [[ -z "$exe_path" ]] && return 1
    
    local exe_name=$(basename "$exe_path" .exe 2>/dev/null || basename "$exe_path")
    
    # Ищем по имени исполняемого файла
    local config=$(jq -r --arg name "$exe_name" \
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

# Получить информацию об игре
get_game_info() {
    local appid=$1
    
    jq -r --arg appid "$appid" \
        '.games[$appid] | "Игра: \(.name)\nОписание: \(.description)\nТребуется: \(.required)\nПриоритет: \(.severity)"' \
        "$DATABASE_PATH"
}

# Основная функция автоопределения
auto_detect() {
    log "Запуск автоопределения конфигурации PyroVeil..."
    
    check_deps || return 1
    
    # 1. Проверяем PYROVEIL_CONFIG (переопределение пользователем)
    if [[ -n "${PYROVEIL_CONFIG:-}" ]]; then
        if [[ -f "$PYROVEIL_CONFIG" ]]; then
            success "Используется пользовательский конфиг: $PYROVEIL_CONFIG"
            echo "$PYROVEIL_CONFIG"
            return 0
        else
            warn "PYROVEIL_CONFIG указан, но файл не найден: $PYROVEIL_CONFIG"
        fi
    fi
    
    # 2. Определение по Steam AppID
    local appid=$(get_steam_appid)
    if [[ -n "$appid" ]]; then
        log "Обнаружен Steam AppID: $appid"
        
        local config=$(find_config_by_appid "$appid")
        if [[ -n "$config" ]]; then
            success "Найден конфиг по AppID: $config"
            get_game_info "$appid" >&2
            echo "$config"
            return 0
        else
            warn "Конфиг для AppID $appid не найден в базе данных"
        fi
    fi
    
    # 3. Определение по имени процесса
    local process_name=$(get_process_name)
    if [[ -n "$process_name" && "$process_name" != "unknown" ]]; then
        log "Имя процесса: $process_name"
        
        local config=$(find_config_by_process_name "$process_name")
        if [[ -n "$config" ]]; then
            success "Найден конфиг по имени процесса: $config"
            echo "$config"
            return 0
        fi
    fi
    
    # 4. Определение по пути к исполняемому файлу
    local exe_path=$(get_executable_path)
    if [[ -n "$exe_path" ]]; then
        log "Путь к исполняемому файлу: $exe_path"
        
        local config=$(find_config_by_exe_path "$exe_path")
        if [[ -n "$config" ]]; then
            success "Найден конфиг по пути: $config"
            echo "$config"
            return 0
        fi
    fi
    
    # 5. Не найдено
    warn "Конфигурация PyroVeil не найдена автоматически"
    warn "Игра будет запущена без исправлений PyroVeil"
    warn ""
    warn "Отладочная информация:"
    warn "  Steam AppID: ${appid:-не обнаружен}"
    warn "  Процесс: ${process_name:-не обнаружен}"
    warn "  Исполняемый файл: ${exe_path:-не обнаружен}"
    warn ""
    warn "Если ваша игра должна поддерживаться PyroVeil:"
    warn "  1. Обновите базу данных: pyroveil-update-database"
    warn "  2. Проверьте список игр: pyroveil-list-games"
    warn "  3. Установите конфиг вручную: export PYROVEIL_CONFIG=/path/to/config.json"
    
    return 1
}

# Список поддерживаемых игр
list_games() {
    check_deps || return 1
    
    echo "Поддерживаемые игры:"
    echo "===================="
    
    jq -r '.games | to_entries[] | 
        "\(.key): \(.value.name)\n   Конфиг: \(.value.config)\n   Приоритет: \(.value.severity)\n   Описание: \(.value.description)\n"' \
        "$DATABASE_PATH"
}

# Проверка конфигурации для конкретной игры
check_game() {
    local appid=$1
    check_deps || return 1
    
    local game_name=$(jq -r --arg appid "$appid" '.games[$appid].name // "Не найдена"' "$DATABASE_PATH")
    
    if [[ "$game_name" == "Не найдена" ]]; then
        error "Игра с AppID $appid не найдена в базе данных"
        return 1
    fi
    
    echo "Информация об игре:"
    get_game_info "$appid"
    
    local config=$(find_config_by_appid "$appid")
    if [[ -n "$config" ]]; then
        echo ""
        echo "Конфиг: $config"
        echo "Статус: ✓ Готов к использованию"
        
        # Проверка наличия cache
        local config_dir=$(dirname "$config")
        if [[ -d "$config_dir/cache" ]]; then
            local cache_count=$(find "$config_dir/cache" -type f | wc -l)
            echo "Кэш: $cache_count файл(ов)"
        fi
    else
        echo ""
        echo "Статус: ✗ Конфиг не найден"
        return 1
    fi
}

# Главная функция
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
                error "Использование: $0 check <steam_appid>"
                exit 1
            fi
            check_game "$2"
            ;;
        help|--help|-h)
            cat << EOF
PyroVeil Auto-Detect - Автоматическое определение конфигурации

Использование:
  $0 [команда]

Команды:
  detect, auto    Автоматически определить конфигурацию (по умолчанию)
  list            Показать список поддерживаемых игр
  check <appid>   Проверить конфигурацию для конкретной игры
  help            Показать эту справку

Примеры:
  $0                          # Автоопределение
  $0 list                     # Список игр
  $0 check 2778720            # Проверка AC Shadows
  
  # Использование в Steam launch options:
  PYROVEIL=1 PYROVEIL_CONFIG=\$(pyroveil-auto-detect) %command%

Переменные окружения:
  PYROVEIL_CONFIG        Переопределить конфиг (приоритет)
  PYROVEIL_DATABASE      Путь к database.json
  PYROVEIL_CONFIG_BASE   Базовая директория конфигов
  SteamAppId             Steam AppID (устанавливается автоматически)

База данных: $DATABASE_PATH
Конфиги: $CONFIG_BASE
EOF
            ;;
        *)
            error "Неизвестная команда: $1"
            error "Используйте '$0 help' для справки"
            exit 1
            ;;
    esac
}

main "$@"
