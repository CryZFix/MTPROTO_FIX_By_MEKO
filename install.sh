#!/bin/bash
# Простой менеджер SYN FIX
# Запуск: curl -fsSL https://raw.githubusercontent.com/Mekotofeuka/MTPR-FIX-By-MEKO/main/install.sh | sudo bash

set -e

SCRIPT_URL="https://raw.githubusercontent.com/Mekotofeuka/MTPR-FIX-By-MEKO/main/main.sh"
LOCAL_FILE="/opt/mtpr-simple/main.sh"
VERSION_FILE="/opt/mtpr-simple/version"

if [ "$(id -u)" -ne 0 ]; then
    echo "Запустите от root: curl -fsSL ... | sudo bash" >&2
    exit 1
fi

mkdir -p /opt/mtpr-simple

# Скачиваем новую версию
curl -fsSL "$SCRIPT_URL" -o "$LOCAL_FILE"
chmod +x "$LOCAL_FILE"

# Сохраняем версию (хеш файла)
md5sum "$LOCAL_FILE" | awk '{print $1}' > "$VERSION_FILE"

ln -sf "$LOCAL_FILE" /usr/local/bin/mekopr

echo "Установка завершена. Запуск меню..."
exec "$LOCAL_FILE" </dev/tty
