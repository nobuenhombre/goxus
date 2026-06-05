# goxus

<p align="center">
  <img src="https://img.shields.io/badge/Go-1.26.1-00ADD8?logo=go&logoColor=white" alt="Go version">
  <img src="https://img.shields.io/badge/Next.js-16-000000?logo=next.js&logoColor=white" alt="Next.js">
  <img src="https://img.shields.io/badge/license-Apache%202.0-blue" alt="License Apache 2.0">
</p>

**goxus** is a full-stack SaaS admin panel powered by a Go 1.26.1 backend and a Next.js 16.2.6 frontend, orchestrated from this monorepo. The backend delivers a Gin HTTP API with PostgreSQL persistence, token-based authentication (login/logout), RBAC (role-based access control), user management CRUD, rate-limited login endpoint, scheduled cron jobs, and expired token cleanup. The frontend is a TypeScript admin dashboard built with Tailwind CSS v4, React 19, shadcn/ui v4 (22 components), featuring login auth, sidebar navigation, user CRUD management, and dark/light theme switching.

---

## Overview

goxus combines a minimal, high-performance Go API layer with a responsive Next.js admin dashboard. The monorepo uses **git submodules** to keep the backend and frontend repositories independently versioned while providing a single entry point for development, deployment, and CI/CD.

The backend features:
- **Token authentication** — login/logout with Bearer tokens, `users_tokens` table with soft-delete and expiry
- **Login rate limiting** — in-memory sliding-window rate limiter per client IP with HTTP 429 + Retry-After
- **User management CRUD** — create, read, update, delete (soft), restore, and change password with RBAC permission checks
- **RBAC service** — roles, permissions, user-role assignment with full CRUD
- **Expired token cleanup** — cron job deleting tokens past TTL (default 7 days)
- **Versioned API** — routes under `/api/v1/` with public, authenticated, and rate-limited endpoints
- **Cron scheduler** — YAML-configurable jobs (example + token cleanup)
- **xo codegen** — type-safe PostgreSQL types generated from schema
- **golang-migrate** — database migrations with seed data

The frontend features:
- **Admin dashboard** — sidebar navigation with collapsible menu, responsive layout
- **Login page** — validated email/password form (zod + react-hook-form), token storage
- **User management UI** — TanStack Table with search, status/email filter tabs, pagination with page size selector, create/edit dialog, change password dialog, delete confirmation, restore soft-deleted users
- **Dark/light theme** — next-themes provider with localStorage persistence
- **Auth guard** — dashboard routes automatically redirect to `/login` if unauthenticated
- **Shared API client** — `apiFetch` / `apiFetchJSON` helpers with automatic Bearer token injection

---

## Project Structure

| Directory | Component | Description |
|-----------|-----------|-------------|
| `back/`   | Go Backend | Gin HTTP API, auth, RBAC, PostgreSQL, rate limiter, cron. Repository: [goxus.back](https://github.com/nobuenhombre/goxus.back) |
| `front/`  | Next.js Frontend | Admin dashboard with shadcn/ui v4, TypeScript, React 19. Repository: [goxus.front](https://github.com/nobuenhombre/goxus.front) |
| `PROCESS.md` | Development workflow | Detailed submodule workflow, IDE setup, real examples (EN) |
| `PROCESS.RU.md` | Процесс разработки | Same as PROCESS.md in Russian |
| `README.md` | Orchestrator | This file — monorepo entry point |

---

## Getting Started

### Prerequisites

- Go 1.26+
- Node.js 20+ (managed via nvm — see `.nvmrc`)
- npm
- PostgreSQL 16+

### Clone with Submodules

```bash
git clone --recurse-submodules git@github.com:nobuenhombre/goxus.git
cd goxus
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

### Install Dependencies

**Backend:**

```bash
cd back
go mod download
```

**Frontend:**

```bash
cd front
nvm use
npm install
```

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                    goxus (orchestrator)               │
│                                                       │
│  ┌──────────────┐            ┌───────────────────┐   │
│  │   back/       │            │    front/          │   │
│  │               │  HTTP/REST │                    │   │
│  │  Gin API ◄─────────────────►  Next.js Admin     │   │
│  │  /api/v1/     │            │  Dashboard         │   │
│  │               │            │                    │   │
│  │  PostgreSQL   │            │  shadcn/ui v4      │   │
│  │  RBAC         │            │  Sidebar + Header  │   │
│  │  Auth (token) │            │  Login + Auth Guard│   │
│  │  User CRUD    │            │  Users CRUD Table  │   │
│  │  Rate limiter │            │  Theme (dark/light)│   │
│  │  Cron Jobs    │            │  API client (lib/) │   │
│  └──────────────┘            └───────────────────┘   │
└──────────────────────────────────────────────────────┘
```

- The **orchestrator** wraps both submodules and is the entry point for scripts, CI pipelines, and deployment.
- The **Go backend** exposes a RESTful JSON API via Gin at `/api/v1/`, connects to PostgreSQL for persistence, provides token-based auth (login/logout with Bearer tokens), user CRUD with RBAC permission checks (including soft-delete, restore, and change password), rate-limited login endpoint via sliding-window rate limiter, and runs background cron tasks including expired token cleanup.
- The **Next.js frontend** consumes the API and renders an admin dashboard with React 19. Features include a collapsible sidebar with navigation groups, a header with search/theme toggle/user menu, a login page with zod validation, a users CRUD table with TanStack Table and client-side search/status-email filter tabs/pagination with page size selector, dialogs for create/edit/change password/delete confirmation, restore for soft-deleted users, and a shared API client layer (`api.ts`) for Bearer token injection.

---

## Development

Start both services locally for development.

### Backend

```bash
cd back
go run ./src/cmd/goxus/... -runtype=service -config=configs/local/config.yaml
```

The API server starts at `http://localhost:8080`.

### Backend with Wire

After changing providers:

```bash
cd back
make wire
```

### Frontend

```bash
cd front
nvm use
npm run dev
```

The development server starts at `http://localhost:3000`.

### Quick start (orchestrator Makefile)

```bash
make dev          # check postgres + start backend + frontend + open browser
make dev-bg       # same, no browser
make stop         # stop background processes
make kill-back    # force-stop backend (kill PID + free port)
make kill-front   # force-stop frontend (kill PID + free port)
```

Override the backend config:

```bash
make BACK_CONFIG=configs/e2e/config.yaml run-back   # run with E2E config (rate limiting disabled)
```

### Frontend Tests

```bash
cd front
nvm use
npm test              # Vitest unit tests (with MSW) — 15 tests
npm run test:coverage # With coverage report
npm run test:e2e      # Playwright E2E tests — 6 spec files, ~596 lines
```

### Backend Tests

```bash
cd back
go test ./... -count=1
```

### Development Process

See [PROCESS.md](./PROCESS.md) for the full submodule development workflow,
including:
- IDE setup (GoLand for back/, PhpStorm for front/)
- Git workflow with submodules
- Real-world example of cross-repo changes

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language (Backend) | Go 1.26.1 |
| Framework (Backend) | Gin v1.12.0 |
| DI (Backend) | Google Wire v0.7.0 |
| Database | PostgreSQL 16+ |
| DB Codegen | xo (custom Go templates) |
| DB Driver | pgx (via suikat/pkg/db/connectors/postgres-pgx-db) |
| Migrations | golang-migrate/migrate |
| Auth | Token-based (Bearer, users_tokens table) |
| Rate Limiting | In-memory sliding-window |
| Background Jobs | robfig/cron v3.0.1 |
| RBAC | Custom service (roles, permissions, decorator pattern) |
| Test PostgreSQL | testcontainers |
| Test coverage (Backend) | **17.2%** total — `domain/user` 86.0%, `rbac` 83.1%, `ratelimit` 76.6%, `config` 41.4% |
| Language (Frontend) | TypeScript |
| Framework (Frontend) | Next.js 16.2.6 (App Router) |
| Runtime (Frontend) | React 19.2.4 + React Compiler |
| CSS | Tailwind CSS v4 (CSS variables, `@theme`) |
| UI Components | shadcn/ui v4 (base-nova style, 22 components) |
| Form Handling | react-hook-form + zod v4 |
| Icons | lucide-react |
| Notifications | sonner (Toaster) |
| Theme | next-themes v0.4.6 |
|| Unit Tests | Vitest v4.1.8 + v8 coverage, jsdom |
|| Data Table | @tanstack/react-table v8.21.3 |
|| API Mocking | MSW v2.14.6 |
|| E2E Tests | Playwright v1.60.0 |
| Test coverage (Frontend) | **13.06%** (statements) — `lib/` 78.2%, pages/UI 0% |
| Package Manager (Frontend) | npm |
| Node.js version | v24.16.0 (nvm, `lts/*` in `.nvmrc`) |
| Orchestration | Git submodules + Makefile |
| License | Apache 2.0 |

---

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](./LICENSE) file for details.

All three repositories (orchestrator, back, front) are Apache 2.0 licensed.
