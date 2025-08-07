#!/bin/bash
set -e

# Установка порта
export PORT=${PORT:-$RAILWAY_STATIC_PORT}
if [ -z "$PORT" ]; then
  export PORT=80
fi

# Настройка Nginx порта
echo "Setting Nginx port to $PORT"
sed -i "s/listen .*/listen $PORT default_server reuseport;/" /etc/nginx/sites-available/default

# Проверка всех переменных окружения
echo "=== Все переменные окружения ==="
printenv | grep -v -E 'PASSWORD|TOKEN|KEY|SECRET' # Не выводим секреты

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

# Отладочный вывод переменных БД
echo "=== Переменные БД ==="
echo "DB_HOST: $DB_HOST"
echo "DB_PORT: $DB_PORT"
echo "DB_DATABASE: $DB_DATABASE"
echo "DB_USERNAME: $DB_USERNAME"
echo "DB_PASSWORD: ${DB_PASSWORD:0:2}******"

# Настройка Laravel
mkdir -p storage/framework/{sessions,views,cache}
chown -R www-data:www-data storage bootstrap/cache public
chmod -R 775 storage

# Проверка подключения к БД
if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ]; then
  echo "Ожидание готовности MySQL..."
  for i in {1..30}; do
    if mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" --silent; then
      echo "MySQL готов!"
      echo "Выполнение миграций..."
      php artisan migrate --force
      break
    else
      echo "Попытка $i/30 - MySQL не готов, ожидание..."
      sleep 2
    fi
  done
else
  echo "Пропуск проверки MySQL: не указаны хост или порт"
fi

# Кеширование
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Проверка конфигураций
echo "Тестирование конфигурации PHP-FPM..."
php-fpm -t
echo "Тестирование конфигурации Nginx..."
nginx -t

# Проверка работы служб
echo "Проверка работы PHP-FPM..."
SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 || echo "PHP-FPM не отвечает"

echo "Проверка работы Nginx..."
timeout 5 bash -c 'until curl -sI http://localhost:$PORT; do sleep 1; done' || echo "Nginx не отвечает"

# Запуск сервисов
echo "Запуск супервизора..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf