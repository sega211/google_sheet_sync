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

# Проверка наличия переменных
if [ -z "$MYSQLHOST" ] || [ -z "$MYSQLPORT" ] || [ -z "$MYSQLUSER" ] || [ -z "$MYSQLPASSWORD" ]; then
  echo "ERROR: MySQL variables not set!"
  echo "MYSQLHOST: $MYSQLHOST"
  echo "MYSQLPORT: $MYSQLPORT"
  echo "MYSQLUSER: $MYSQLUSER"
  echo "MYSQLPASSWORD: ${MYSQLPASSWORD:0:2}******"
  exit 1
fi

export DB_HOST=$MYSQLHOST
export DB_PORT=$MYSQLPORT
export DB_DATABASE=$MYSQLDATABASE
export DB_USERNAME=$MYSQLUSER
export DB_PASSWORD=$MYSQLPASSWORD

# Отладочный вывод
echo "=== RAILWAY DB VARIABLES ==="
echo "MYSQLHOST: $MYSQLHOST"
echo "MYSQLPORT: $MYSQLPORT"
echo "MYSQLDATABASE: $MYSQLDATABASE"
echo "MYSQLUSER: $MYSQLUSER"
echo "MYSQLPASSWORD: ${MYSQLPASSWORD:0:2}******"

echo "=== NETWORK DIAGNOSTICS ==="
echo "Pinging host:"
ping -c 4 $MYSQLHOST
echo "Testing port with telnet:"
timeout 5 telnet $MYSQLHOST $MYSQLPORT || echo "Telnet failed"

# Настройка Laravel
mkdir -p storage/framework/{sessions,views,cache}
chown -R www-data:www-data storage bootstrap/cache public
chmod -R 775 storage

# Проверка подключения и миграции
echo "Waiting for MySQL..."
for i in {1..30}; do
  if mysqladmin ping -h"$MYSQLHOST" -P"$MYSQLPORT" -u"$MYSQLUSER" -p"$MYSQLPASSWORD" --silent; then
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