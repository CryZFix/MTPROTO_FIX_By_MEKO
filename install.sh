#!/bin/bash
set -e

BASE_URL="https://raw.githubusercontent.com/Mekotofeuka/MTPROTO_FIX_By_MEKO/main"
FILES=("main.sh" "proxys/proxymenu.sh" "proxys/telemt1.sh" "proxys/mtprotozig1.sh")

if [ "$(id -u)" -ne 0 ]; then
    echo "Запустите от root: curl -fsSL ... | sudo bash" >&2
    exit 1
fi

mkdir -p /opt/mtpr-simple/proxys

for file in "${FILES[@]}"; do
    curl -fsSL "$BASE_URL/$file" -o "/opt/mtpr-simple/$file"
done

chmod +x /opt/mtpr-simple/main.sh
chmod +x /opt/mtpr-simple/proxys/*.sh
ln -sf /opt/mtpr-simple/main.sh /usr/local/bin/mekopr

echo "Установка завершена."
exec /opt/mtpr-simple/main.sh </dev/tty
