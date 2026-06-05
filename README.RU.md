# goxus

<p align="center">
  <img src="https://img.shields.io/badge/Go-1.26.1-00ADD8?logo=go&logoColor=white" alt="Go version">
  <img src="https://img.shields.io/badge/Next.js-16-000000?logo=next.js&logoColor=white" alt="Next.js">
  <img src="https://img.shields.io/badge/license-Apache%202.0-blue" alt="License Apache 2.0">
</p>

**goxus** — это full-stack SaaS admin panel с бэкендом на Go 1.26.1 и фронтендом на Next.js 16.2.6,
оркестрируемая из этого монорепозитория. Бэкенд предоставляет Gin HTTP API с PostgreSQL,
токен-аутентификацией (вход/выход), RBAC (ролевой моделью доступа), CRUD-управлением
пользователями, rate-limited эндпоинтом входа, планировщиком cron-задач и очисткой
просроченных токенов. Фронтенд — TypeScript admin dashboard на React 19,
построенный на Tailwind CSS v4 и shadcn/ui v4 (22 компонента), с формой входа,
сайдбар-навигацией, CRUD-таблицей пользователей и переключением тёмной/светлой темы.

---

## Обзор

goxus объединяет минималистичный высокопроизводительный API-слой на Go с
адаптивным admin dashboard на Next.js. Монорепозиторий использует
**git submodules**, чтобы хранить бэкенд и фронтенд в отдельных репозиториях с
независимым версионированием, предоставляя единую точку входа для разработки,
развёртывания и CI/CD.

В бэкенде реализованы:
- **Токен-аутентификация** — вход/выход по Bearer-токенам, таблица `users_tokens` с soft-delete и сроком действия
- **Rate limiting входа** — in-memory sliding-window ограничитель по IP клиента с HTTP 429 + Retry-After
- **CRUD пользователей** — создание, чтение, обновление, удаление (soft), восстановление и смена пароля с проверкой разрешений RBAC
- **RBAC-сервис** — роли, разрешения, назначение ролей пользователям (полный CRUD)
- **Очистка просроченных токенов** — cron-задача, удаляющая токены старше TTL (по умолч. 7 дней)
- **Версионированное API** — маршруты `/api/v1/` с публичными, аутентифицированными и rate-limited эндпоинтами
- **Планировщик cron** — YAML-конфигурируемые задачи (пример + очистка токенов)
- **xo codegen** — типобезопасные типы PostgreSQL, сгенерированные из схемы
- **golang-migrate** — миграции БД с seed-данными

Во фронтенде реализованы:
- **Admin dashboard** — сайдбар-навигация со сворачиваемым меню, адаптивный макет
- **Страница входа** — форма с валидацией (zod + react-hook-form), сохранение токена
- **Управление пользователями** — TanStack Table с поиском, фильтрацией по статусу/email, пагинацией с выбором размера страницы, диалогами создания/редактирования/смены пароля/подтверждения удаления, восстановлением soft-deleted пользователей
- **Тёмная/светлая тема** — next-themes провайдер с сохранением в localStorage
- **Auth guard** — маршруты dashboard автоматически перенаправляют на `/login` без токена
- **Общий API-клиент** — `apiFetch` / `apiFetchJSON` с автоматической вставкой Bearer-токена

---

## Структура проекта

| Директория | Компонент | Описание |
|-----------|-----------|----------|
| `back/`   | Go Backend | Gin HTTP API, аутентификация, RBAC, PostgreSQL, rate limiter, cron. Репозиторий: [goxus.back](https://github.com/nobuenhombre/goxus.back) |
| `front/`  | Next.js Frontend | Admin dashboard с shadcn/ui v4, TypeScript, React 19. Репозиторий: [goxus.front](https://github.com/nobuenhombre/goxus.front) |
| `PROCESS.md` | Документация | Рабочий процесс с submodule, настройка IDE, примеры (EN) |
| `PROCESS.RU.md` | Процесс разработки | То же, что PROCESS.md, на русском |
| `README.md` | Оркестратор | Точка входа в монорепозиторий, документация (EN) |
| `README.RU.md` | Оркестратор | Этот файл — точка входа в монорепозиторий, документация (RU) |

---

## Начало работы

### Требования

- Go 1.26+
- Node.js 20+ (управляется через nvm — см. `.nvmrc`)
- npm
- PostgreSQL 16+

### Клонирование с подмодулями

```bash
git clone --recurse-submodules git@github.com:nobuenhombre/goxus.git
cd goxus
```

Если вы уже клонировали репозиторий без флага `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

### Установка зависимостей

**Бэкенд:**

```bash
cd back
go mod download
```

**Фронтенд:**

```bash
cd front
nvm use
npm install
```

---

## Архитектура

```
┌──────────────────────────────────────────────────────────┐
│                    goxus (orchestrator)                  │
│                                                          │
│  ┌───────────────┐             ┌──────────────────────┐  │
│  │   back/       │             │    front/            │  │
│  │               │  HTTP/REST  │                      │  │
│  │  Gin API ◄──────────────────►  Next.js Admin       │  │
│  │  /api/v1/     │             │  Dashboard           │  │
│  │               │             │                      │  │
│  │  PostgreSQL   │             │  shadcn/ui v4        │  │
│  │  RBAC         │             │  Sidebar + Header    │  │
│  │  Auth (token) │             │  Login + Auth Guard  │  │
│  │  User CRUD    │             │  Users CRUD Table    │  │
│  │  Rate limiter │             │  Theme (dark/light)  │  │
│  │  Cron Jobs    │             │  API client (lib/)   │  │
│  └───────────────┘             └──────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

- **Оркестратор** объединяет оба подмодуля и служит точкой входа для скриптов,
  CI-пайплайнов и развёртывания.
- **Go-бэкенд** предоставляет RESTful JSON API через Gin на `/api/v1/`, подключается
  к PostgreSQL, реализует токен-аутентификацию (вход/выход по Bearer-токенам),
  CRUD пользователей с проверкой разрешений RBAC (включая soft-delete, восстановление и смену пароля),
  rate-limited вход через sliding-window ограничитель и фоновые cron-задачи, включая очистку просроченных токенов.
- **Next.js-фронтенд** потребляет API и рендерит admin dashboard на React 19.
  Включает сворачиваемый сайдбар с группами навигации, хедер с поиском/переключателем
  темы/меню пользователя, страницу входа с валидацией zod, CRUD-таблицу
  пользователей на TanStack Table с поиском/фильтрами по статусу и email/пагинацией с выбором размера страницы,
  диалогами создания/редактирования/смены пароля/подтверждения удаления, восстановлением soft-deleted пользователей
  и общий слой API-клиента (`api.ts`) для автоматической вставки Bearer-токена.

---

## Разработка

Запустите оба сервиса локально для разработки.

### Бэкенд

```bash
cd back
go run ./src/cmd/goxus/... -runtype=service -config=configs/local/config.yaml
```

API-сервер запускается на `http://localhost:8080`.

### Бэкенд — перегенерация Wire

После изменений в provider'ах:

```bash
cd back
make wire
```

### Фронтенд

```bash
cd front
nvm use
npm run dev
```

Сервер разработки запускается на `http://localhost:3000`.

### Быстрый запуск (Makefile оркестратора)

```bash
make dev          # проверить postgres + запустить backend + frontend + открыть браузер
make dev-bg       # то же, без браузера
make stop         # остановить фоновые процессы
make kill-back    # принудительно остановить backend (kill PID + освободить порт)
make kill-front   # принудительно остановить frontend (kill PID + освободить порт)
```

Переопределение конфига бэкенда:

```bash
make BACK_CONFIG=configs/e2e/config.yaml run-back   # запуск с E2E-конфигом (rate limiting отключён)
```

### Тесты фронтенда

```bash
cd front
nvm use
npm test              # Vitest unit tests (с MSW) — 15 тестов
npm run test:coverage # С отчётом о покрытии
npm run test:e2e      # Playwright E2E тесты — 6 файлов, ~596 строк
```

### Тесты бэкенда

```bash
cd back
go test ./... -count=1
```

### Процесс разработки

Смотрите [PROCESS.RU.md](./PROCESS.RU.md) — полное описание рабочего процесса с
submodule, включая:
- Настройку IDE (GoLand для back/, PhpStorm для front/)
- Git-процесс с submodule
- Реальный пример межрепозиторных изменений

---

## Технологический стек

| Слой | Технология |
|------|-----------|
| Язык (бэкенд) | Go 1.26.1 |
| Фреймворк (бэкенд) | Gin v1.12.0 |
| DI (бэкенд) | Google Wire v0.7.0 |
| База данных | PostgreSQL 16+ |
| Генерация кода БД | xo (кастомные Go-шаблоны) |
| Драйвер БД | pgx (через suikat/pkg/db/connectors/postgres-pgx-db) |
| Миграции | golang-migrate/migrate |
| Аутентификация | Токен-ориентированная (Bearer, таблица users_tokens) |
| Rate limiting | In-memory sliding-window |
| Фоновые задачи | robfig/cron v3.0.1 |
| RBAC | Кастомный сервис (роли, разрешения, декоратор) |
| Тесты PostgreSQL | testcontainers |
| Покрытие тестами (бэкенд) | **17.2%** в целом — `domain/user` 86.0%, `rbac` 83.1%, `ratelimit` 76.6%, `config` 41.4% |
| Язык (фронтенд) | TypeScript |
| Фреймворк (фронтенд) | Next.js 16.2.6 (App Router) |
| Среда выполнения (фронтенд) | React 19.2.4 + React Compiler |
| CSS | Tailwind CSS v4 (CSS-переменные, `@theme`) |
| UI-компоненты | shadcn/ui v4 (base-nova, 22 компонента) |
| Формы | react-hook-form + zod v4 |
| Иконки | lucide-react |
| Уведомления | sonner (Toaster) |
| Тема | next-themes v0.4.6 |
|| Unit-тесты | Vitest v4.1.8 + v8 coverage, jsdom |
|| Data Table | @tanstack/react-table v8.21.3 |
|| Моки API | MSW v2.14.6 |
|| E2E-тесты | Playwright v1.60.0 |
| Покрытие тестами (фронтенд) | **13.06%** (операторы) — `lib/` 78.2%, страницы/UI 0% |
| Менеджер пакетов (фронтенд) | npm |
| Node.js | v24.16.0 (nvm, `lts/*` в `.nvmrc`) |
| Оркестрация | Git submodules + Makefile |
| Лицензия | Apache 2.0 |

---

## Лицензия

Этот проект распространяется под лицензией Apache 2.0. Подробности — в файле [LICENSE](./LICENSE).

Все три репозитория (оркестратор, бэкенд, фронтенд) имеют лицензию Apache 2.0.