#!/bin/bash
set -e

# Установка порта
export PORT=${PORT:-80}
echo "Using port: $PORT"
# Проверяем, существует ли файл, прежде чем его редактировать
if [ -f /etc/nginx/sites-available/default ]; then
    sed -i "s/listen .*/listen $PORT;/" /etc/nginx/sites-available/default
else
    echo "Nginx default conf not found at /etc/nginx/sites-available/default"
fi

# Автоматическое определение переменных БД из стандартных имен Railway
# Railway предоставляет DATABASE_HOST, DATABASE_PORT, DATABASE_NAME, DATABASE_USERNAME, DATABASE_PASSWORD
export DB_HOST=${DATABASE_HOST:-$DB_HOST}
export DB_PORT=${DATABASE_PORT:-3306}
export DB_DATABASE=${DATABASE_NAME:-$DB_DATABASE}
export DB_USERNAME=${DATABASE_USERNAME:-$DB_USERNAME}
export DB_PASSWORD=${DATABASE_PASSWORD:-$DB_PASSWORD}

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
if [ -n "$DB_HOST" ] && [ -n "$DB_USERNAME" ] && [ -n "$DB_PASSWORD" ] && [ -n "$DB_DATABASE" ]; then
  echo "Waiting for MySQL..."
  # Добавление проверки на доступность порта, так как ping может не сработать, если сервис еще не поднялся
  for i in {1..30}; do
    if nc -z "$DB_HOST" "$DB_PORT"; then
      echo "MySQL is reachable on $DB_HOST:$DB_PORT."
      # Попробуем выполнить ping, чтобы убедиться, что сервер MySQL отвечает
      if mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" --silent; then
        echo "MySQL ready!"

        # Миграции и сидинг
        echo "Running migrations..."
        php artisan migrate --force

        echo "Seeding database..."
        php artisan db:seed --force

        break
      else
        echo "Attempt $i/30 - MySQL server not responding to ping, waiting 2s..."
        sleep 2
      fi
    else
      echo "Attempt $i/30 - MySQL server not reachable on $DB_HOST:$DB_PORT, waiting 2s..."
      sleep 2
    fi
  done
  # Проверка, удалось ли подключиться после всех попыток
  if ! mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" --silent; then
      echo "Failed to connect to MySQL after multiple attempts."
      # Здесь можно решить, продолжать ли работу или завершить скрипт
      # exit 1 # Закомментировано, чтобы сервис не останавливался, если подключение к БД не критично для старта
  fi
else
  echo "Skipping DB operations because DB connection details are not fully provided."
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