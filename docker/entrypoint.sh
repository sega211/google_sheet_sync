#!/bin/bash

# Запуск cron в фоне
cron

# Создаем файл Google Service Account из переменной окружения
if [ -n "$GOOGLE_CREDENTIALS_BASE64" ]; then
    echo "Создание файла Google Service Account..."
    mkdir -p storage/app
    echo "$GOOGLE_CREDENTIALS_BASE64" | base64 -d > storage/app/google-service-account.json
    chmod 644 storage/app/google-service-account.json
fi

# Выполняем миграции только при первом запуске
if [ ! -f "/var/www/.migrated" ]; then
    echo "Выполнение миграций..."
    php artisan migrate --force
    touch /var/www/.migrated
fi

# Кеширование Laravel
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Запуск сервера
if [ "$1" = "start-server" ]; then
    echo "Запуск PHP-FPM и Nginx..."
    
    # Запуск PHP-FPM в фоне
    php-fpm &
    
    # Запуск Nginx на переднем плане
    nginx -g "daemon off;"
    
    # Мониторинг логов
    tail -f /var/log/nginx/error.log /var/log/cron.log
fi

exec "$@"