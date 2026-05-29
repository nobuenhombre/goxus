# goxus

<p align="center">
  <img src="https://img.shields.io/badge/Go-1.22+-00ADD8?logo=go&logoColor=white" alt="Go version">
  <img src="https://img.shields.io/badge/Next.js-15-000000?logo=next.js&logoColor=white" alt="Next.js">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License MIT">
</p>

**goxus** — это full-stack SaaS-платформа с бэкендом на Go и фронтендом на Next.js,
оркестрируемая из этого монорепозитория. Бэкенд предоставляет Gin HTTP API с
постоянным хранилищем в PostgreSQL и планировщиком cron-задач; фронтенд —
современное TypeScript-приложение, построенное на Tailwind CSS v4 и shadcn/ui.

---

## Обзор

goxus объединяет минималистичный высокопроизводительный API-слой на Go с
адаптивным пользовательским интерфейсом на Next.js. Монорепозиторий использует
**git submodules**, чтобы хранить бэкенд и фронтенд в отдельных репозиториях с
независимым версионированием, предоставляя единую точку входа для разработки,
развёртывания и CI/CD.

---

## Структура проекта

| Директория | Компонент | Описание |
|-----------|-----------|----------|
| `back/`   | Go Backend | Gin HTTP API, миграции PostgreSQL, cron-задачи. Репозиторий: [goxus.back](https://github.com/nobuenhombre/goxus.back) |
| `front/`  | Next.js Frontend | TypeScript-приложение с Tailwind CSS v4 и shadcn/ui. Репозиторий: [goxus.front](https://github.com/nobuenhombre/goxus.front) |
| `README.md` | Оркестратор | Этот файл — точка входа в монорепозиторий, документация и скрипты координации |

---

## Начало работы

### Требования

- Go 1.22+
- Node.js 20+
- pnpm (рекомендуется) или npm
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
pnpm install
```

---

## Архитектура

```
┌──────────────────────────────────────────────────────┐
│                    goxus (orchestrator)               │
│                                                       │
│  ┌──────────────┐            ┌───────────────────┐   │
│  │   back/       │            │    front/          │   │
│  │               │  HTTP/REST │                    │   │
│  │  Gin API ◄─────────────────►  Next.js App      │   │
│  │               │            │                    │   │
│  │  PostgreSQL   │            │  shadcn/ui +       │   │
│  │  Cron Jobs    │            │  Tailwind CSS v4   │   │
│  └──────────────┘            └───────────────────┘   │
└──────────────────────────────────────────────────────┘
```

- **Оркестратор** объединяет оба подмодуля и служит точкой входа для скриптов,
  CI-пайплайнов и развёртывания.
- **Go-бэкенд** предоставляет RESTful JSON API через Gin, подключается к PostgreSQL
  для сохранения данных и выполняет фоновые cron-задачи.
- **Next.js-фронтенд** потребляет API, рендерит серверные и клиентские страницы,
  использует shadcn/ui для единообразного дизайна.

---

## Разработка

Запустите оба сервиса локально для разработки.

### Бэкенд

```bash
cd back
go run cmd/server/main.go
```

API-сервер запускается на `http://localhost:8080`.

### Фронтенд

```bash
cd front
pnpm dev
```

Сервер разработки запускается на `http://localhost:3000` и проксирует API-запросы
к бэкенду.

---

## Технологический стек

| Слой | Технология |
|------|-----------|
| Язык (бэкенд) | Go 1.22+ |
| Фреймворк (бэкенд) | Gin |
| База данных | PostgreSQL |
| Фоновые задачи | Go cron |
| Язык (фронтенд) | TypeScript |
| Фреймворк (фронтенд) | Next.js 15 |
| CSS | Tailwind CSS v4 |
| UI-компоненты | shadcn/ui |
| Менеджер пакетов (фронтенд) | pnpm |
| Оркестрация | Git submodules |

---

## Лицензия

Этот проект распространяется под лицензией MIT. Подробности — в файле [LICENSE](./LICENSE).
