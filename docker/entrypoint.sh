#!/bin/bash
set -e

# Функция ожидания готовности MySQL
wait_for_db() {
    local host="$1"
    local port="$2"
    local user="$3"
    local password="$4"
    local timeout=60
    local start_time=$(date +%s)

    echo "Ожидание готовности MySQL ($host:$port)..."

    while true; do
        if mysqladmin ping -h"$host" -P"$port" -u"$user" -p"$password" --silent; then
            echo "MySQL готов к работе!"
            return 0
        fi
        
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        
        if [ $elapsed_time -ge $timeout ]; then
            echo "Ошибка: MySQL не доступен после $timeout секунд ожидания"
            return 1
        fi
        
        echo "Попытка подключения... ($elapsed_time/$timeout сек)"
        sleep 2
    done
}

# Установка прав для storage
mkdir -p /var/www/storage/framework/{sessions,views,cache}
chown -R www-data:www-data /var/www/storage
chmod -R 775 /var/www/storage

# Ожидание готовности БД
if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ] && [ -n "$DB_USERNAME" ] && [ -n "$DB_PASSWORD" ]; then
    wait_for_db "$DB_HOST" "$DB_PORT" "$DB_USERNAME" "$DB_PASSWORD"
else
    echo "Переменные DB_HOST, DB_PORT, DB_USERNAME или DB_PASSWORD не установлены, пропускаем ожидание БД"
fi

# Выполнение миграций
echo "Выполнение миграций..."
php artisan migrate --force

echo "Очистка кеша Laravel..."
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

# Запуск в зависимости от команды
cmd="$1"
shift

case "$cmd" in
    start-server)
        echo "Запуск PHP-FPM и планировщика..."
        /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisor.conf
        ;;
    *)
        echo "Запуск команды: $cmd"
        exec "$cmd" "$@"
        ;;
esac