# goxus

<p align="center">
  <img src="https://img.shields.io/badge/Go-1.26.1-00ADD8?logo=go&logoColor=white" alt="Go version">
  <img src="https://img.shields.io/badge/Next.js-16-000000?logo=next.js&logoColor=white" alt="Next.js">
  <img src="https://img.shields.io/badge/license-Apache%202.0-blue" alt="License Apache 2.0">
</p>

**goxus** — это full-stack SaaS admin panel с бэкендом на Go 1.26.1 и фронтендом на Next.js 16.2.6,
оркестрируемая из этого монорепозитория. Бэкенд предоставляет Gin HTTP API с PostgreSQL,
токен-аутентификацией (вход/выход), RBAC (ролевой моделью доступа), CRUD-управлением
пользователями и планировщиком cron-задач. Фронтенд — TypeScript admin dashboard на React 19,
построенный на Tailwind CSS v4 и shadcn/ui v4 (20+ компонентов), с формой входа,
сайдбар-навигацией, CRUD-таблицей пользователей и переключением тёмной/светлой темы.

---

## Обзор

goxus объединяет минималистичный высокопроизводительный API-слой на Go с
адаптивным admin dashboard на Next.js. Монорепозиторий использует
**git submodules**, чтобы хранить бэкенд и фронтенд в отдельных репозиториях с
независимым версионированием, предоставляя единую точку входа для разработки,
развёртывания и CI/CD.

В бэкенде реализованы:
- **Токен-аутентификация** — вход/выход по Bearer-токенам, таблица `users_tokens` с soft-delete
- **CRUD пользователей** — создание, чтение, обновление, удаление с проверкой разрешений RBAC
- **RBAC-сервис** — роли, разрешения, назначение ролей пользователям (полный CRUD)
- **Версионированное API** — маршруты `/api/v1/` с публичными и аутентифицированными эндпоинтами
- **Планировщик cron** — YAML-конфигурируемые задачи (пример: каждые 10 минут)
- **xo codegen** — типобезопасные типы PostgreSQL, сгенерированные из схемы
- **golang-migrate** — миграции БД с seed-данными

Во фронтенде реализованы:
- **Admin dashboard** — сайдбар-навигация со сворачиваемым меню, адаптивный макет
- **Страница входа** — форма с валидацией (zod + react-hook-form), сохранение токена
- **Управление пользователями** — таблица с поиском, пагинацией, диалогом подтверждения удаления
- **Тёмная/светлая тема** — кастомный провайдер темы с сохранением в localStorage
- **Auth guard** — маршруты dashboard автоматически перенаправляют на `/login` без токена

---

## Структура проекта

| Директория | Компонент | Описание |
|-----------|-----------|----------|
| `back/`   | Go Backend | Gin HTTP API, аутентификация, RBAC, PostgreSQL, cron. Репозиторий: [goxus.back](https://github.com/nobuenhombre/goxus.back) |
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
│  │  Cron Jobs    │             │  Theme (dark/light)  │  │
│  └───────────────┘             └──────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

- **Оркестратор** объединяет оба подмодуля и служит точкой входа для скриптов,
  CI-пайплайнов и развёртывания.
- **Go-бэкенд** предоставляет RESTful JSON API через Gin на `/api/v1/`, подключается
  к PostgreSQL, реализует токен-аутентификацию (вход/выход по Bearer-токенам),
  CRUD пользователей с проверкой разрешений RBAC и выполняет фоновые cron-задачи.
- **Next.js-фронтенд** потребляет API и рендерит admin dashboard на React 19.
  Включает сворачиваемый сайдбар с группами навигации, хедер с поиском/переключателем
  темы/меню пользователя, страницу входа с валидацией zod и CRUD-таблицу
  пользователей с поиском, пагинацией и подтверждением удаления.

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

### Тесты фронтенда

```bash
cd front
nvm use
npm test              # Vitest unit tests (с MSW)
npm run test:coverage # С отчётом о покрытии
npm run test:e2e      # Playwright E2E тесты
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
| Фоновые задачи | robfig/cron v3.0.1 |
| RBAC | Кастомный сервис (роли, разрешения, декоратор) |
| Тесты PostgreSQL | testcontainers |
| Покрытие тестами (бэкенд) | **19.0%** в целом — `domain/user` 86.4%, `rbac` 85.2%, `config` 41.4% |
| Язык (фронтенд) | TypeScript |
| Фреймворк (фронтенд) | Next.js 16.2.6 (App Router) |
| Среда выполнения (фронтенд) | React 19.2.4 |
| CSS | Tailwind CSS v4 (CSS-переменные, `@theme`) |
| UI-компоненты | shadcn/ui v4 (base-nova, 20+ компонентов) |
| Формы | react-hook-form + zod v4 |
| Иконки | lucide-react |
| Уведомления | sonner (Toaster) |
| Unit-тесты | Vitest v4.1.8 + v8 coverage, jsdom |
| Моки API | MSW v2.14.6 |
| E2E-тесты | Playwright v1.60.0 |
| Покрытие тестами (фронтенд) | **8.37%** (операторы) — `lib/` 75.5%, страницы/UI 0% |
| Менеджер пакетов (фронтенд) | npm |
| Node.js | nvm (`lts/*` в `.nvmrc`) |
| Оркестрация | Git submodules |
| Лицензия | Apache 2.0 |

---

## Лицензия

Этот проект распространяется под лицензией Apache 2.0. Подробности — в файле [LICENSE](./LICENSE).

Все три репозитория (оркестратор, бэкенд, фронтенд) имеют лицензию Apache 2.0.
