#!/bin/bash
# Простой менеджер SYN FIX
# Меню: 1) Install/Remove SYN FIX, 2) Optimization, 0) Exit

set -eo pipefail

# ── Цвета ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Логирование ─────────────────────────────────────────────
log_info()    { echo -e "  ${BLUE}[i]${NC} $1"; }
log_success() { echo -e "  ${GREEN}[✓]${NC} $1"; }
log_error()   { echo -e "  ${RED}[✗]${NC} $1" >&2; }

# ── Файл для хранения порта ─────────────────────────────────
PORT_FILE="/opt/mtpr-simple/port"

# ── Проверка root ────────────────────────────────────────────
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Требуются права root"
        exit 1
    fi
}

# ── Определение порта из сохранённого файла ──────────────────
get_saved_port() {
    if [ -f "$PORT_FILE" ]; then
        cat "$PORT_FILE"
    else
        echo ""
    fi
}

save_port() {
    echo "$1" > "$PORT_FILE"
}

# ── Проверка наличия ЛЮБОГО SYN-правила (TCP + SYN) ──────────
is_syn_fix_installed() {
    # Проверяем в iptables-save на наличие строк с tcp и syn (регистр не важен)
    if iptables-save 2>/dev/null | grep -iE 'tcp.*--syn|--syn.*tcp' | grep -q .; then
        return 0
    fi
    # Проверяем во всех .rules файлах в /etc/ufw/
    if grep -rE 'tcp.*--syn|--syn.*tcp' /etc/ufw/ --include='*.rules' 2>/dev/null | grep -q .; then
        return 0
    fi
    return 1
}

# ── Определение Telemt ──────────────────────────────────────
detect_telemt() {
    # Ищем процесс telemt
    if pgrep -x telemt >/dev/null 2>&1; then
        # Пытаемся найти конфиг
        local configs=(
            "/etc/telemt/telemt.toml"
            "/etc/telemt/config.toml"
            "/etc/telemt.toml"
            "/opt/telemt/config.toml"
            "/opt/telemt/telemt.toml"
        )
        for cfg in "${configs[@]}"; do
            if [ -f "$cfg" ]; then
                # Парсим порт
                local port=$(grep -E '^port[[:space:]]*=' "$cfg" | head -1 | awk -F'=' '{print $2}' | tr -d ' "')
                if [[ "$port" =~ ^[0-9]+$ ]]; then
                    echo "установлен (порт $port)"
                    return 0
                fi
            fi
        done
        echo "установлен (порт не определён)"
        return 0
    else
        echo "не обнаружен"
        return 1
    fi
}

# ── Установка SYN FIX ──────────────────────────────────────
install_syn_fix() {
    local port
    echo ""
    echo -en "  ${BOLD}Введите порт для SYN FIX (по умолчанию 443):${NC} "
    read -r port
    if [ -z "$port" ]; then
        port="443"
    fi
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Некорректный порт, используем 443"
        port="443"
    fi

    log_info "Установка SYN FIX на порт $port..."

    # Убеждаемся, что ufw установлен и включен
    apt update
    apt install ufw -y

    ufw allow 22/tcp
    ufw allow "$port"/tcp

    ufw --force enable

    # Добавляем наши правила в /etc/ufw/before.rules (если их там ещё нет)
    if ! grep -q 'mtpr_syn_fix' /etc/ufw/before.rules; then
        cp /etc/ufw/before.rules /etc/ufw/before.rules.bak.$(date +%s)
        sed -i "/COMMIT/ i\
# MTProxy SYN FIX by MEKO (mtpr_syn_fix)\n\
-A ufw-before-input -p tcp --dport $port --syn -m hashlimit --hashlimit-name mtproto_$port --hashlimit-mode srcip --hashlimit-upto 54/minute --hashlimit-burst 1 --hashlimit-htable-expire 60000 --hashlimit-htable-size 32768 -m comment --comment \"mtpr_syn_fix\" -j ACCEPT\n\
-A ufw-before-input -p tcp --dport $port --syn -j REJECT --reject-with tcp-reset" /etc/ufw/before.rules

        # Если COMMIT не найден, добавляем в конец
        if ! grep -q 'mtpr_syn_fix' /etc/ufw/before.rules; then
            log_info "COMMIT не найден, добавляем правила в конец before.rules"
            echo -e "\n# MTProxy SYN FIX by MEKO (mtpr_syn_fix)" >> /etc/ufw/before.rules
            echo "-A ufw-before-input -p tcp --dport $port --syn -m hashlimit --hashlimit-name mtproto_$port --hashlimit-mode srcip --hashlimit-upto 54/minute --hashlimit-burst 1 --hashlimit-htable-expire 60000 --hashlimit-htable-size 32768 -m comment --comment \"mtpr_syn_fix\" -j ACCEPT" >> /etc/ufw/before.rules
            echo "-A ufw-before-input -p tcp --dport $port --syn -j REJECT --reject-with tcp-reset" >> /etc/ufw/before.rules
        fi
    else
        log_info "Наши правила уже присутствуют в before.rules"
    fi

    # Сохраняем порт
    save_port "$port"

    # Перезагружаем ufw
    ufw reload

    log_success "SYN FIX успешно установлен на порт $port"
}

# ── Удаление ВСЕХ SYN-правил (TCP + SYN) ──────────────────
remove_syn_fix() {
    log_info "Удаление всех SYN-правил (TCP + SYN)..."

    # 1. Удаляем из цепочки ufw-before-input в iptables
    local nums=()
    while IFS= read -r line; do
        # Ищем строки с TCP и SYN (регистр не важен)
        if echo "$line" | grep -qiE 'tcp.*syn|syn.*tcp'; then
            num=$(echo "$line" | awk '{print $1}')
            nums+=("$num")
        fi
    done < <(iptables -L ufw-before-input --line-numbers -n 2>/dev/null)

    # Удаляем в обратном порядке
    for num in $(printf '%s\n' "${nums[@]}" | sort -nr); do
        iptables -D ufw-before-input "$num" 2>/dev/null && log_info "Удалено правило #$num из iptables"
    done

    # 2. Удаляем строки с SYN-правилами из всех .rules файлов в /etc/ufw/
    find /etc/ufw/ -name '*.rules' -type f | while read -r file; do
        if grep -qiE 'tcp.*syn|syn.*tcp' "$file"; then
            cp "$file" "$file.bak.$(date +%s)"
            # Удаляем строки, содержащие tcp и syn (в любом порядке)
            sed -i '/tcp.*syn/d' "$file"
            sed -i '/syn.*tcp/d' "$file"
            sed -i '/^$/d' "$file"
            log_info "Очищен файл: $file"
        fi
    done

    ufw reload
    rm -f "$PORT_FILE"

    log_success "Все SYN-правила удалены"
}

# ── Пункт 2: Optimization (пока ничего не делает) ──────────
apply_optimization() {
    log_info "Оптимизация пока не реализована"
}

# ── Очистка экрана и шапка ──────────────────────────────────
clear_screen() {
    clear 2>/dev/null || printf '\033[2J\033[H'
}

show_header() {
    clear_screen
    echo ""
    echo -e "  ${BOLD}Простой менеджер SYN FIX${NC}"
    echo -e "  ${DIM}===========================${NC}"
    echo ""
    # Статус SYN FIX (любое правило)
    if is_syn_fix_installed; then
        echo -e "  ${BOLD}SYN FIX:${NC} ${GREEN}Установлен${NC}"
    else
        echo -e "  ${BOLD}SYN FIX:${NC} ${DIM}Не установлен${NC}"
    fi
    # Статус Telemt
    telemt_status=$(detect_telemt)
    echo -e "  ${BOLD}Telemt:${NC} ${telemt_status}"
    echo ""
}

# ── Главное меню ─────────────────────────────────────────────
main_menu() {
    while true; do
        show_header

        # Динамическое имя пункта 1
        if is_syn_fix_installed; then
            local item1="${RED}Remove SYN FIX${NC}"
        else
            local item1="${GREEN}Install SYN FIX${NC}"
        fi

        echo -e "  ${CYAN}[1]${NC}  $item1"
        echo -e "  ${CYAN}[2]${NC}  Optimization (пока ничего не делает)"
        echo -e "  ${CYAN}[0]${NC}  Выход"
        echo ""
        echo -en "  ${BOLD}Выбор:${NC} "
        local choice
        read -r choice

        case "$choice" in
            1)
                echo ""
                if is_syn_fix_installed; then
                    log_info "Обнаружены SYN-правила. Удалить ВСЕ такие правила?"
                    echo -en "  ${BOLD}Удалить? [y/N]:${NC} "
                    local confirm
                    read -r confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        remove_syn_fix
                    else
                        log_info "Отмена удаления"
                    fi
                else
                    install_syn_fix
                fi
                echo ""
                read -rsn1 -p "  Нажмите любую клавишу для возврата в меню..."
                ;;
            2)
                echo ""
                apply_optimization
                echo ""
                read -rsn1 -p "  Нажмите любую клавишу для возврата в меню..."
                ;;
            0|q|Q)
                echo ""
                log_info "Выход"
                exit 0
                ;;
            *)
                log_error "Неверный выбор"
                sleep 1
                ;;
        esac
    done
}

# ── Запуск ────────────────────────────────────────────────────
check_root
main_menu
