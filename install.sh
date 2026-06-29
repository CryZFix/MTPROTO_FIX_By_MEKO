#!/bin/bash
set -e

BASE_URL="https://raw.githubusercontent.com/Mekotofeuka/MTPROTO_FIX_By_MEKO/main"
FILES=("main.sh" "proxys/proxymenu.sh" "proxys/telemt1.sh" "proxys/mtprotozig1.sh")

# ── Цвета ─────────────────────────────────────────────────────
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# ── Проверка root ────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[✗]${NC} Запустите от root: ${BOLD}curl -fsSL ... | sudo bash${NC}" >&2
    exit 1
fi

# ── Шапка ─────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}${CYAN}⚙️  УСТАНОВКА MEKOPR${NC}"
echo -e "  ${BOLD}${DIM}═════════════════════════════════════════════════${NC}"
echo ""

# ── Подсчёт общего количества файлов ────────────────────────
TOTAL_FILES=${#FILES[@]}
CURRENT_FILE=0

# ── Функция для получения размера файла ──────────────────────
get_file_size() {
    local url="$1"
    local size=$(curl -sI "$url" 2>/dev/null | grep -i "Content-Length" | awk '{print $2}' | tr -d '\r')
    if [ -n "$size" ] && [ "$size" -gt 0 ] 2>/dev/null; then
        if [ "$size" -gt 1048576 ]; then
            echo "$(echo "scale=1; $size/1048576" | bc) MB"
        elif [ "$size" -gt 1024 ]; then
            echo "$(echo "scale=0; $size/1024" | bc) KB"
        else
            echo "$size B"
        fi
    else
        echo "?"
    fi
}

# ── Создание директорий ──────────────────────────────────────
mkdir -p /opt/mtpr-simple/proxys

# ── Скачивание файлов с прогрессом ──────────────────────────
for file in "${FILES[@]}"; do
    CURRENT_FILE=$((CURRENT_FILE + 1))
    FILE_NAME=$(basename "$file")
    
    # Получаем размер файла
    FILE_SIZE=$(get_file_size "$BASE_URL/$file")
    
    echo -ne "  ${CYAN}[${CURRENT_FILE}/${TOTAL_FILES}]${NC} Загрузка ${BOLD}${FILE_NAME}${NC} (${FILE_SIZE})... "
    
    if curl -fsSL "$BASE_URL/$file" -o "/opt/mtpr-simple/$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Ошибка${NC}"
        exit 1
    fi
done

# ── Установка прав и создание ссылки ────────────────────────
echo ""
echo -ne "  ${CYAN}[+]${NC} Установка прав выполнения... "
chmod +x /opt/mtpr-simple/main.sh && chmod +x /opt/mtpr-simple/proxys/*.sh && echo -e "${GREEN}✓${NC}"

echo -ne "  ${CYAN}[+]${NC} Создание ссылки ${BOLD}mekopr${NC}... "
ln -sf /opt/mtpr-simple/main.sh /usr/local/bin/mekopr && echo -e "${GREEN}✓${NC}"

# ── Завершение ───────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}${GREEN}✅ Установка MEKOPR успешно завершена!${NC}"
echo -e "  ${DIM}─────────────────────────────────────────────────────${NC}"
echo ""
echo -e "  Для открытия меню при дальнейшей работе используйте команду ${BOLD}mekopr${NC}"
echo ""

exec /opt/mtpr-simple/main.sh </dev/tty
