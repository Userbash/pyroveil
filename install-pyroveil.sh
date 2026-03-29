#!/usr/bin/env bash
# install-pyroveil.sh - Универсальный установщик PyroVeil
# Поддержка: Bazzite, Fedora Silverblue/Kinoite, Arch Linux, Generic Linux

set -euo pipefail

VERSION="1.0.0"
REPO_URL="https://github.com/HansKristian-Work/pyroveil.git"
PREFIX="${PREFIX:-$HOME/.local}"
SRC_DIR="${SRC_DIR:-$HOME/.pyroveil-build}"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${BLUE}[install-pyroveil]${NC} $*"; }
warn() { echo -e "${YELLOW}[install-pyroveil]${NC} $*"; }
error() { echo -e "${RED}[install-pyroveil]${NC} $*" >&2; }
success() { echo -e "${GREEN}[install-pyroveil]${NC} $*"; }
header() { echo -e "${BOLD}${CYAN}$*${NC}"; }

die() {
    error "$*"
    exit 1
}

# Определение типа системы
detect_system() {
    local system="unknown"
    
    if command -v rpm-ostree &>/dev/null; then
        system="immutable-fedora"
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        
        if [[ "$ID" == "bazzite" ]] || [[ "$ID_LIKE" =~ "bazzite" ]]; then
            system="bazzite"
        elif [[ "$ID" == "arch" ]] || [[ "$ID_LIKE" =~ "arch" ]]; then
            system="arch"
        elif [[ "$ID" == "fedora" ]] && command -v rpm-ostree &>/dev/null; then
            system="immutable-fedora"
        elif [[ "$ID" == "fedora" ]]; then
            system="fedora"
        elif [[ "$ID" =~ "debian" ]] || [[ "$ID_LIKE" =~ "debian" ]]; then
            system="debian"
        else
            system="generic"
        fi
    fi
    
    echo "$system"
}

# Проверка зависимостей
check_dependencies() {
    local system=$1
    local missing_deps=()
    
    case "$system" in
        immutable-fedora|bazzite)
            if ! command -v distrobox &>/dev/null; then
                error "Distrobox не установлен!"
                error "Установите: rpm-ostree install distrobox && systemctl reboot"
                return 1
            fi
            ;;
        arch)
            for dep in git cmake ninja gcc; do
                if ! command -v $dep &>/dev/null; then
                    missing_deps+=("$dep")
                fi
            done
            
            if [[ ${#missing_deps[@]} -gt 0 ]]; then
                warn "Отсутствуют зависимости: ${missing_deps[*]}"
                warn "Установка зависимостей..."
                sudo pacman -S --needed --noconfirm git cmake ninja gcc || die "Не удалось установить зависимости"
            fi
            ;;
        fedora)
            for dep in git cmake ninja-build gcc-c++; do
                if ! rpm -q $dep &>/dev/null; then
                    missing_deps+=("$dep")
                fi
            done
            
            if [[ ${#missing_deps[@]} -gt 0 ]]; then
                warn "Отсутствуют зависимости: ${missing_deps[*]}"
                warn "Установка зависимостей..."
                sudo dnf install -y git cmake ninja-build gcc-c++ || die "Не удалось установить зависимости"
            fi
            ;;
        debian)
            for dep in git cmake ninja-build g++; do
                if ! dpkg -s $dep &>/dev/null 2>&1; then
                    missing_deps+=("$dep")
                fi
            done
            
            if [[ ${#missing_deps[@]} -gt 0 ]]; then
                warn "Отсутствуют зависимости: ${missing_deps[*]}"
                warn "Установка зависимостей..."
                sudo apt-get update && sudo apt-get install -y git cmake ninja-build g++ || \
                    die "Не удалось установить зависимости"
            fi
            ;;
    esac
    
    return 0
}

# Установка на иммутабельных системах (через distrobox)
install_immutable() {
    header "Установка PyroVeil на иммутабельную систему через Distrobox"
    
    local container_name="pyroveil-build"
    local image="fedora:latest"
    
    # Проверка существования контейнера
    if distrobox list | grep -q "^${container_name}"; then
        log "Контейнер $container_name уже существует, используем его"
    else
        log "Создание контейнера $container_name..."
        distrobox create -n "$container_name" -i "$image" || die "Не удалось создать контейнер"
    fi
    
    log "Подготовка сборочной среды в контейнере..."
    
    # Сборка в контейнере
    distrobox enter "$container_name" -- bash -c "
        set -euo pipefail
        
        # Установка зависимостей
        echo 'Установка зависимостей...'
        sudo dnf install -y git cmake ninja-build gcc-c++ || exit 1
        
        # Клонирование репозитория
        if [[ -d /tmp/pyroveil ]]; then
            rm -rf /tmp/pyroveil
        fi
        
        echo 'Клонирование PyroVeil...'
        git clone --depth 1 '$REPO_URL' /tmp/pyroveil || exit 1
        cd /tmp/pyroveil
        
        echo 'Инициализация субмодулей...'
        git submodule update --init --recursive || exit 1
        
        echo 'Конфигурация CMake...'
        cmake -B build -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX='$PREFIX' || exit 1
        
        echo 'Сборка...'
        ninja -C build || exit 1
        
        echo 'Установка...'
        ninja -C build install || exit 1
        
        # Копирование базы данных и конфигов
        echo 'Установка базы данных и конфигов...'
        mkdir -p '$PREFIX/share/pyroveil/hacks'
        cp -r hacks/* '$PREFIX/share/pyroveil/hacks/' || true
        cp database.json '$PREFIX/share/pyroveil/' 2>/dev/null || true
        
        echo 'Сборка завершена успешно!'
    " || die "Сборка в контейнере не удалась"
    
    success "Сборка в контейнере завершена"
}

# Установка на обычных системах
install_native() {
    header "Установка PyroVeil (нативная сборка)"
    
    # Очистка старой директории сборки
    if [[ -d "$SRC_DIR" ]]; then
        log "Удаление старой директории сборки..."
        rm -rf "$SRC_DIR"
    fi
    
    # Клонирование
    log "Клонирование репозитория из $REPO_URL..."
    git clone --depth 1 "$REPO_URL" "$SRC_DIR" || die "Не удалось клонировать репозиторий"
    
    cd "$SRC_DIR"
    
    # Инициализация субмодулей
    log "Инициализация субмодулей..."
    git submodule update --init --recursive || die "Не удалось обновить субмодули"
    
    # Конфигурация
    log "Конфигурация CMake..."
    cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" || die "Не удалось сконфигурировать проект"
    
    # Сборка
    log "Сборка (может занять несколько минут)..."
    ninja -C build || die "Сборка не удалась"
    
    # Установка
    log "Установка в $PREFIX..."
    ninja -C build install || die "Установка не удалась"
    
    # Копирование дополнительных файлов
    log "Установка конфигов и базы данных..."
    mkdir -p "$PREFIX/share/pyroveil/hacks"
    cp -r hacks/* "$PREFIX/share/pyroveil/hacks/" 2>/dev/null || true
    cp database.json "$PREFIX/share/pyroveil/" 2>/dev/null || true
    
    success "Сборка и установка завершены"
}

# Постустановочная конфигурация
post_install() {
    header "Постустановочная конфигурация"
    
    local layer_path="$PREFIX/share/vulkan/implicit_layer.d"
    local bashrc="$HOME/.bashrc"
    local profile="$HOME/.profile"
    
    # Настройка VK_LAYER_PATH
    log "Настройка переменных окружения..."
    
    local env_line="export VK_LAYER_PATH=\"$layer_path:\${VK_LAYER_PATH:-}\""
    
    if ! grep -qF "VK_LAYER_PATH" "$bashrc" 2>/dev/null; then
        echo "" >> "$bashrc"
        echo "# PyroVeil Vulkan Layer" >> "$bashrc"
        echo "$env_line" >> "$bashrc"
        success "VK_LAYER_PATH добавлен в $bashrc"
    else
        log "VK_LAYER_PATH уже установлен в $bashrc"
    fi
    
    if [[ -f "$profile" ]] && ! grep -qF "VK_LAYER_PATH" "$profile" 2>/dev/null; then
        echo "" >> "$profile"
        echo "# PyroVeil Vulkan Layer" >> "$profile"
        echo "$env_line" >> "$profile"
        success "VK_LAYER_PATH добавлен в $profile"
    fi
    
    # Экспорт для текущей сессии
    export VK_LAYER_PATH="$layer_path${VK_LAYER_PATH:+:$VK_LAYER_PATH}"
    
    # Копирование скриптов
    log "Установка утилит..."
    
    local bin_dir="$PREFIX/bin"
    mkdir -p "$bin_dir"
    
    # Копируем скрипты автоматизации
    if [[ -f "$SRC_DIR/scripts/pyroveil-auto-detect.sh" ]]; then
        cp "$SRC_DIR/scripts/pyroveil-auto-detect.sh" "$bin_dir/pyroveil-auto-detect"
        chmod +x "$bin_dir/pyroveil-auto-detect"
    fi
    
    # Проверка установки jq
    if ! command -v jq &>/dev/null; then
        warn "jq не установлен - автоопределение игр работать не будет"
        warn "Установите: sudo pacman -S jq (Arch) или sudo dnf install jq (Fedora)"
    fi
    
    # Проверка файлов
    local so_file="$PREFIX/lib/libVkLayer_pyroveil_64.so"
    local json_file="$layer_path/VkLayer_pyroveil_64.json"
    
    if [[ -f "$so_file" ]] && [[ -f "$json_file" ]]; then
        success "Файлы слоя установлены корректно:"
        log "  - $so_file"
        log "  - $json_file"
    else
        error "Файлы слоя не найдены!"
        [[ ! -f "$so_file" ]] && error "  Отсутствует: $so_file"
        [[ ! -f "$json_file" ]] && error "  Отсутствует: $json_file"
        return 1
    fi
    
    # Вывод информации о поддерживаемых играх
    local db_file="$PREFIX/share/pyroveil/database.json"
    if [[ -f "$db_file" ]] && command -v jq &>/dev/null; then
        echo ""
        header "Поддерживаемые игры:"
        jq -r '.games[] | "  ✓ \(.name) (AppID: \(.steam_appid // "N/A"))"' "$db_file"
    fi
    
    return 0
}

# Вывод финальной информации
print_final_info() {
    echo ""
    header "╔════════════════════════════════════════════════════════╗"
    header "║       PyroVeil успешно установлен! 🎉                 ║"
    header "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    success "Следующие шаги:"
    echo ""
    echo "  1. Перезапустите терминал или выполните:"
    echo "     ${CYAN}source ~/.bashrc${NC}"
    echo ""
    echo "  2. Для автоматической работы добавьте в Steam launch options:"
    echo "     ${CYAN}PYROVEIL=1 %command%${NC}"
    echo ""
    echo "  3. PyroVeil автоматически определит игру и применит нужный конфиг"
    echo ""
    echo "  4. Для ручной настройки конкретной игры:"
    echo "     ${CYAN}pyroveil-auto-detect check <steam_appid>${NC}"
    echo ""
    echo "  5. Список поддерживаемых игр:"
    echo "     ${CYAN}pyroveil-auto-detect list${NC}"
    echo ""
    
    if ! command -v jq &>/dev/null; then
        warn "⚠️  Для автоопределения игр требуется установить jq:"
        warn "   Arch:   sudo pacman -S jq"
        warn "   Fedora: sudo dnf install jq"
    fi
    
    echo ""
    log "Установка завершена в: $PREFIX"
    log "База данных игр: $PREFIX/share/pyroveil/database.json"
    log "Конфиги игр: $PREFIX/share/pyroveil/hacks/"
    echo ""
}

# Главная функция установки
main() {
    header "╔════════════════════════════════════════════════════════╗"
    header "║  PyroVeil Universal Installer v${VERSION}              ║"
    header "║  Поддержка Vulkan слоев для NVIDIA                    ║"
    header "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # Проверка прав (не должен быть root)
    if [[ $EUID -eq 0 ]]; then
        die "Не запускайте этот скрипт от root! Используйте обычного пользователя."
    fi
    
    # Определение системы
    local system=$(detect_system)
    log "Обнаружена система: ${BOLD}$system${NC}"
    echo ""
    
    # Проверка зависимостей
    log "Проверка зависимостей..."
    check_dependencies "$system" || die "Не удалось проверить/установить зависимости"
    echo ""
    
    # Установка в зависимости от типа системы
    case "$system" in
        immutable-fedora|bazzite)
            install_immutable
            ;;
        *)
            install_native
            ;;
    esac
    
    echo ""
    
    # Постустановочная конфигурация
    post_install || die "Постустановочная конфигурация не удалась"
    
    # Финальная информация
    print_final_info
}

# Запуск
main "$@"
