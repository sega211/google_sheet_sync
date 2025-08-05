#!/bin/bash

# Запуск cron в фоне
cron

# Создаем файл Google Service Account из переменной окружения
if [ -n "$GOOGLE_CREDENTIALS_BASE64" ]; then
    echo "Decoding Google credentials..."
    echo "$GOOGLE_CREDENTIALS_BASE64" | base64 -d > storage/app/google-service-account.json
    chmod 644 storage/app/google-service-account.json
fi

# Выполняем миграции только при первом запуске
if [ ! -f "/var/www/.migrated" ]; then
    echo "Running migrations..."
    php artisan migrate --force
    touch /var/www/.migrated
fi

# Кеширование Laravel (ДЕЛАЕМ ЗДЕСЬ, а не в Dockerfile!)
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Запуск сервера
if [ "$1" = "start-server" ]; then
    echo "Starting PHP-FPM & Nginx..."
    php-fpm &
    service nginx start
    tail -f /var/log/nginx/error.log
fi

exec "$@"