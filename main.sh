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

# ── Проверка root ────────────────────────────────────────────
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Требуются права root"
        exit 1
    fi
}

# ── Проверка, установлен ли НАШ SYN FIX ─────────────────────
is_our_syn_fix_installed() {
    iptables-save 2>/dev/null | grep -q 'mtpr_syn_fix'
    return $?
}

# ── Установка НАШЕГО SYN FIX (без удаления чужих) ────────────
install_syn_fix() {
    log_info "Установка SYN FIX..."

    # Обновляем пакеты и ставим ufw (вывод виден)
    apt update
    apt install ufw -y

    ufw allow 22/tcp
    ufw allow 443/tcp

    ufw --force enable
    ufw reload

    # Добавляем наши правила (если уже есть, то заменим – но по логике меню их нет)
    # Сначала удалим наши старые правила, чтобы не дублировать (на случай, если они остались)
    iptables -D ufw-before-input \
        -p tcp --dport 443 --syn \
        -m hashlimit \
        --hashlimit-name mtproto_443 \
        --hashlimit-mode srcip \
        --hashlimit-upto 54/minute \
        --hashlimit-burst 1 \
        --hashlimit-htable-expire 60000 \
        --hashlimit-htable-size 32768 \
        -m comment --comment "mtpr_syn_fix" \
        -j ACCEPT 2>/dev/null || true

    iptables -D ufw-before-input \
        -p tcp --dport 443 --syn \
        -j REJECT --reject-with tcp-reset 2>/dev/null || true

    # Вставляем новые правила
    iptables -I ufw-before-input 1 \
        -p tcp --dport 443 --syn \
        -m hashlimit \
        --hashlimit-name mtproto_443 \
        --hashlimit-mode srcip \
        --hashlimit-upto 54/minute \
        --hashlimit-burst 1 \
        --hashlimit-htable-expire 60000 \
        --hashlimit-htable-size 32768 \
        -m comment --comment "mtpr_syn_fix" \
        -j ACCEPT

    iptables -I ufw-before-input 2 \
        -p tcp --dport 443 --syn \
        -j REJECT --reject-with tcp-reset

    log_success "SYN FIX успешно установлен"
}

# ── Удаление ТОЛЬКО НАШЕГО SYN FIX ──────────────────────────
remove_syn_fix() {
    log_info "Удаление SYN FIX..."

    # Удаляем только наши правила (с комментарием)
    iptables -D ufw-before-input \
        -p tcp --dport 443 --syn \
        -m hashlimit \
        --hashlimit-name mtproto_443 \
        --hashlimit-mode srcip \
        --hashlimit-upto 54/minute \
        --hashlimit-burst 1 \
        --hashlimit-htable-expire 60000 \
        --hashlimit-htable-size 32768 \
        -m comment --comment "mtpr_syn_fix" \
        -j ACCEPT 2>/dev/null || true

    iptables -D ufw-before-input \
        -p tcp --dport 443 --syn \
        -j REJECT --reject-with tcp-reset 2>/dev/null || true

    log_success "SYN FIX удалён"
}

# ── Пункт 2: Optimization (пока ничего не делает) ────────────
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
    if is_our_syn_fix_installed; then
        echo -e "  ${BOLD}Статус SYN FIX:${NC} ${GREEN}Установлен (наш)${NC}"
    else
        echo -e "  ${BOLD}Статус SYN FIX:${NC} ${DIM}Не установлен${NC}"
    fi
    echo ""
}

# ── Главное меню ─────────────────────────────────────────────
main_menu() {
    while true; do
        show_header

        # Динамическое имя пункта 1
        if is_our_syn_fix_installed; then
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
                if is_our_syn_fix_installed; then
                    log_info "SYN FIX уже установлен. Удалить?"
                    echo -en "  ${BOLD}Удалить? [y/N]:${NC} "
                    local confirm
                    read -r confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        remove_syn_fix
                    else
                        log_info "Отмена удаления"
                    fi
                else
                    log_info "SYN FIX не установлен. Установить?"
                    echo -en "  ${BOLD}Установить? [y/N]:${NC} "
                    local confirm
                    read -r confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        install_syn_fix
                    else
                        log_info "Отмена установки"
                    fi
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
