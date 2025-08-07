#!/bin/bash
set -e

# Установка порта по умолчанию
export PORT=${PORT:-80}

# Настройка Nginx порта
echo "Setting Nginx port to $PORT"
sed -i "s/listen .*/listen $PORT;/" /etc/nginx/sites-available/default
# Парсинг DATABASE_URL
if [ -n "$DATABASE_URL" ]; then
  echo "Parsing DATABASE_URL..."
  DB_INFO=$(echo "$DATABASE_URL" | awk -F[:/@] '{print $4,$5,$7,$8,$9}')
  DB_USER=$(echo $DB_INFO | cut -d' ' -f1)
  DB_PASS=$(echo $DB_INFO | cut -d' ' -f2)
  DB_HOST=$(echo $DB_INFO | cut -d' ' -f3)
  DB_PORT=$(echo $DB_INFO | cut -d' ' -f4)
  DB_NAME=$(echo $DB_INFO | cut -d' ' -f5)

  export DB_HOST=$DB_HOST
  export DB_PORT=$DB_PORT
  export DB_DATABASE=$DB_NAME
  export DB_USERNAME=$DB_USER
  export DB_PASSWORD=$DB_PASS
fi

# Отладочный вывод
echo "=== Parsed from DATABASE_URL ==="
echo "DB_HOST: $DB_HOST"
echo "DB_PORT: $DB_PORT"
echo "DB_DATABASE: $DB_DATABASE"
echo "DB_USERNAME: $DB_USERNAME"
echo "DB_PASSWORD: ${DB_PASSWORD:0:2}******"

# Отладочный вывод
echo "=== Railway DB Variables ==="
echo "MYSQLHOST: $MYSQLHOST"
echo "MYSQLPORT: $MYSQLPORT"
echo "MYSQLDATABASE: $MYSQLDATABASE"
echo "MYSQLUSER: $MYSQLUSER"
echo "MYSQLPASSWORD: ${MYSQLPASSWORD:0:2}******"

echo "=== Laravel DB Variables ==="
echo "DB_HOST: $DB_HOST"
echo "DB_PORT: $DB_PORT"
echo "DB_DATABASE: $DB_DATABASE"
echo "DB_USERNAME: $DB_USERNAME"
echo "DB_PASSWORD: ${DB_PASSWORD:0:2}******"

# Функция проверки MySQL
wait_for_db() {
    echo "Waiting for MySQL at $DB_HOST:$DB_PORT..."
    for i in {1..30}; do
        if mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" --silent; then
            echo "MySQL is ready!"
            return 0
        fi
        echo "Attempt $i/30 - waiting 2s..."
        sleep 2
    done
    echo "MySQL connection failed after 30 attempts"
    return 1
}

# Проверка подключения
if [ -n "$MYSQLHOST" ]; then
    wait_for_db
fi

# Настройка Laravel
mkdir -p storage/framework/{sessions,views,cache}
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage

# Миграции
if [ -n "$DB_DATABASE" ]; then
    echo "Running migrations..."
    php artisan migrate --force
fi

# Кеширование
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Запуск сервисов
echo "Starting services..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf