#!/bin/bash
set -e

# Используем стандартные переменные Railway для MySQL
export DB_HOST=${MYSQLHOST:-localhost}
export DB_PORT=${MYSQLPORT:-3306}
export DB_DATABASE=${MYSQLDATABASE:-railway}
export DB_USERNAME=${MYSQLUSER:-root}
export DB_PASSWORD=${MYSQLPASSWORD:-}

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