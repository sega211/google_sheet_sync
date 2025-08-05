# Laravel Google Sheet Sync

Проект демонстрирует синхронизацию данных между базой данных Laravel и Google Sheets, включая обработку комментариев.

## Особенности
- Синхронизация моделей Laravel с Google Таблицей
- Сохранение комментариев пользователя при обновлении данных
- Консольные команды для синхронизации и вывода комментариев
- Веб-интерфейс для управления продуктами и синхронизацией
- Автоматическое обновление данных по расписанию

## Установка

1. Клонируйте репозиторий:
   ```bash
   git clone https://github.com/sega211/google_sheet_sync.git
   cd google_sheets_sync

2. Установите зависимости

    ```bash
    composer install

3. Создайте файл окружения
    ```bash
    cp .env.example .env
    php artisan key:generate

4. Настройте базу данных в .env:
    ```env
    DB_CONNECTION=mysql
    DB_HOST=127.0.0.1
    DB_PORT=3306
    DB_DATABASE=your_database
    DB_USERNAME=your_username
    DB_PASSWORD=your_password

5. Выполните миграции:
    ```bash
    php artisan migrate

6. Настройте Google Sheets API:
    - Создайте сервисный аккаунт в Google Cloud Console
    - Скачайте JSON-ключ и поместите в storage/app/google-service-account.json 
    - В .env добавьте:
        ```env
        GOOGLE_SERVICE_ACCOUNT_JSON=google-service-account.json
        GOOGLE_SPREADSHEET_ID=your_spreadsheet_id
        
7. Предоставьте доступ сервисному аккаунту к Google Таблице:
    - Создайте таблицу с полями: "ID", "Name", "Price", "Status", "Created At", "Updared At", "Comments"
    - Откройте настройки доступа таблицы
    - Добавьте email сервисного аккаунта с правами "Редактор"

## Использование
### Веб-интерфейс
Главная страница: /products

Генерация демо-данных (1000 продуктов): POST /products/generate

Очистка всех данных: POST /products/clear

Синхронизация с Google Sheets: POST /products/sync

Просмотр комментариев: /fetch или /fetch/{count}

### Консольные комманды
    
    - Синхронизация данных

    ```bash
    php artisan sync:google-sheets

    - Просмотр комментариев

    ```bash
    php artisan fetch:comments
    php artisan fetch:comments --count=5
    ```

### Планировщик задач

Синхронизация запускается автоматически каждую минуту. Для настройки cron на сервере добавьте:

    ```bash
    * * * * * cd /path-to-your-project && php artisan schedule:run >> /dev/null 2>&1 
    ```


## Docker
Для запуска в Docker:
    
    ```bash
    docker-compose up -d --build
    docker-compose exec app php artisan migrate

Откройте в браузере: http://localhost:8000

PhpMyAdmin доступен по адресу:
http://localhost:8080
(логин: root, пароль: secret)
