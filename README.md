```markdown
# Laravel Google Sheet Sync

**Особенности** | **Требования** | **Установка** | **Использование** | **Тестирование** | **Лицензия**

---

Проект демонстрирует синхронизацию данных между базой данных Laravel и Google Sheets, включая обработку комментариев.
## Особенности
- Синхронизация моделей Laravel с Google Таблицей
- Сохранение комментариев пользователя при обновлении данных
- Консольные команды для синхронизации и вывода комментариев
- Веб-интерфейс для управления продуктами и синхронизацией
- Автоматическое обновление данных по расписанию (каждую минуту)
- Поддержка нескольких таблиц через настройку URL

## Требования
- PHP >= 8.1
- Composer
- Node.js & NPM
- MySQL (или другая БД, поддерживаемая Laravel)
- Docker и Docker Compose (для Docker-установки)

## Установка
### Без Docker
1. Клонируйте репозиторий:

   ```bash
   git clone https://github.com/sega211/google_sheet_sync.git
   cd google_sheets_sync
   ```
2. Установите зависимости:
   ```bash
   composer install
   npm install
   npm run build
   ```
3. Создайте файл окружения:
   ```bash
   cp .env.example .env
   php artisan key:generate
   ```
4. Настройте базу данных в .env:
   ```env
   DB_CONNECTION=mysql
   DB_HOST=127.0.0.1
   DB_PORT=3306
   DB_DATABASE=your_database
   DB_USERNAME=your_username
   DB_PASSWORD=your_password
   ```
5. Выполните миграции:
   ```bash
   php artisan migrate
   ```
6. Настройте Google Sheets API:
   - Создайте сервисный аккаунт в Google Cloud Console
   - Скачайте JSON-ключ и поместите в `storage/app/google-service-account.json`
   - В .env добавьте:
        ```env
        GOOGLE_SERVICE_ACCOUNT_JSON=google-service-account.json
        GOOGLE_SPREADSHEET_ID=your_default_spreadsheet_id
        ```
   - Предоставьте доступ сервисному аккаунту к Google Таблице:
        - Откройте настройки доступа таблицы
        - Добавьте email сервисного аккаунта с правами "Редактор"
### С Docker
1. Склонируйте репозиторий и перейдите в директорию проекта:
   ```bash
   git clone https://github.com/sega211/google_sheet_sync.git
   cd google_sheets_sync
   ```
2. Создайте файл `.env` из примера и настройте переменные Google API:
   ```bash
   cp .env.example .env
   # Отредактируйте .env, установите GOOGLE_SERVICE_ACCOUNT_JSON и GOOGLE_SPREADSHEET_ID
   ```
3. Запустите сборку и запуск контейнеров:
   ```bash
   docker-compose up -d --build
   ```
4. Сгенерируйте ключ приложения и выполните миграции:
   ```bash
   docker-compose exec app php artisan key:generate
   docker-compose exec app php artisan migrate
   ```
5. Приложение будет доступно по адресу: [http://localhost:8000](http://localhost:8000)
## Использование
### Веб-интерфейс
- Главная страница: `/products`
- Генерация демо-данных (1000 продуктов): нажмите "Generate 1000 Products"
- Очистка всех данных: нажмите "Clear All Products"
- Установка URL Google Таблицы: введите URL в поле и нажмите "Set Spreadsheet"
- Синхронизация с Google Sheets: нажмите "Sync with Google Sheets"
- Просмотр комментариев: `/fetch` или `/fetch/{count}` (например, `/fetch/10`)
### Консольные команды
- Синхронизация данных:
  ```bash
  php artisan sync:google-sheets
  ```
- Просмотр комментариев:
  ```bash
  # Все комментарии
  php artisan fetch:comments
  # Ограниченное количество
  php artisan fetch:comments --count=5
  # Только строки с комментариями
  php artisan fetch:comments --comments-only
  ```
### Планировщик задач
Синхронизация запускается автоматически каждую минуту. Для настройки cron на сервере добавьте:
```bash
* * * * * cd /path-to-your-project && php artisan schedule:run >> /dev/null 2>&1
```
В Docker-среде планировщик уже настроен и работает внутри контейнера `scheduler`.
## Docker-структура
- `app`: Веб-сервер (Laravel + PHP-FPM)
- `webserver`: Nginx
- `db`: MySQL
- `phpmyadmin`: PhpMyAdmin (доступен на [http://localhost:8080](http://localhost:8080))
- `scheduler`: Запускает планировщик Laravel (синхронизацию каждую минуту)
## Переменные окружения
| Переменная                     | Описание                                  |
|--------------------------------|-------------------------------------------|
| `GOOGLE_SERVICE_ACCOUNT_JSON`  | Имя файла JSON-ключа сервисного аккаунта (в директории `storage/app`) |
| `GOOGLE_SPREADSHEET_ID`        | ID таблицы по умолчанию                   |
| `DB_*`                         | Настройки базы данных                     |
## Тестирование
1. Генерация тестовых данных:
   - Нажмите "Generate 1000 Products" в веб-интерфейсе
   - Или выполните в консоли: `php artisan db:seed --class=ProductSeeder` (если создан сидер)
2. Проверка синхронизации:
   - Установите ID таблицы через веб-интерфейс
   - Запустите синхронизацию
   - Проверьте данные в Google Таблице
3. Проверка комментариев:
   - Добавьте комментарии в колонку "Comments" Google Таблицы
   - Запустите команду `php artisan fetch:comments --comments-only`
   - Или перейдите по адресу `/fetch?comments=1`
## Содействие (Contributing)
Если вы хотите внести свой вклад в проект, пожалуйста, создайте Fork репозитория и отправьте Pull Request. Мы будем рады вашим предложениям и улучшениям!
## Лицензия
Этот проект открыт под лицензией [MIT](LICENSE).
```
