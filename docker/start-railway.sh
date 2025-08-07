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

# Используем СТАНДАРТНЫЕ переменные Railway для MySQL
# Railway автоматически создает эти переменные при связывании сервисов
export DB_HOST=$MYSQLHOST
export DB_PORT=$MYSQLPORT
export DB_DATABASE=$MYSQLDATABASE
export DB_USERNAME=$MYSQLUSER
export DB_PASSWORD=$MYSQLPASSWORD

# Отладочный вывод переменных
echo "=== RAILWAY DB VARIABLES ==="
echo "MYSQLHOST: $MYSQLHOST"
echo "MYSQLPORT: $MYSQLPORT"
echo "MYSQLDATABASE: $MYSQLDATABASE"
echo "MYSQLUSER: $MYSQLUSER"
echo "MYSQLPASSWORD: ${MYSQLPASSWORD:0:2}******"

echo "=== LARAVEL DB VARIABLES ==="
echo "DB_HOST: $DB_HOST"
echo "DB_PORT: $DB_PORT"
echo "DB_DATABASE: $DB_DATABASE"
echo "DB_USERNAME: $DB_USERNAME"
echo "DB_PASSWORD: ${DB_PASSWORD:0:2}******"

# Настройка Laravel
mkdir -p storage/framework/{sessions,views,cache}
chown -R www-data:www-data storage bootstrap/cache public
chmod -R 775 storage

# Проверка подключения и миграции
if [ -n "$MYSQLHOST" ] && [ -n "$MYSQLPORT" ] && [ -n "$MYSQLUSER" ] && [ -n "$MYSQLPASSWORD" ]; then
  echo "Waiting for MySQL..."
  for i in {1..30}; do
    if mysqladmin ping -h"$MYSQLHOST" -P"$MYSQLPORT" -u"$MYSQLUSER" -p"$MYSQLPASSWORD" --silent; then
      echo "MySQL ready!"
      
      echo "Running migrations..."
      php artisan migrate --force
      
      # Если нужны начальные данные
      # echo "Seeding database..."
      # php artisan db:seed --force
      
      break
    else
      echo "Attempt $i/30 - waiting 2s..."
      sleep 2
    fi
  done
else
  echo "Skipping DB operations: MySQL variables not set"
fi

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