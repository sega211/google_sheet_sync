#!/bin/bash
set -e

# Установка утилит для диагностики
apt-get update && apt-get install -y jq dnsutils netcat-openbsd

# Установка порта
export PORT=${PORT:-80}
echo "Using port: $PORT"
if [ -f /etc/nginx/sites-available/default ]; then
    sed -i "s/listen .*/listen $PORT;/" /etc/nginx/sites-available/default
else
    echo "Nginx default conf not found at /etc/nginx/sites-available/default"
fi

# Расширенная диагностика переменных
echo "===== ENVIRONMENT DIAGNOSTICS ====="
echo "DATABASE_URL: ${DATABASE_URL:-[not set]}"
echo "MYSQLHOST: ${MYSQLHOST:-[not set]}"
echo "MYSQLUSER: ${MYSQLUSER:-[not set]}"
echo "MYSQLPASSWORD: ${MYSQLPASSWORD:+[present]}"
env | grep -E 'DB_|MYSQL' || echo "No DB/MYSQL variables found"
echo "=================================="

# Функция для парсинга DATABASE_URL
parse_database_url() {
    if [ -n "$DATABASE_URL" ]; then
        echo "Parsing DATABASE_URL: ${DATABASE_URL//:[^@]*@/:******@}"
        
        # Удаляем префикс mysql://
        local url="${DATABASE_URL#mysql://}"
        
        # Извлекаем логин:пароль@хост:порт/база
        local userpass="${url%%@*}"
        export DB_USERNAME="${userpass%%:*}"
        export DB_PASSWORD="${userpass#*:}"
        
        local hostportpath="${url#*@}"
        export DB_HOST="${hostportpath%%:*}"
        
        local portpath="${hostportpath#*:}"
        export DB_PORT="${portpath%%/*}"
        export DB_DATABASE="${portpath#*/}"
        
        # Удаляем параметры запроса если есть
        export DB_DATABASE="${DB_DATABASE%%\?*}"
        
        return 0
    fi
    return 1
}

# Попытка 1: Использование DATABASE_URL
if parse_database_url; then
    echo "Using DATABASE_URL for DB connection"

# Попытка 2: Стандартные переменные Railway
elif [ -n "$MYSQLHOST" ] && [ -n "$MYSQLUSER" ] && [ -n "$MYSQLPASSWORD" ]; then
    echo "Using Railway standard variables"
    export DB_HOST=$MYSQLHOST
    export DB_PORT=$MYSQLPORT
    export DB_DATABASE=$MYSQLDATABASE
    export DB_USERNAME=$MYSQLUSER
    export DB_PASSWORD=$MYSQLPASSWORD

# Попытка 3: Ручные переменные через шаблоны
elif [ -n "$DB_HOST" ] && [ -n "$DB_USERNAME" ] && [ -n "$DB_PASSWORD" ]; then
    echo "Using manual DB_* variables"
    # Уже установлены

# Все попытки провалились
else
    echo "ERROR: Could not determine database connection details!"
    echo "Please ensure:"
    echo "1. MySQL service is linked to this application"
    echo "2. DATABASE_URL variable is set to: \${{ MySQL-usZd.MYSQL_URL }}"
    echo "3. Or set DB_HOST, DB_USERNAME, DB_PASSWORD manually"
    
    # Расширенная диагностика
    echo "===== FULL ENVIRONMENT DUMP ====="
    printenv | sort
    echo "===== RAILWAY SECRETS ====="
    ls -la /etc/railway/secrets || echo "No secrets directory"
    
    exit 1
fi

# Установка значений по умолчанию
export DB_PORT=${DB_PORT:-3306}
export DB_DATABASE=${DB_DATABASE:-railway}

# Отладочный вывод (без пароля)
echo "=== DB CONNECTION DETAILS ==="
echo "Host: $DB_HOST:$DB_PORT"
echo "Database: $DB_DATABASE"
echo "Username: $DB_USERNAME"
echo "Password: ${DB_PASSWORD:0:2}******"

# Диагностика сети
echo "=== NETWORK DIAGNOSTICS ==="
echo "Resolving DB host:"
nslookup $DB_HOST || echo "DNS lookup failed"
echo "Testing DB port:"
timeout 5 bash -c "cat < /dev/null > /dev/tcp/$DB_HOST/$DB_PORT" && \
    echo "Port test successful" || echo "Port test failed"

# Настройка Laravel
mkdir -p storage/framework/{sessions,views,cache}
chown -R www-data:www-data storage bootstrap/cache public
chmod -R 775 storage

# Проверка подключения к MySQL
echo "Waiting for MySQL connection..."
for i in {1..30}; do
    if mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" --silent; then
        echo "MySQL is ready!"
        
        # Проверка существования базы данных
        if ! mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" -e "USE $DB_DATABASE" 2>/dev/null; then
            echo "Creating database $DB_DATABASE..."
            mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" -e "CREATE DATABASE $DB_DATABASE"
        fi
        
        echo "Running migrations..."
        php artisan migrate --force
        
        break
    else
        echo "Attempt $i/30: MySQL not ready, waiting 2s..."
        sleep 2
    fi
done

# Кеширование
echo "Caching configuration..."
php artisan config:cache
echo "Caching routes..."
php artisan route:cache
echo "Caching views..."
php artisan view:cache

# Запуск сервисов
echo "Starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf