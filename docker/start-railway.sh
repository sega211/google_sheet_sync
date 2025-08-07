#!/bin/bash
set -e

# Установка порта
export PORT=${PORT:-80}
echo "Using port: $PORT"
if [ -f /etc/nginx/sites-available/default ]; then
    sed -i "s/listen .*/listen $PORT;/" /etc/nginx/sites-available/default
else
    echo "Nginx default conf not found at /etc/nginx/sites-available/default"
fi

# Используем переменные для Laravel
export DB_HOST=${DB_HOST:-}
export DB_PORT=${DB_PORT:-3306}
export DB_DATABASE=${DB_DATABASE:-}
export DB_USERNAME=${DB_USERNAME:-}
export DB_PASSWORD=${DB_PASSWORD:-}

# Отладочный вывод
echo "=== LARAVEL DB VARIABLES ==="
echo "DB_HOST: $DB_HOST"
echo "DB_PORT: $DB_PORT"
echo "DB_DATABASE: $DB_DATABASE"
echo "DB_USERNAME: $DB_USERNAME"
echo "DB_PASSWORD: ${DB_PASSWORD:0:2}******"

# Проверка наличия переменных
if [ -z "$DB_HOST" ] || [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ]; then
  echo "ERROR: Database variables not set! Please check Railway service connections."
  echo "Make sure you have:"
  echo "- Linked MySQL service to your application"
  echo "- Set variables with correct syntax: \${{ MySQL-usZd.MYSQLHOST }} etc."
  exit 1
fi

# Настройка Laravel
mkdir -p storage/framework/{sessions,views,cache}
chown -R www-data:www-data storage bootstrap/cache public
chmod -R 775 storage

# Проверка подключения и миграции
echo "Waiting for MySQL connection at $DB_HOST:$DB_PORT..."
for i in {1..30}; do
  if mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" --silent; then
    echo "MySQL ready!"
    
    echo "Running migrations..."
    php artisan migrate --force
    
    break
  else
    echo "Attempt $i/30 - waiting 2s..."
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