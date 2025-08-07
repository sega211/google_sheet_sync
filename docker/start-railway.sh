#!/bin/bash
set -e

# Установка утилит для диагностики
apt-get update && apt-get install -y jq dnsutils netcat-openbsd iputils-ping

# Установка порта
export PORT=${PORT:-80}
echo "Using port: $PORT"
if [ -f /etc/nginx/sites-available/default ]; then
    sed -i "s/listen .*/listen $PORT;/" /etc/nginx/sites-available/default
else
    echo "Nginx default conf not found at /etc/nginx/sites-available/default"
fi

# =================================================================
# НАЧАЛО КРИТИЧЕСКОЙ СЕКЦИИ - РУЧНЫЕ ПЕРЕМЕННЫЕ ДЛЯ ПОДКЛЮЧЕНИЯ К БД
# =================================================================

echo "===== RAILWAY SERVICE STATUS ====="
echo "Service ID: $RAILWAY_SERVICE_ID"
echo "Environment: $RAILWAY_ENVIRONMENT_NAME"
echo "Project: $RAILWAY_PROJECT_NAME"

echo "===== ENVIRONMENT DIAGNOSTICS ====="
env | grep -E 'DB_|MYSQL' || echo "No DB/MYSQL variables found"

# Проверяем наличие критических переменных
if [[ -z "$DB_HOST" || -z "$DB_USERNAME" || -z "$DB_PASSWORD" ]]; then
    echo ""
    echo "ERROR: Database connection variables are missing!"
    echo "Please set in Railway dashboard:"
    echo "DB_HOST, DB_USERNAME, DB_PASSWORD"
    echo ""
    echo "Current values:"
    echo "DB_HOST: '$DB_HOST'"
    echo "DB_USERNAME: '$DB_USERNAME'"
    echo "DB_PASSWORD: ${DB_PASSWORD:+[present]}"
    echo ""
    echo "===== FULL ENVIRONMENT DUMP ====="
    printenv | sort
    echo "===== RAILWAY SECRETS FILES ====="
    ls -la /etc/railway/secrets
    [ -f "/etc/railway/secrets/mysql.json" ] && cat /etc/railway/secrets/mysql.json
    exit 1
fi

# Установка значений по умолчанию для опциональных переменных
export DB_PORT=${DB_PORT:-3306}
export DB_DATABASE=${DB_DATABASE:-railway}

# Отладочный вывод
echo "=== USING MANUAL DB CONNECTION ==="
echo "Host: $DB_HOST:$DB_PORT"
echo "Database: $DB_DATABASE"
echo "Username: $DB_USERNAME"
echo "Password: ${DB_PASSWORD:0:2}******"

# =================================================================
# КОНЕЦ КРИТИЧЕСКОЙ СЕКЦИИ
# =================================================================

# Диагностика сети
echo "=== NETWORK DIAGNOSTICS ==="
echo "Resolving DB host '$DB_HOST':"
nslookup "$DB_HOST" || echo "DNS lookup failed"

echo "Pinging DB host:"
ping -c 2 "$DB_HOST" || echo "Ping failed"

echo "Testing DB port $DB_PORT:"
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