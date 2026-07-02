#!/bin/bash

# PQC Check Scrip


set -e

# ── Цвета ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

print_header() {
    echo -e "\n${CYAN}━━━ $1 ━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

# ── Проверка зависимостей ──────────────────────────────────
check_dependencies() {
    print_header "ПРОВЕРКА ЗАВИСИМОСТЕЙ V5"

    
    # Устанавливаем build-essential если нет
    if ! command -v cc &> /dev/null; then
        print_info "Устанавливаю build-essential..."
        apt install -y build-essential
        print_success "build-essential установлен"
    else
        print_success "build-essential уже установлен"
    fi
    
    local missing=()
    for cmd in openssl curl nslookup; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_warning "Отсутствуют: ${missing[*]}"
        print_info "Устанавливаю необходимые пакеты..."
        apt install -y openssl curl dnsutils
        print_success "Зависимости установлены"
    else
        print_success "Все зависимости установлены"
    fi
}

# ── Проверка наличия Rust и pqfetch ────────────────────────
check_rust_pqfetch() {
    if [ -f "$HOME/.cargo/bin/rustc" ]; then
        export PATH="$HOME/.cargo/bin:$PATH"
        return 0
    fi
    if command -v rustc &> /dev/null; then
        return 0
    fi
    return 1
}

check_pqfetch() {
    if [ -f "$HOME/.cargo/bin/pqfetch" ]; then
        export PATH="$HOME/.cargo/bin:$PATH"
        return 0
    fi
    if command -v pqfetch &> /dev/null; then
        return 0
    fi
    return 1
}

# ── Установка Rust и pqfetch ──────────────────────────────
install_pqfetch() {
    local need_rust=false
    local need_pqfetch=false
    
    if ! check_rust_pqfetch; then
        need_rust=true
    fi
    
    if ! check_pqfetch; then
        need_pqfetch=true
    fi
    
    if [ "$need_rust" = false ] && [ "$need_pqfetch" = false ]; then
        return 0
    fi
    
    echo ""
    print_info "Для работы необходимо установить следующие компоненты:"
    echo ""
    echo -e "  ${BOLD}1. Rust${NC} — язык программирования"
    echo -e "  ${BOLD}2. pqfetch${NC} — утилита для проверки PQ-шифров"
    echo ""
    echo -en "  ${BOLD}Установить компоненты?${NC} ${GREEN}[Enter/Y - да, N - нет]:${NC} "
    read -r install_confirm
    
    if [[ -n "$install_confirm" && "$install_confirm" =~ ^[nN]$ ]]; then
        echo ""
        print_info "Возврат в главное меню..."
        sleep 0.5
        return 1
    fi
    
    print_header "УСТАНОВКА RUST И PQFECTH"
    
    if [ "$need_rust" = true ]; then
        print_info "Устанавливаю Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        export PATH="$HOME/.cargo/bin:$PATH"
        print_success "Rust установлен"
    else
        print_success "Rust уже установлен"
    fi
    
    if [ "$need_pqfetch" = true ]; then
        print_info "Устанавливаю pqfetch..."
        export PATH="$HOME/.cargo/bin:$PATH"
        cargo install pqfetch
        print_success "pqfetch установлен"
    else
        print_success "pqfetch уже установлен"
    fi
    
    export PATH="$HOME/.cargo/bin:$PATH"
    return 0
}

# ── Проверка прокси ────────────────────────────────────────
check_site() {
    local domain="$1"
    local port="${2:-443}"
    
    echo -e "\n${BOLD}🔎 ${domain}:${port}${NC}"
    
    # IP-адреса
    echo -e "\n${CYAN}🌐 IP-адреса:${NC}"
    nslookup $domain 2>/dev/null | grep -E 'Address: ' | grep -v '#' | awk '{print $2}' | head -3 | while read ip; do
        echo "  $ip"
    done
    echo ""
    
    # ── PQ-проверка через pqfetch ──────────────────────────
    echo -e "${CYAN}━━━ PQ-подключение (X25519MLKEM768) ━━━${NC}"
    export PATH="$HOME/.cargo/bin:$PATH"
    PQFECTH_OUTPUT=$(pqfetch $domain 2>&1 || true)
    
    if echo "$PQFECTH_OUTPUT" | grep -qi "X25519MLKEM768"; then
        echo -e "${GREEN}✅ ПОДДЕРЖИВАЕТ X25519MLKEM768${NC}"
        echo "$PQFECTH_OUTPUT" | head -1
        echo ""
        echo -e "${GREEN}━━━ ВЕРДИКТ ━━━${NC}"
        echo -e "${GREEN}🟢 PQ-безопасен (X25519MLKEM768)${NC}"
    elif echo "$PQFECTH_OUTPUT" | grep -qi "X25519"; then
        echo -e "${YELLOW}⚠️ Использует X25519 (классический)${NC}"
        echo "$PQFECTH_OUTPUT" | head -1
        echo ""
        # Переходим к обычному TLS
        check_regular_tls "$domain" "$port" "X25519"
    else
        echo -e "${RED}❌ PQ не поддерживается${NC}"
        # Показываем причину если есть
        echo "$PQFECTH_OUTPUT" | head -3 | grep -E "error|alert|invalid" | while read line; do
            echo -e "  ${GRAY}${line}${NC}"
        done
        echo ""
        # Переходим к обычному TLS
        check_regular_tls "$domain" "$port" ""
    fi
}

# ── Проверка обычного TLS ───────────────────────────────────
check_regular_tls() {
    local domain="$1"
    local port="$2"
    local pq_status="$3"
    
    echo -e "${CYAN}━━━ Обычное TLS-подключение ━━━${NC}"
    
    # Пробуем через openssl s_client
    local tls_info=""
    if command -v openssl &> /dev/null; then
        tls_info=$(echo | timeout 5 openssl s_client -connect ${domain}:${port} -servername ${domain} 2>/dev/null | grep -E "Protocol|Cipher|Server Temp Key|subject=" | head -6)
    fi
    
    if [ -n "$tls_info" ]; then
        echo -e "${GREEN}🔹 Статус: OK${NC}"
        echo "$tls_info"
        echo ""
        
        # Проверяем наличие X25519 в Server Temp Key
        if echo "$tls_info" | grep -qi "X25519"; then
            if [ "$pq_status" = "X25519" ] || [ -z "$pq_status" ]; then
                echo -e "${RED}━━━ ВЕРДИКТ ━━━${NC}"
                echo -e "${RED}🔴 МАРКЕР: ДА${NC}"
                echo -e "${RED}PQ не поддерживается + Peer Temp Key = X25519${NC}"
                echo -e "${YELLOW}⚠️ Риск блокировки на ТСПУ для iOS клиентов${NC}"
            else
                echo -e "${GREEN}━━━ ВЕРДИКТ ━━━${NC}"
                echo -e "${GREEN}🟢 Маркер: НЕТ${NC}"
                echo -e "${GREEN}PQ поддерживается${NC}"
            fi
        else
            echo -e "${GREEN}━━━ ВЕРДИКТ ━━━${NC}"
            echo -e "${GREEN}🟢 Маркер: НЕТ${NC}"
            echo -e "${GREEN}PQ не поддерживается, но Peer Temp Key не X25519${NC}"
        fi
    else
        # Пробуем через curl
        echo -e "${YELLOW}⚠️ openssl не дал результат, пробую через curl...${NC}"
        local curl_info=$(timeout 5 curl -vI --tlsv1.3 --connect-timeout 3 "https://${domain}:${port}" 2>&1 | grep -E "SSL connection|TLS|subject" | head -5)
        
        if [ -n "$curl_info" ]; then
            echo -e "${GREEN}🔹 Статус: OK${NC}"
            echo "$curl_info"
            echo ""
            echo -e "${GREEN}━━━ ВЕРДИКТ ━━━${NC}"
            echo -e "${GREEN}🟢 Маркер: НЕТ${NC}"
            echo -e "${GREEN}TLS подключение установлено${NC}"
        else
            echo -e "${RED}❌ Не удалось подключиться по TLS${NC}"
            echo ""
            echo -e "${RED}━━━ ВЕРДИКТ ━━━${NC}"
            echo -e "${RED}🔴 Не удалось проверить${NC}"
        fi
    fi
    echo ""
}

# ── Парсинг ввода ───────────────────────────────────────────
parse_and_check() {
    local input="$1"
    local domain=""
    local port="443"
    local secret=""
    
    # Проверяем, является ли входная строка Telegram-ссылкой
    if echo "$input" | grep -qi "t.me/proxy\|tg://proxy"; then
        domain=$(echo "$input" | grep -oP 'server=\K[^&]+' 2>/dev/null || echo "")
        port=$(echo "$input" | grep -oP 'port=\K[^&]+' 2>/dev/null || echo "443")
        secret=$(echo "$input" | grep -oP 'secret=\K[^&]+' 2>/dev/null || echo "")
        
        if [ -z "$domain" ]; then
            print_error "Не удалось извлечь server из ссылки"
            return 1
        fi
        
        echo -e "\n${CYAN}━━━ РАСПАРСЕНО ИЗ ССЫЛКИ ━━━${NC}"
        echo -e "  ${BOLD}Сервер:${NC} $domain"
        echo -e "  ${BOLD}Порт:${NC} $port"
        if [ -n "$secret" ]; then
            echo -e "  ${BOLD}Секрет:${NC} ${secret:0:20}... (обрезано)"
        fi
        echo ""
    else
        # Обычный домен или IP:порт
        domain="$input"
        if echo "$domain" | grep -q ":"; then
            port=$(echo "$domain" | cut -d':' -f2)
            domain=$(echo "$domain" | cut -d':' -f1)
        fi
    fi
    
    check_site "$domain" "$port"
}

# ── Очистка экрана ──────────────────────────────────────────
clear_screen() {
    clear 2>/dev/null || printf '\033[2J\033[H'
}

# ── Основная функция ────────────────────────────────────────
main() {
    clear_screen
    echo ""
    echo -e "  ${BOLD}${CYAN}🔍 ПРОВЕРКА ПРОКСИ НА PQ-БЕЗОПАСНОСТЬ${NC}"
    echo -e "  ${DIM}═════════════════════════════════════════════════${NC}"
    echo ""
    
    # Проверяем зависимости
    check_dependencies
    
    # Проверяем и устанавливаем Rust + pqfetch
    if ! install_pqfetch; then
        return 0
    fi
    
    # Цикл проверки
    while true; do
        echo ""
        echo -e "  ${BOLD}Введите ссылку на прокси для проверки:${NC}"
        echo -e "  ${DIM}Примеры:${NC}"
        echo -e "  ${DIM}  • tg://proxy?server=212.8.229.241&port=443&secret=...${NC}"
        echo -e "  ${DIM}  • 212.8.229.241:443${NC}"
        echo -e "  ${DIM}  • rutube.ru${NC}"
        echo -e "  ${DIM}  • 0 (ноль), n или q — выход в главное меню${NC}"
        echo ""
        echo -en "  ${BOLD}Ввод:${NC} "
        read -r proxy_input
        
        # Проверка на выход
        if [[ "$proxy_input" == "0" || "$proxy_input" =~ ^[nN]$ || "$proxy_input" =~ ^[qQ]$ ]]; then
            echo ""
            print_info "Возврат в главное меню..."
            sleep 0.5
            return 0
        fi
        
        # Проверка на пустой ввод
        if [ -z "$proxy_input" ]; then
            print_warning "Вы ничего не ввели. Попробуйте снова или введите 0 для выхода."
            continue
        fi
        
        parse_and_check "$proxy_input"
        
        echo ""
        echo -e "  ${GRAY}Нажмите Enter для продолжения или 0 для выхода...${NC}"
        read -r continue_choice
        if [[ "$continue_choice" == "0" || "$continue_choice" =~ ^[nN]$ || "$continue_choice" =~ ^[qQ]$ ]]; then
            echo ""
            print_info "Возврат в главное меню..."
            sleep 0.5
            return 0
        fi
        
        # Очищаем экран после Enter
        clear_screen
        echo ""
        echo -e "  ${BOLD}${CYAN}🔍 ПРОВЕРКА ПРОКСИ НА PQ-БЕЗОПАСНОСТЬ${NC}"
        echo -e "  ${DIM}═════════════════════════════════════════════════${NC}"
        echo ""
    done
}

# ── Запуск ──────────────────────────────────────────────────
main "$@"
