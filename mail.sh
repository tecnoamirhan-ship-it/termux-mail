#!/data/data/com.termux/files/usr/bin/bash
# ⚡ MAIL.TM — ОБЫЧНАЯ (15 мин) / VIP (вечная + выбор домена + свой логин)

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

# === ФУНКЦИЯ: ПОКАЗАТЬ ДОМЕНЫ ===
show_domains() {
    echo -e "\n${CYAN}📡 Загружаю домены...${NC}"
    domains_json=$(curl -s https://api.mail.tm/domains)
    
    echo -e "\n${YELLOW}🔥 ДОСТУПНЫЕ ДОМЕНЫ:${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo "$domains_json" | jq -r '.["hydra:member"][] | "\(.domain)"' | \
    while read domain; do
        if [ "$domain" = "wshu.net" ]; then
            echo -e "  🌟 ${YELLOW}$domain${NC} ${RED}[VIP-ДОМЕН]${NC}"
        else
            echo "  📧 $domain"
        fi
    done
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# === ФУНКЦИЯ: СОЗДАТЬ ЯЩИК ===
create_mail() {
    local mode="$1"  # "vip" или "normal"
    
    if [ "$mode" = "vip" ]; then
        # VIP: выбор домена + свой логин
        show_domains
        
        echo ""
        read -p "📧 Введи домен (Enter для wshu.net): " chosen_domain
        [ -z "$chosen_domain" ] && chosen_domain="wshu.net"
        
        echo ""
        echo -e "${PURPLE}💎 СОЗДАЙ СВОЙ VIP-АДРЕС${NC}"
        read -p "Введи желаемый логин (например 777): " custom_login
        
        if [ -n "$custom_login" ]; then
            email="${custom_login}@${chosen_domain}"
        else
            email="vip_$(date +%s)@${chosen_domain}"
        fi
        
        read -p "🔑 Придумай пароль: " password
        
        echo -e "\n${PURPLE}👑 Создаю VIP-ящик $email ...${NC}"
    else
        # Обычный: рандомный домен + логин
        domains_json=$(curl -s https://api.mail.tm/domains)
        domain=$(echo "$domains_json" | jq -r '.["hydra:member"][0].domain')
        email="user_$(date +%s)@${domain}"
        password="Pass_$(shuf -i 10000-99999 -n 1)"
        
        echo -e "\n${CYAN}📧 Создаю временный ящик (15 мин)...${NC}"
    fi
    
    # Создание аккаунта
    account_response=$(curl -s -X POST https://api.mail.tm/accounts \
        -H "Content-Type: application/json" \
        -d "{\"address\":\"$email\",\"password\":\"$password\"}")
    
    # Проверка на занятость
    error=$(echo "$account_response" | jq -r '.["hydra:description"] // .detail // empty')
    
    if echo "$error" | grep -qi "already exists"; then
        if [ "$mode" = "vip" ]; then
            email="${custom_login}_x@${chosen_domain}"
        else
            email="user_$(date +%s)_$(shuf -i 10-99 -n 1)@${domain}"
        fi
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
    
    # Для обычного режима — таймер на 15 минут
    if [ "$mode" = "normal" ]; then
        expire_time=$(( $(date +%s) + 900 ))
        echo "$expire_time" > "$EXPIRE_FILE"
    else
        echo "0" > "$EXPIRE_FILE"
    fi
    
    # Вывод информации
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ "$mode" = "vip" ]; then
        echo -e "${PURPLE}👑 VIP-ЯЩИК ГОТОВ! (ВЕЧНЫЙ)${NC}"
    else
        echo -e "${CYAN}📬 ВРЕМЕННЫЙ ЯЩИК (15 мин)${NC}"
    fi
    echo -e "📧 Адрес: ${YELLOW}$email${NC}"
    echo -e "🔑 Пароль: ${YELLOW}$password${NC}"
    echo -e "🆔 ID: ${CYAN}$acc_id${NC}"
    if [ "$mode" = "vip" ]; then
        echo -e "🌟 Домен: ${PURPLE}$chosen_domain${NC}"
    fi
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# === ФУНКЦИЯ: ВХОД В СВОЙ ЯЩИК ===
login_mail() {
    echo -e "\n${PURPLE}🔐 ВХОД В VIP-ЯЩИК${NC}"
    read -p "📧 Введи полный адрес (например 777@wshu.net): " email
    read -p "🔑 Введи пароль: " password
    
    token_response=$(curl -s -X POST https://api.mail.tm/token \
        -H "Content-Type: application/json" \
        -d "{\"address\":\"$email\",\"password\":\"$password\"}")
    
    token=$(echo "$token_response" | jq -r '.token')
    acc_id=$(echo "$token_response" | jq -r '.id')
    
    if [ -z "$token" ] || [ "$token" = "null" ]; then
        echo -e "${RED}❌ Неверный адрес или пароль${NC}"
        exit 1
    fi
    
    echo "{\"email\":\"$email\",\"password\":\"$password\",\"id\":\"$acc_id\",\"mode\":\"vip\"}" > "$ACCOUNT_FILE"
    echo "$token" > "$TOKEN_FILE"
    echo "0" > "$LAST_ID_FILE"
    echo "0" > "$EXPIRE_FILE"
    
    echo -e "${PURPLE}👑 Добро пожаловать, VIP!${NC}"
    echo -e "📧 ${GREEN}$email${NC}"
}

# === ПРОВЕРКА ИСТЕЧЕНИЯ ВРЕМЕНИ ===
check_expire() {
    if [ -f "$EXPIRE_FILE" ]; then
        expire_time=$(cat "$EXPIRE_FILE")
        if [ "$expire_time" != "0" ]; then
            current_time=$(date +%s)
            if [ "$current_time" -ge "$expire_time" ]; then
                echo -e "${RED}⏰ Время почты истекло (15 мин)${NC}"
                echo -e "${YELLOW}💡 Используй VIP-пароль для вечной почты${NC}"
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
echo -e "1) ${CYAN}Обычная почта (15 минут)${NC}"
echo -e "2) ${PURPLE}VIP-почта (пароль + выбор домена + свой логин)${NC}"
echo -e "3) ${GREEN}Войти в свой VIP-ящик${NC}"
echo ""
read -p "👉 Выбери режим (1/2/3): " mode_choice

case $mode_choice in
    1)
        # Обычный режим
        if [ -f "$ACCOUNT_FILE" ]; then
            email=$(jq -r '.email' "$ACCOUNT_FILE" 2>/dev/null)
            mode=$(jq -r '.mode' "$ACCOUNT_FILE" 2>/dev/null)
            if [ "$mode" = "normal" ]; then
                check_expire
                echo -e "${CYAN}📬 Использую существующий: $email${NC}"
            else
                create_mail "normal"
                email=$(jq -r '.email' "$ACCOUNT_FILE")
            fi
        else
            create_mail "normal"
            email=$(jq -r '.email' "$ACCOUNT_FILE")
        fi
        ;;
    2)
        # VIP режим с проверкой пароля
        read -sp "🔐 Введи VIP-пароль: " input_pass
        echo ""
        
        if [ "$input_pass" != "$VIP_PASS" ]; then
            echo -e "${RED}❌ Неверный VIP-пароль!${NC}"
            echo -e "${YELLOW}💡 Используй обычный режим (выбор 1)${NC}"
            exit 1
        fi
        
        echo -e "${PURPLE}👑 VIP-ДОСТУП РАЗРЕШЁН!${NC}"
        create_mail "vip"
        email=$(jq -r '.email' "$ACCOUNT_FILE")
        ;;
    3)
        # Вход в существующий VIP
        read -sp "🔐 Введи VIP-пароль: " input_pass
        echo ""
        
        if [ "$input_pass" != "$VIP_PASS" ]; then
            echo -e "${RED}❌ Неверный VIP-пароль!${NC}"
            exit 1
        fi
        
        login_mail
        email=$(jq -r '.email' "$ACCOUNT_FILE")
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
    echo -e "🌟 ${PURPLE}VIP-РЕЖИМ (вечный)${NC}"
fi
echo ""

while true; do
    # Проверка истечения для обычного режима
    if [ "$mode" = "normal" ]; then
        check_expire
    fi
    
    # Проверка писем
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
