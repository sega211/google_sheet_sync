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
    sudo \
    default-mysql-client \
    libmagickwand-dev \
    supervisor

# Установка PHP расширений
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip
RUN pecl install imagick && docker-php-ext-enable imagick

# Установка Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Установка Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Рабочая директория
WORKDIR /var/www

# Копируем только необходимые для установки зависимости файлы
COPY composer.* package*.json ./

# Установка зависимостей PHP
RUN composer install --optimize-autoloader --no-dev --no-scripts

# Установка зависимостей Node.js
RUN npm install

# Копируем остальные файлы проекта
COPY . .

# Создаем директории для хранения и устанавливаем права
RUN mkdir -p /var/www/storage/framework/sessions \
             /var/www/storage/framework/views \
             /var/www/storage/framework/cache \
             /var/www/storage/logs \
    && chown -R www-data:www-data /var/www/storage \
    && chmod -R 775 /var/www/storage

# Сборка фронтенда
RUN npm run production

# Копируем конфигурацию супервизора
RUN mkdir -p /etc/supervisor/conf.d
COPY docker/supervisor.conf /etc/supervisor/conf.d/supervisor.conf

# Entrypoint скрипт
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Очистка кэша
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Стартовая команда
CMD ["start-server"]

# Копируем только необходимые для установки зависимости файлы
COPY composer.* package*.json ./

# Установка зависимостей PHP
RUN composer install --optimize-autoloader --no-dev --no-scripts

# Установка зависимостей Node.js
RUN npm install

# Копируем остальные файлы проекта
COPY . .

# Создаем директории для хранения и устанавливаем права
RUN mkdir -p /var/www/storage/framework/{sessions,views,cache} \
    && chown -R www-data:www-data /var/www/storage \
    && chmod -R 775 /var/www/storage

# Сборка фронтенда
RUN npm run production

# Копируем конфигурацию супервизора
COPY docker/supervisor.conf /etc/supervisor/conf.d/supervisor.conf

# Entrypoint скрипт
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Очистка кэша
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Стартовая команда
CMD ["start-server"]