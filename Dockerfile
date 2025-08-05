FROM php:8.3-fpm

# Установка зависимостей
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    unzip \
    cron \
    nginx  # Добавляем Nginx!

# Установка PHP расширений
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip

# Настройка Nginx + PHP-FPM
RUN rm /etc/nginx/sites-enabled/default
COPY docker/nginx.conf /etc/nginx/sites-available/laravel
RUN ln -s /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/laravel

# Установка Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Установка Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Рабочая директория
WORKDIR /var/www

# Копируем ВСЕ файлы проекта
COPY . .

# Установка прав доступа
RUN mkdir -p /var/www/storage/framework/sessions \
             /var/www/storage/framework/views \
             /var/www/storage/framework/cache \
             /var/www/storage/logs

RUN chown -R www-data:www-data /var/www/storage
RUN chmod -R 775 /var/www/storage

# Установка зависимостей PHP
RUN composer install --optimize-autoloader --no-dev

# Установка зависимостей Node.js и сборка фронтенда
RUN npm install && npm run production

# Запуск cron
RUN touch /var/log/cron.log
RUN (crontab -l ; echo "* * * * * cd /var/www && php artisan schedule:run >> /var/log/cron.log 2>&1") | crontab -

# Кеширование (перенесено в entrypoint)
# !!! Убрали отсюда php artisan config:cache !!!

# Entrypoint скрипт
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Стартовая команда
CMD ["start-server"]