#!/bin/bash
set -e

# Установка порта
export PORT=${PORT:-80}
echo "Using port: $PORT"
sed -i "s/listen .*/listen $PORT;/" /etc/nginx/sites-available/default

# Автоматическое определение переменных БД
export DB_HOST=${MYSQLHOST:-$DB_HOST}
export DB_PORT=${MYSQLPORT:-3306}
export DB_DATABASE=${MYSQLDATABASE:-$DB_DATABASE}
export DB_USERNAME=${MYSQLUSER:-$DB_USERNAME}
export DB_PASSWORD=${MYSQLPASSWORD:-$DB_PASSWORD}

# Отладочный вывод
echo "=== DB Variables ==="
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
if [ -n "$DB_HOST" ]; then
  echo "Waiting for MySQL..."
  for i in {1..30}; do
    if mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" --silent; then
      echo "MySQL ready!"
      
      # Миграции и сидинг
      echo "Running migrations..."
      php artisan migrate --force
      
      echo "Seeding database..."
      php artisan db:seed --force
      
      break
    else
      echo "Attempt $i/30 - waiting 2s..."
      sleep 2
    fi
  done
else
  echo "Skipping DB operations"
fi

# Кеширование
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Запуск сервисов
echo "Starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf