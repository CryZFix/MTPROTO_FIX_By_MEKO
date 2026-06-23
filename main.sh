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

# ── Проверка наличия ЛЮБОГО SYN-правила на порт 443 ────────
is_syn_fix_installed() {
    # Проверяем в iptables-save (ищем 443 и syn в одной строке)
    if iptables-save 2>/dev/null | grep -iE '443.*syn|syn.*443' | grep -q .; then
        return 0
    fi
    # Проверяем во всех .rules файлах в /etc/ufw/
    if grep -rE '443.*syn|syn.*443' /etc/ufw/ --include='*.rules' 2>/dev/null | grep -q .; then
        return 0
    fi
    return 1
}

# ── Установка НАШЕГО SYN FIX (без удаления чужих) ──────────
install_syn_fix() {
    log_info "Установка SYN FIX..."

    # Убеждаемся, что ufw установлен и включен
    apt update
    apt install ufw -y

    ufw allow 22/tcp
    ufw allow 443/tcp

    ufw --force enable

    # Добавляем наши правила в /etc/ufw/before.rules (если их там ещё нет)
    if ! grep -q 'mtpr_syn_fix' /etc/ufw/before.rules; then
        cp /etc/ufw/before.rules /etc/ufw/before.rules.bak.$(date +%s)
        sed -i '/COMMIT/ i\
# MTProxy SYN FIX by MEKO (mtpr_syn_fix)\n\
-A ufw-before-input -p tcp --dport 443 --syn -m hashlimit --hashlimit-name mtproto_443 --hashlimit-mode srcip --hashlimit-upto 54/minute --hashlimit-burst 1 --hashlimit-htable-expire 60000 --hashlimit-htable-size 32768 -m comment --comment "mtpr_syn_fix" -j ACCEPT\n\
-A ufw-before-input -p tcp --dport 443 --syn -j REJECT --reject-with tcp-reset' /etc/ufw/before.rules

        # Если COMMIT не найден, добавляем в конец
        if ! grep -q 'mtpr_syn_fix' /etc/ufw/before.rules; then
            log_info "COMMIT не найден, добавляем правила в конец before.rules"
            echo -e "\n# MTProxy SYN FIX by MEKO (mtpr_syn_fix)" >> /etc/ufw/before.rules
            echo '-A ufw-before-input -p tcp --dport 443 --syn -m hashlimit --hashlimit-name mtproto_443 --hashlimit-mode srcip --hashlimit-upto 54/minute --hashlimit-burst 1 --hashlimit-htable-expire 60000 --hashlimit-htable-size 32768 -m comment --comment "mtpr_syn_fix" -j ACCEPT' >> /etc/ufw/before.rules
            echo '-A ufw-before-input -p tcp --dport 443 --syn -j REJECT --reject-with tcp-reset' >> /etc/ufw/before.rules
        fi
    else
        log_info "Наши правила уже присутствуют в before.rules"
    fi

    # Перезагружаем ufw, чтобы применить изменения
    ufw reload

    log_success "SYN FIX успешно установлен"
}

# ── Удаление ВСЕХ SYN-правил на порт 443 ───────────────────
remove_syn_fix() {
    log_info "Удаление всех SYN-правил на порт 443..."

    # 1. Удаляем из цепочки ufw-before-input в iptables
    local nums=()
    while IFS= read -r line; do
        # Ищем 443 и SYN в одной строке (регистр не важен)
        if echo "$line" | grep -qiE '443.*syn|syn.*443'; then
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
        if grep -qiE '443.*syn|syn.*443' "$file"; then
            cp "$file" "$file.bak.$(date +%s)"
            sed -i '/443.*syn/d' "$file"
            sed -i '/syn.*443/d' "$file"
            sed -i '/^$/d' "$file"
            log_info "Очищен файл: $file"
        fi
    done

    ufw reload

    log_success "Все SYN-правила на порт 443 удалены"
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
    if is_syn_fix_installed; then
        echo -e "  ${BOLD}Статус SYN FIX:${NC} ${GREEN}Установлен${NC}"
    else
        echo -e "  ${BOLD}Статус SYN FIX:${NC} ${DIM}Не установлен${NC}"
    fi
    echo ""
}

# ── Главное меню ─────────────────────────────────────────────
main_menu() {
    while true; do
        # ВАЖНО: ПРОВЕРКА ПЕРЕД КАЖДЫМ ПОКАЗОМ МЕНЮ
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
                    log_info "SYN FIX установлен. Удалить все SYN-правила на порт 443?"
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
