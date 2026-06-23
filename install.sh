#!/bin/bash
# Простой менеджер SYN FIX
# Использование: curl -fsSL https://raw.githubusercontent.com/Mekotofeuka/MTPR-FIX-By-MEKO/main/install.sh | sudo bash

set -e

SCRIPT_URL="https://raw.githubusercontent.com/Mekotofeuka/MTPR-FIX-By-MEKO/main/main.sh"

if [ "$(id -u)" -ne 0 ]; then
    echo "Запустите от root: curl -fsSL ... | sudo bash" >&2
    exit 1
fi

mkdir -p /opt/mtpr-simple
curl -fsSL "$SCRIPT_URL" -o /opt/mtpr-simple/main.sh
chmod +x /opt/mtpr-simple/main.sh
ln -sf /opt/mtpr-simple/main.sh /usr/local/bin/mtpr

echo "Установка завершена. Запуск меню..."
exec /opt/mtpr-simple/main.sh </dev/tty
