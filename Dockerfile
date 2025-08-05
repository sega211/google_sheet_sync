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
    nginx

# Установка PHP расширений
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip

# Установка Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Установка Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Настройка Nginx
RUN rm /etc/nginx/sites-enabled/default
COPY docker/nginx/app.conf /etc/nginx/sites-available/laravel
RUN ln -s /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/laravel
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

# Рабочая директория
WORKDIR /var/www

# Копируем только необходимые для установки зависимости файлы
COPY composer.json composer.lock package.json package-lock.json ./

# Установка зависимостей PHP
RUN composer install --optimize-autoloader --no-dev --no-scripts

# Установка зависимостей Node.js
RUN npm install

# Копируем остальные файлы проекта
COPY . .

# Установка прав доступа
RUN mkdir -p /var/www/storage/framework/sessions \
             /var/www/storage/framework/views \
             /var/www/storage/framework/cache \
             /var/www/storage/logs

RUN chown -R www-data:www-data /var/www/storage
RUN chmod -R 775 /var/www/storage

# Сборка фронтенда
RUN npm run production

# Запуск cron
RUN touch /var/log/cron.log
RUN (crontab -l ; echo "* * * * * cd /var/www && php artisan schedule:run >> /var/log/cron.log 2>&1") | crontab -

# Entrypoint скрипт
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Стартовая команда
CMD ["start-server"]