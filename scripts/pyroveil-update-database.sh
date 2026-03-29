#!/usr/bin/env bash
# pyroveil-update-database.sh - Обновление базы данных игр PyroVeil

set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/HansKristian-Work/pyroveil/main"
LOCAL_BASE="${PYROVEIL_HOME:-$HOME/.local/share/pyroveil}"
LOCAL_DB="$LOCAL_BASE/database.json"
HACKS_DIR="$LOCAL_BASE/hacks"

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[pyroveil-update]${NC} $*"; }
warn() { echo -e "${YELLOW}[pyroveil-update]${NC} $*"; }
error() { echo -e "${RED}[pyroveil-update]${NC} $*" >&2; }
success() { echo -e "${GREEN}[pyroveil-update]${NC} $*"; }

# Проверка зависимостей
check_deps() {
    if ! command -v curl &>/dev/null; then
        error "curl не установлен. Установите: sudo pacman -S curl или sudo dnf install curl"
        exit 1
    fi
    
    if ! command -v jq &>/dev/null; then
        warn "jq не установлен - некоторые функции могут не работать"
        warn "Установите: sudo pacman -S jq или sudo dnf install jq"
    fi
}

# Скачивание файла с повторными попытками
download_file() {
    local url=$1
    local output=$2
    local retries=3
    
    for i in $(seq 1 $retries); do
        if curl -fsSL "$url" -o "$output"; then
            return 0
        fi
        
        if [[ $i -lt $retries ]]; then
            warn "Попытка $i не удалась, повторяю..."
            sleep 2
        fi
    done
    
    return 1
}

# Получение удаленной версии
get_remote_version() {
    curl -fsSL "$REPO_URL/database.json" | jq -r '.version // 0' 2>/dev/null || echo "0"
}

# Получение локальной версии
get_local_version() {
    if [[ -f "$LOCAL_DB" ]]; then
        jq -r '.version // 0' "$LOCAL_DB" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Скачивание конфига игры
download_game_config() {
    local config_path=$1
    local local_path="$HACKS_DIR/$config_path"
    local remote_path="$REPO_URL/hacks/$config_path"
    
    # Создаем директорию
    mkdir -p "$(dirname "$local_path")"
    
    log "Скачивание $config_path..."
    
    if download_file "$remote_path" "$local_path"; then
        success "✓ $config_path"
        
        # Проверяем, есть ли cache директория
        local config_dir=$(dirname "$config_path")
        local cache_url="$REPO_URL/hacks/$config_dir/cache"
        
        # Пытаемся скачать список файлов кэша (если есть)
        # Это упрощенная версия - в реальности нужен API GitHub
        return 0
    else
        warn "✗ Не удалось скачать $config_path"
        return 1
    fi
}

# Обновление базы данных
update_database() {
    log "Проверка обновлений базы данных PyroVeil..."
    
    # Создаем директорию, если не существует
    mkdir -p "$LOCAL_BASE"
    mkdir -p "$HACKS_DIR"
    
    # Получаем версии
    local remote_version=$(get_remote_version)
    local local_version=$(get_local_version)
    
    log "Локальная версия: $local_version"
    log "Удаленная версия: $remote_version"
    
    if [[ "$remote_version" -gt "$local_version" ]] || [[ "$local_version" == "0" ]]; then
        log "Найдено обновление! Скачивание новой базы данных..."
        
        # Резервная копия старой БД
        if [[ -f "$LOCAL_DB" ]]; then
            cp "$LOCAL_DB" "$LOCAL_DB.backup"
            log "Резервная копия: $LOCAL_DB.backup"
        fi
        
        # Скачиваем новую БД
        if download_file "$REPO_URL/database.json" "$LOCAL_DB"; then
            success "✓ База данных обновлена"
            
            # Обновляем конфиги игр
            if command -v jq &>/dev/null; then
                log "Обновление конфигов игр..."
                
                local configs=$(jq -r '.games[].config' "$LOCAL_DB")
                local count=0
                local total=$(echo "$configs" | wc -l)
                
                while IFS= read -r config; do
                    ((count++))
                    log "[$count/$total] Обработка $config..."
                    download_game_config "$config" || true
                done <<< "$configs"
                
                success "Обновлено $count конфиг(ов)"
            else
                warn "jq не установлен - конфиги не обновлены"
                warn "Установите jq для автоматического обновления конфигов"
            fi
        else
            error "Не удалось скачать базу данных"
            
            # Восстанавливаем из резервной копии
            if [[ -f "$LOCAL_DB.backup" ]]; then
                mv "$LOCAL_DB.backup" "$LOCAL_DB"
                log "База данных восстановлена из резервной копии"
            fi
            
            exit 1
        fi
    else
        success "База данных актуальна (версия $local_version)"
    fi
}

# Принудительное обновление
force_update() {
    log "Принудительное обновление всех файлов..."
    
    # Удаляем локальную БД
    rm -f "$LOCAL_DB"
    
    # Обновляем
    update_database
}

# Показать информацию о базе данных
show_info() {
    if [[ ! -f "$LOCAL_DB" ]]; then
        error "База данных не найдена. Выполните обновление: $0 update"
        exit 1
    fi
    
    if ! command -v jq &>/dev/null; then
        error "jq не установлен"
        exit 1
    fi
    
    echo "Информация о базе данных PyroVeil"
    echo "=================================="
    echo ""
    echo "Файл: $LOCAL_DB"
    echo "Версия: $(jq -r '.version' "$LOCAL_DB")"
    echo "Обновлена: $(jq -r '.last_updated' "$LOCAL_DB")"
    echo "Всего игр: $(jq -r '.metadata.total_games' "$LOCAL_DB")"
    echo ""
    echo "По приоритету:"
    echo "  Критические: $(jq -r '.metadata.critical_fixes' "$LOCAL_DB")"
    echo "  Высокий: $(jq -r '.metadata.high_priority' "$LOCAL_DB")"
    echo "  Средний: $(jq -r '.metadata.medium_priority' "$LOCAL_DB")"
    echo "  Низкий: $(jq -r '.metadata.low_priority' "$LOCAL_DB")"
    echo ""
}

# Показать список игр
list_games() {
    if [[ ! -f "$LOCAL_DB" ]]; then
        error "База данных не найдена. Выполните обновление: $0 update"
        exit 1
    fi
    
    if ! command -v jq &>/dev/null; then
        error "jq не установлен"
        exit 1
    fi
    
    echo "Поддерживаемые игры:"
    echo "===================="
    echo ""
    
    jq -r '.games | to_entries[] | 
        "[\(.value.severity | ascii_upcase)] \(.value.name)\n   AppID: \(.key)\n   Конфиг: \(.value.config)\n   Статус: \(if .value.required then "Обязателен" else "Опционален" end)\n   Описание: \(.value.description)\n"' \
        "$LOCAL_DB"
}

# Главная функция
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
            cat << EOF
PyroVeil Database Updater - Обновление базы данных игр

Использование:
  $0 [команда]

Команды:
  update, up     Обновить базу данных (по умолчанию)
  force          Принудительное обновление всех файлов
  info           Показать информацию о базе данных
  list, ls       Показать список поддерживаемых игр
  help           Показать эту справку

Примеры:
  $0                    # Обновить БД
  $0 force              # Принудительное обновление
  $0 list               # Список игр
  $0 info               # Информация о БД

База данных: $LOCAL_DB
Конфиги: $HACKS_DIR
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
