#!/data/data/com.termux/files/usr/bin/bash
# ⚡ MAIL.TM — ОБЫЧНАЯ (15 мин) / VIP-АВТО (рандомный домен + VIP-логин)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

VIP_PASS="Tx82Lp91KmN4"
DATA_DIR="$HOME/.mailtm"
mkdir -p "$DATA_DIR"
ACCOUNT_FILE="$DATA_DIR/account.json"
TOKEN_FILE="$DATA_DIR/token.txt"
LAST_ID_FILE="$DATA_DIR/last_msg_id"
EXPIRE_FILE="$DATA_DIR/expire_time"

# === ГЕНЕРАТОР VIP-ЛОГИНА ===
generate_vip_login() {
    local prefix=("777" "666" "888" "999" "555" "111" "333" "444" "222" "000")
    local suffix=("vip" "elite" "king" "boss" "pro" "max" "god" "legend" "star" "prime")
    
    local rand_prefix=${prefix[$RANDOM % ${#prefix[@]}]}
    local rand_suffix=${suffix[$RANDOM % ${#suffix[@]}]}
    
    echo "${rand_prefix}${rand_suffix}"
}

# === ПОЛУЧИТЬ СЛУЧАЙНЫЙ ДОМЕН ===
get_random_domain() {
    domains_json=$(curl -s --max-time 5 https://api.mail.tm/domains 2>/dev/null)
    
    if [ -n "$domains_json" ]; then
        echo "$domains_json" | jq -r '.["hydra:member"][].domain' | shuf -n 1
    else
        # Запасные домены если API не отвечает
        local fallback=("mail.tm" "wshu.net" "crax.live" "digital.ml" "sunmail.xyz")
        echo "${fallback[$RANDOM % ${#fallback[@]}]}"
    fi
}

# === ФУНКЦИЯ: СОЗДАТЬ ЯЩИК ===
create_mail() {
    local mode="$1"
    
    if [ "$mode" = "vip" ]; then
        # VIP: авто-генерация
        local vip_login=$(generate_vip_login)
        local vip_domain=$(get_random_domain)
        email="${vip_login}@${vip_domain}"
        password="Vip_$(shuf -i 100000-999999 -n 1)"
        
        echo -e "\n${PURPLE}👑 Генерирую VIP-почту...${NC}"
    else
        # Обычный: рандомный
        local domain=$(get_random_domain)
        email="user_$(date +%s)@${domain}"
        password="Pass_$(shuf -i 10000-99999 -n 1)"
        
        echo -e "\n${CYAN}📧 Создаю временную почту (15 мин)...${NC}"
    fi
    
    echo -e "📬 ${YELLOW}$email${NC}"
    
    # Создание аккаунта
    account_response=$(curl -s -X POST https://api.mail.tm/accounts \
        -H "Content-Type: application/json" \
        -d "{\"address\":\"$email\",\"password\":\"$password\"}")
    
    error=$(echo "$account_response" | jq -r '.["hydra:description"] // .detail // empty')
    
    if echo "$error" | grep -qi "already exists"; then
        if [ "$mode" = "vip" ]; then
            vip_login="$(generate_vip_login)_x"
        else
            vip_login="user_$(date +%s)_$(shuf -i 10-99 -n 1)"
        fi
        email="${vip_login}@${vip_domain}"
        account_response=$(curl -s -X POST https://api.mail.tm/accounts \
            -H "Content-Type: application/json" \
            -d "{\"address\":\"$email\",\"password\":\"$password\"}")
    fi
    
    # Получение токена
    token_response=$(curl -s -X POST https://api.mail.tm/token \
        -H "Content-Type: application/json" \
        -d "{\"address\":\"$email\",\"password\":\"$password\"}")
    
    token=$(echo "$token_response" | jq -r '.token')
    acc_id=$(echo "$token_response" | jq -r '.id')
    
    if [ -z "$token" ] || [ "$token" = "null" ]; then
        echo -e "${RED}❌ Ошибка создания${NC}"
        exit 1
    fi
    
    # Сохранение
    echo "{\"email\":\"$email\",\"password\":\"$password\",\"id\":\"$acc_id\",\"mode\":\"$mode\"}" > "$ACCOUNT_FILE"
    echo "$token" > "$TOKEN_FILE"
    echo "0" > "$LAST_ID_FILE"
    
    if [ "$mode" = "normal" ]; then
        expire_time=$(( $(date +%s) + 900 ))
        echo "$expire_time" > "$EXPIRE_FILE"
    else
        echo "0" > "$EXPIRE_FILE"
    fi
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ "$mode" = "vip" ]; then
        echo -e "${PURPLE}👑 VIP-ЯЩИК СОЗДАН! (ВЕЧНЫЙ)${NC}"
    else
        echo -e "${CYAN}📬 ВРЕМЕННАЯ ПОЧТА (15 мин)${NC}"
    fi
    echo -e "📧 Адрес: ${YELLOW}$email${NC}"
    echo -e "🔑 Пароль: ${YELLOW}$password${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# === ПРОВЕРКА ИСТЕЧЕНИЯ ===
check_expire() {
    if [ -f "$EXPIRE_FILE" ]; then
        expire_time=$(cat "$EXPIRE_FILE")
        if [ "$expire_time" != "0" ]; then
            current_time=$(date +%s)
            if [ "$current_time" -ge "$expire_time" ]; then
                echo -e "${RED}⏰ Время почты истекло (15 мин)${NC}"
                echo -e "${YELLOW}💡 Используй VIP-режим для вечной почты${NC}"
                rm -f "$ACCOUNT_FILE" "$TOKEN_FILE" "$LAST_ID_FILE" "$EXPIRE_FILE"
                exit 0
            fi
        fi
    fi
}

# === ЗАПУСК ===
clear
echo -e "${YELLOW}╔══════════════════════════════════╗${NC}"
echo -e "${YELLOW}║     📬 MAIL.TM — ДВА РЕЖИМА   ║${NC}"
echo -e "${YELLOW}╚══════════════════════════════════╝${NC}"
echo ""
echo -e "1) ${CYAN}Обычная почта (15 мин)${NC}"
echo -e "2) ${PURPLE}VIP-почта (вечная, авто-генерация)${NC}"
echo -e "3) ${GREEN}Войти в свой VIP-ящик${NC}"
echo ""
read -p "👉 Выбери режим (1/2/3): " mode_choice

case $mode_choice in
    1)
        create_mail "normal"
        email=$(jq -r '.email' "$ACCOUNT_FILE")
        ;;
    2)
        echo ""
        read -sp "🔐 VIP-пароль: " input_pass
        echo ""
        
        if [ "$input_pass" != "$VIP_PASS" ]; then
            echo -e "${RED}❌ Неверный пароль!${NC}"
            exit 1
        fi
        
        echo -e "${PURPLE}👑 VIP-ДОСТУП!${NC}"
        create_mail "vip"
        email=$(jq -r '.email' "$ACCOUNT_FILE")
        ;;
    3)
        echo ""
        read -sp "🔐 VIP-пароль: " input_pass
        echo ""
        
        if [ "$input_pass" != "$VIP_PASS" ]; then
            echo -e "${RED}❌ Неверный пароль!${NC}"
            exit 1
        fi
        
        echo -e "\n${PURPLE}🔐 ВХОД В VIP-ЯЩИК${NC}"
        read -p "📧 Адрес: " email
        read -p "🔑 Пароль: " password
        
        token_response=$(curl -s -X POST https://api.mail.tm/token \
            -H "Content-Type: application/json" \
            -d "{\"address\":\"$email\",\"password\":\"$password\"}")
        
        token=$(echo "$token_response" | jq -r '.token')
        
        if [ -z "$token" ] || [ "$token" = "null" ]; then
            echo -e "${RED}❌ Неверные данные${NC}"
            exit 1
        fi
        
        echo "{\"email\":\"$email\",\"password\":\"$password\",\"id\":\"$(echo "$token_response" | jq -r '.id')\",\"mode\":\"vip\"}" > "$ACCOUNT_FILE"
        echo "$token" > "$TOKEN_FILE"
        echo "0" > "$LAST_ID_FILE"
        echo "0" > "$EXPIRE_FILE"
        
        echo -e "${PURPLE}👑 Добро пожаловать!${NC}"
        ;;
    *)
        echo -e "${RED}❌ Неверный выбор${NC}"
        exit 1
        ;;
esac

# === МОНИТОРИНГ ===
token=$(cat "$TOKEN_FILE")
mode=$(jq -r '.mode' "$ACCOUNT_FILE")

echo ""
echo -e "${YELLOW}╔══════════════════════════════╗${NC}"
echo -e "${YELLOW}║  ⚡ МОНИТОРИНГ (1 сек)    ║${NC}"
echo -e "${YELLOW}╚══════════════════════════════╝${NC}"
echo -e "📬 ${GREEN}$email${NC}"

if [ "$mode" = "normal" ]; then
    remaining=$(( ($(cat "$EXPIRE_FILE") - $(date +%s)) / 60 ))
    echo -e "⏰ Осталось: ${RED}$remaining мин${NC}"
else
    echo -e "🌟 ${PURPLE}VIP (вечный)${NC}"
fi
echo ""

while true; do
    if [ "$mode" = "normal" ]; then
        check_expire
    fi
    
    messages_json=$(curl -s --max-time 2 "https://api.mail.tm/messages" \
        -H "Authorization: Bearer $token")
    
    latest_id=$(echo "$messages_json" | jq -r '.["hydra:member"][0].id // "0"')
    last_id=$(cat "$LAST_ID_FILE")
    
    if [ "$latest_id" != "$last_id" ] && [ "$latest_id" != "0" ]; then
        msg=$(curl -s --max-time 3 "https://api.mail.tm/messages/$latest_id" \
            -H "Authorization: Bearer $token")
        
        from=$(echo "$msg" | jq -r '.from.address // "Неизвестный"')
        subject=$(echo "$msg" | jq -r '.subject // "Без темы"')
        body=$(echo "$msg" | jq -r '.text // .html // ""' | sed 's/<[^>]*>//g')
        
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}⚡ НОВОЕ ПИСЬМО! $(date '+%H:%M:%S')${NC}"
        echo -e "👤 ${CYAN}$from${NC}"
        echo -e "📌 ${YELLOW}$subject${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "$body" | head -c 300
        echo ""
        
        termux-notification \
            --title "📩 $from" \
            --content "$subject" \
            --priority max \
            --vibrate 500 \
            2>/dev/null
        
        echo "$latest_id" > "$LAST_ID_FILE"
    fi
    
    sleep 1
done
