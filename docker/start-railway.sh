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

# Функция для получения секретов из Railway Secrets
get_railway_secrets() {
    if [ -f "/etc/railway/secrets/mysql.json" ]; then
        echo "Reading MySQL credentials from Railway Secrets"
        export DB_HOST=$(jq -r '.host' /etc/railway/secrets/mysql.json)
        export DB_PORT=$(jq -r '.port' /etc/railway/secrets/mysql.json)
        export DB_DATABASE=$(jq -r '.database' /etc/railway/secrets/mysql.json)
        export DB_USERNAME=$(jq -r '.user' /etc/railway/secrets/mysql.json)
        export DB_PASSWORD=$(jq -r '.password' /etc/railway/secrets/mysql.json)
        return 0
    fi
    return 1
}

# Функция для парсинга DATABASE_URL
parse_database_url() {
    if [ -n "$DATABASE_URL" ]; then
        echo "Parsing DATABASE_URL"
        DB_INFO=$(echo "$DATABASE_URL" | awk -F[:/@] '{print $4,$5,$7,$8,$9}')
        export DB_USERNAME=$(echo $DB_INFO | cut -d' ' -f1)
        export DB_PASSWORD=$(echo $DB_INFO | cut -d' ' -f2)
        export DB_HOST=$(echo $DB_INFO | cut -d' ' -f3)
        export DB_PORT=$(echo $DB_INFO | cut -d' ' -f4)
        export DB_DATABASE=$(echo $DB_INFO | cut -d' ' -f5)
        return 0
    fi
    return 1
}

# Попытка 1: Использование стандартных переменных Railway
if [ -n "$MYSQLHOST" ] && [ -n "$MYSQLUSER" ] && [ -n "$MYSQLPASSWORD" ]; then
    echo "Using Railway standard variables"
    export DB_HOST=$MYSQLHOST
    export DB_PORT=$MYSQLPORT
    export DB_DATABASE=$MYSQLDATABASE
    export DB_USERNAME=$MYSQLUSER
    export DB_PASSWORD=$MYSQLPASSWORD

# Попытка 2: Использование переменных DB_*
elif [ -n "$DB_HOST" ] && [ -n "$DB_USERNAME" ] && [ -n "$DB_PASSWORD" ]; then
    echo "Using DB_* variables"
    # Уже установлены, ничего не делаем

# Попытка 3: Railway Secrets
elif get_railway_secrets; then
    echo "Using Railway Secrets"

# Попытка 4: Парсинг DATABASE_URL
elif parse_database_url; then
    echo "Using DATABASE_URL"

# Попытка 5: Прямые значения из Railway UI (Connect tab)
elif [ -n "$RAILWAY_DB_HOST" ]; then
    echo "Using direct connection parameters"
    export DB_HOST=$RAILWAY_DB_HOST
    export DB_PORT=$RAILWAY_DB_PORT
    export DB_DATABASE=$RAILWAY_DB_DATABASE
    export DB_USERNAME=$RAILWAY_DB_USERNAME
    export DB_PASSWORD=$RAILWAY_DB_PASSWORD

# Все попытки провалились
else
    echo "ERROR: Could not determine database connection details!"
    echo "Please ensure your MySQL service is linked to this application."
    echo "Alternatively, set DB_HOST, DB_USERNAME, DB_PASSWORD environment variables."
    
    # Диагностика
    echo "=== ENVIRONMENT DIAGNOSTICS ==="
    echo "MYSQL* variables:"
    printenv | grep MYSQL || echo "None"
    echo "DB_* variables:"
    printenv | grep '^DB_' || echo "None"
    echo "DATABASE_URL: $DATABASE_URL"
    echo "Railway Secrets:"
    ls -la /etc/railway/secrets || echo "No secrets directory"
    
    exit 1
fi

# Установка значений по умолчанию
export DB_PORT=${DB_PORT:-3306}
export DB_DATABASE=${DB_DATABASE:-railway}

# Отладочный вывод
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
nc -zv -w 5 $DB_HOST $DB_PORT || echo "Port test failed"

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