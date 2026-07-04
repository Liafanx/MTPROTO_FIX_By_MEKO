#!/bin/bash
# telemt_in_docker1.sh - Установка Telemt в Docker

# ── Цвета ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Функции логирования ─────────────────────────────────────
log_info() { echo -e "  ${BLUE}[i]${NC} $1"; }
log_success() { echo -e "  ${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "  ${RED}[✗]${NC} $1" >&2; }
log_warning() { echo -e "  ${YELLOW}[!]${NC} $1"; }

# ── Проверка root ────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    log_error "Требуются права root"
    exit 1
fi

# ── Получаем последнюю версию Telemt ────────────────────────
log_info "Получение последней версии Telemt..."
TELEMT_VERSION=$(curl -s https://api.github.com/repos/telemt/telemt/releases/latest | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//')

if [ -z "$TELEMT_VERSION" ]; then
    log_warning "Не удалось получить версию, используем 3.4.22"
    TELEMT_VERSION="3.4.22"
else
    log_success "Последняя версия: $TELEMT_VERSION"
fi

# ── Проверка Docker ──────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    log_warning "Docker не установлен"
    echo -en "  ${BOLD}Установить Docker? Y/n:${NC} "
    read -r install_docker
    if [[ -z "$install_docker" || "$install_docker" =~ ^[yY]$ ]]; then
        log_info "Установка Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
    else
        log_info "Установка отменена"
        echo -e "  ${GRAY}Нажмите любую клавишу для возврата...${NC}"
        read -rsn1
        return 0
    fi
fi

# ── Заголовок ─────────────────────────────────────────────────
clear
echo ""
echo -e "  ${BOLD}УСТАНОВКА TELEMT В DOCKER v0.2${NC}"
echo -e "  ${DIM}================================${NC}"
echo ""
echo -e "  Будет установлен Telemt ${GREEN}${TELEMT_VERSION}${NC} в Docker контейнере"
echo -e "  ${DIM}Версия: ${TELEMT_VERSION}${NC}"
echo ""
echo -en "  ${BOLD}Продолжить установку? Y/n:${NC} "
read -r confirm
if [[ -n "$confirm" && "$confirm" =~ ^[nN]$ ]]; then
    log_info "Установка отменена"
    echo -e "  ${GRAY}Нажмите любую клавишу для возврата...${NC}"
    read -rsn1
    return 0
fi

# ── 1) Автозапуск Docker ─────────────────────────────────────
echo ""
echo -e "  ${BOLD}1. Включить автозапуск Docker при старте системы?${NC}"
echo -e "  ${DIM}(systemctl enable docker && systemctl start docker)${NC}"
echo -en "  ${BOLD}Включить? Y/n:${NC} "
read -r docker_autostart
if [[ -z "$docker_autostart" || "$docker_autostart" =~ ^[yY]$ ]]; then
    log_info "Включение автозапуска Docker..."
    systemctl enable docker 2>/dev/null && systemctl start docker 2>/dev/null
    log_success "Docker автозапуск включён"
else
    log_info "Автозапуск Docker пропущен"
fi

# ── 2) Путь установки ────────────────────────────────────────
echo ""
echo -e "  ${BOLD}2. Путь установки Telemt${NC}"
echo -e "  ${DIM}По умолчанию: /root/telemt${NC}"
echo -en "  ${BOLD}Введите путь или нажмите Enter для выбора стандартного:${NC} "
read -r install_path
if [ -z "$install_path" ]; then
    install_path="/root/telemt"
fi
log_info "Путь: $install_path"

# ── 3) Порт ───────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}3. Порт для прокси${NC}"
echo -e "  ${DIM}По умолчанию: 443${NC}"
echo -en "  ${BOLD}Введите порт или нажмите Enter для выбора порта поумолчанию:${NC} "
read -r port_input
if [ -z "$port_input" ]; then
    port="443"
elif [[ "$port_input" =~ ^[0-9]+$ ]] && [ "$port_input" -ge 1 ] && [ "$port_input" -le 65535 ]; then
    port="$port_input"
else
    log_warning "Некорректный порт, используем 443"
    port="443"
fi
echo -e "  ${GREEN}✓${NC} Использован порт: ${CYAN}${port}${NC}"

# ── 4) Секрет (с циклом) ─────────────────────────────────────
echo ""
echo -e "  ${BOLD}4. Секрет для доступа к прокси${NC}"

SECRET=""
while true; do
    # Генерируем секрет при первом проходе или при gen
    if [ -z "$SECRET" ]; then
        SECRET=$(openssl rand -hex 16)
    fi
    
    echo -e "  ${DIM}Сгенерирован секрет: ${CYAN}${SECRET}${NC}"
    echo ""
    echo -e "  ${BOLD}Варианты:${NC}"
    echo -e "  ${GREEN}Enter/Y${NC} — использовать сгенерированный секрет"
    echo -e "  ${CYAN}Ввести вручную${NC} — указать свой секрет"
    echo -e "  ${RED}gen${NC} — перегенерировать новый секрет"
    echo ""
    echo -en "  ${BOLD}Ваш выбор:${NC} "
    read -r secret_input
    
    if [[ "$secret_input" =~ ^[Gg][Ee][Nn]$ ]]; then
        SECRET=$(openssl rand -hex 16)
        echo ""
        echo -e "  ${GREEN}✓${NC} Новый секрет: ${CYAN}${SECRET}${NC}"
        echo ""
        # Показываем меню снова с новым секретом
        continue
    elif [[ -n "$secret_input" ]] && [[ ! "$secret_input" =~ ^[yY]$ ]] && [[ -z "$secret_input" ]]; then
        # Ввели что-то кроме gen, enter, y, Y
        SECRET="$secret_input"
        echo ""
        echo -e "  ${GREEN}✓${NC} Использован секрет: ${CYAN}${SECRET}${NC}"
        echo ""
        break
    else
        # Enter или y/Y
        echo ""
        echo -e "  ${GREEN}✓${NC} Использован сгенерированный секрет: ${CYAN}${SECRET}${NC}"
        echo ""
        break
    fi
done

# ── 5) TLS домен ─────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}5. TLS домен для маскировки${NC}"
echo -e "  ${DIM}По умолчанию: rutube.ru${NC}"
echo -en "  ${BOLD}Введите домен или нажмите Enter для выбора rutube.ru:${NC} "
read -r tls_domain_input
if [ -z "$tls_domain_input" ]; then
    tls_domain="rutube.ru"
else
    tls_domain="$tls_domain_input"
fi
echo -e "  ${GREEN}✓${NC} Использован домен: ${CYAN}${tls_domain}${NC}"

# ── 6) Определяем IP ─────────────────────────────────────────
SERVER_IP=$(curl -4 -fsS ifconfig.me 2>/dev/null || curl -4 -fsS icanhazip.com 2>/dev/null || echo "127.0.0.1")
echo ""
log_info "Обнаружен IP: $SERVER_IP"

# ── 7) Установка ─────────────────────────────────────────────
echo ""
log_info "Начинаем установку Telemt ${TELEMT_VERSION} в Docker..."
echo ""

# Создаем папку
mkdir -p "$install_path" && cd "$install_path"
log_success "Папка создана: $install_path"

# Создаем config.toml
cat > config.toml <<EOF
[general]
use_middle_proxy = true
log_level = "normal"

[general.modes]
classic = false
secure = false
tls = true

[general.links]
show = "*"
public_host = "$SERVER_IP"
public_port = $port

[server]
port = $port

[server.api]
enabled = true
listen = "0.0.0.0:9091"
whitelist = ["0.0.0.0/0"]

[censorship]
tls_domain = "$tls_domain"
mask = true
tls_emulation = true
tls_front_dir = "tlsfront"

[access.users]
myuser = "$SECRET"
EOF
log_success "config.toml создан"

# Создаем docker-compose.yml
cat > docker-compose.yml <<EOF
services:
  telemt:
    image: ghcr.io/telemt/telemt:${TELEMT_VERSION}
    container_name: telemt
    restart: unless-stopped
    ports:
      - "${port}:${port}"
      - "9091:9091"
    volumes:
      - ./config.toml:/app/config.toml:ro
      - ./tlsfront:/app/tlsfront:rw
    environment:
      - RUST_LOG=info
    cap_add:
      - NET_BIND_SERVICE
    cap_drop:
      - ALL
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
    security_opt:
      - no-new-privileges:true

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=3600
    command: --include telemt
EOF
log_success "docker-compose.yml создан"

# Устанавливаем jq
apt install -y jq >/dev/null 2>&1 || true

# Запускаем
log_info "Запуск Docker контейнера..."
docker compose up -d

if [ $? -eq 0 ]; then
    log_success "Telemt успешно запущен"
else
    log_error "Ошибка запуска Telemt"
fi

# ── 8) Вывод ссылки ──────────────────────────────────────────
echo ""
echo -e "  ${BOLD}${GREEN}═════════════════════════════════════════════════${NC}"
echo -e "  ${BOLD}${GREEN}        TELEMT УСТАНОВЛЕН УСПЕШНО!${NC}"
echo -e "  ${BOLD}${GREEN}═════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}ССЫЛКА ДЛЯ ПОДКЛЮЧЕНИЯ В TELEGRAM:${NC}"
echo ""

sleep 1

# Пробуем получить ссылку
LINK=$(curl -s http://localhost:9091/v1/users 2>/dev/null | jq -r '.data[].links.tls[]' 2>/dev/null | grep -v "::" | grep -v "0.0.0.0" | head -1)
if [ -n "$LINK" ]; then
    echo -e "  ${CYAN}${LINK}${NC}"
else
    echo -e "  ${YELLOW}Ссылка пока не доступна. Попробуйте позже:${NC}"
    echo -e "  ${DIM}  docker compose logs -f${NC}"
    echo -e "  ${DIM}  Или проверьте вручную: curl http://localhost:9091/v1/users${NC}"
fi

echo ""
echo -e "  ${BOLD}Данные для подключения:${NC}"
echo -e "  ${BOLD}Версия:${NC} ${CYAN}${TELEMT_VERSION}${NC}"
echo -e "  ${BOLD}Секрет:${NC} ${CYAN}${SECRET}${NC}"
echo -e "  ${BOLD}IP сервера:${NC} ${CYAN}${SERVER_IP}${NC}"
echo -e "  ${BOLD}Порт:${NC} ${CYAN}${port}${NC}"
echo -e "  ${BOLD}TLS домен:${NC} ${CYAN}${tls_domain}${NC}"
echo ""
echo -e "  ${BOLD}Команды управления:${NC}"
echo -e "  ${DIM}  docker compose logs -f  # просмотр логов${NC}"
echo -e "  ${DIM}  docker compose restart  # перезапуск${NC}"
echo -e "  ${DIM}  docker compose down     # остановка${NC}"
echo -e "  ${DIM}  docker compose up -d    # запуск после остановки${NC}"
echo -e "  ${BOLD}${GREEN}═════════════════════════════════════════════════${NC}"
echo ""

echo -e "  ${GRAY}Нажмите любую клавишу для возврата в меню...${NC}"
read -rsn1
return 0
