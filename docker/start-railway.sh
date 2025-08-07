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

# Автоматическое определение переменных БД из СТАНДАРТНЫХ имен Railway
# !!! ВАЖНО: Замените 'MYSQL_DB_' на префикс, который Railway генерирует для вашего сервиса БД !!!
# Вам нужно будет проверить точные имена переменных в настройках вашего сервиса приложения.
# Предположим, ваш сервис базы данных называется 'mysql-db'. Тогда переменные могут быть:
# MYSQL_DB_HOST, MYSQL_DB_PORT, MYSQL_DB_DATABASE, MYSQL_DB_USERNAME, MYSQL_DB_PASSWORD

export DB_HOST=${MYSQLHOST:-$DB_HOST}
export DB_PORT=${MYSQLPORT:-3306} # Railway обычно предоставляет порт, если он отличается от стандартного
export DB_DATABASE=${MYSQLDATABASE:-$DB_DATABASE}
export DB_USERNAME=${MYSQLUSERNAME:-$DB_USERNAME}
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
if [ -n "$DB_HOST" ] && [ -n "$DB_USERNAME" ] && [ -n "$DB_PASSWORD" ] && [ -n "$DB_DATABASE" ]; then
  echo "Waiting for MySQL..."
  for i in {1..30}; do
    if nc -z "$DB_HOST" "$DB_PORT"; then
      echo "MySQL is reachable on $DB_HOST:$DB_PORT."
      if mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" --silent; then
        echo "MySQL ready!"
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
  if ! mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" --silent; then
      echo "Failed to connect to MySQL after multiple attempts."
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