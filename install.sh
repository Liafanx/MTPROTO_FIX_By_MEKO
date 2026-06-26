#!/bin/bash
set -e

SCRIPT_URL="https://raw.githubusercontent.com/Mekotofeuka/MTPROTO_FIX_By_MEKO/main/main.sh"

if [ "$(id -u)" -ne 0 ]; then
    echo "Запустите от root: curl -fsSL ... | sudo bash" >&2
    exit 1
fi

mkdir -p /opt/mtpr-simple
curl -fsSL "$SCRIPT_URL" -o /opt/mtpr-simple/main.sh
chmod +x /opt/mtpr-simple/main.sh
ln -sf /opt/mtpr-simple/main.sh /usr/local/bin/mekopr

echo "Установка завершена."
exec /opt/mtpr-simple/main.sh </dev/tty
