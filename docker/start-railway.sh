#!/bin/bash
set -e

# Установка порта
export PORT=${PORT:-$RAILWAY_STATIC_PORT}
if [ -z "$PORT" ]; then
  export PORT=${RAILWAY_PORT:-80}
fi
echo "Using port: $PORT"

# Настройка Nginx
sed -i "s/listen .*/listen $PORT default_server reuseport;/" /etc/nginx/sites-available/default

# Автоматическое определение переменных БД
if [ -z "$DB_HOST" ]; then
  if [ -n "$MYSQLHOST" ]; then
    export DB_HOST=$MYSQLHOST
    export DB_PORT=$MYSQLPORT
    export DB_DATABASE=$MYSQLDATABASE
    export DB_USERNAME=$MYSQLUSER
    export DB_PASSWORD=$MYSQLPASSWORD
  elif [ -n "$DATABASE_URL" ]; then
    echo "Parsing DATABASE_URL..."
    DB_INFO=$(echo "$DATABASE_URL" | awk -F[:/@] '{print $4,$5,$7,$8,$9}')
    export DB_USERNAME=$(echo $DB_INFO | cut -d' ' -f1)
    export DB_PASSWORD=$(echo $DB_INFO | cut -d' ' -f2)
    export DB_HOST=$(echo $DB_INFO | cut -d' ' -f3)
    export DB_PORT=$(echo $DB_INFO | cut -d' ' -f4)
    export DB_DATABASE=$(echo $DB_INFO | cut -d' ' -f5)
  fi
fi

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

# Миграции (если есть данные для подключения)
if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ] && [ -n "$DB_USERNAME" ]; then
  echo "Waiting for MySQL..."
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
else
  echo "Skipping DB checks"
fi

# Кеширование
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Проверка конфигурации
nginx -t
php-fpm -t

# Запуск сервисов
echo "Starting services..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf