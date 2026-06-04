# goxus

<p align="center">
  <img src="https://img.shields.io/badge/Go-1.26.1-00ADD8?logo=go&logoColor=white" alt="Go version">
  <img src="https://img.shields.io/badge/Next.js-16-000000?logo=next.js&logoColor=white" alt="Next.js">
  <img src="https://img.shields.io/badge/license-Apache%202.0-blue" alt="License Apache 2.0">
</p>

**goxus** is a full-stack SaaS admin panel powered by a Go 1.26.1 backend and a Next.js 16.2.6 frontend, orchestrated from this monorepo. The backend delivers a Gin HTTP API with PostgreSQL persistence, token-based authentication (login/logout), RBAC (role-based access control), user management CRUD, and scheduled cron jobs. The frontend is a TypeScript admin dashboard built with Tailwind CSS v4, React 19, shadcn/ui v4 (20+ components), featuring login auth, sidebar navigation, user CRUD management, and dark/light theme switching.

---

## Overview

goxus combines a minimal, high-performance Go API layer with a responsive Next.js admin dashboard. The monorepo uses **git submodules** to keep the backend and frontend repositories independently versioned while providing a single entry point for development, deployment, and CI/CD.

The backend features:
- **Token authentication** — login/logout with Bearer tokens, `users_tokens` table with soft-delete
- **User management CRUD** — create, read, update, delete users with RBAC permission checks
- **RBAC service** — roles, permissions, user-role assignment with full CRUD
- **Versioned API** — routes under `/api/v1/` with public and authenticated endpoints
- **Cron scheduler** — YAML-configurable jobs (example: every 10 minutes)
- **xo codegen** — type-safe PostgreSQL types generated from schema
- **golang-migrate** — database migrations with seed data

The frontend features:
- **Admin dashboard** — sidebar navigation with collapsible menu, responsive layout
- **Login page** — validated email/password form (zod + react-hook-form), token storage
- **User management UI** — searchable table with pagination, delete confirmation dialog
- **Dark/light theme** — custom theme provider with localStorage persistence
- **Auth guard** — dashboard routes automatically redirect to `/login` if unauthenticated

---

## Project Structure

| Directory | Component | Description |
|-----------|-----------|-------------|
| `back/`   | Go Backend | Gin HTTP API, auth, RBAC, PostgreSQL, cron. Repository: [goxus.back](https://github.com/nobuenhombre/goxus.back) |
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
│  │  Cron Jobs    │            │  Theme (dark/light)│   │
│  └──────────────┘            └───────────────────┘   │
└──────────────────────────────────────────────────────┘
```

- The **orchestrator** wraps both submodules and is the entry point for scripts, CI pipelines, and deployment.
- The **Go backend** exposes a RESTful JSON API via Gin at `/api/v1/`, connects to PostgreSQL for persistence, provides token-based auth (login/logout with Bearer tokens), user CRUD with RBAC permission checks, and runs background cron tasks.
- The **Next.js frontend** consumes the API and renders an admin dashboard with React 19. Features include a collapsible sidebar with navigation groups, a header with search/theme toggle/user menu, a login page with zod validation, and a users CRUD table with search, pagination, and delete confirmation.

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

### Frontend Tests

```bash
cd front
nvm use
npm test              # Vitest unit tests (with MSW)
npm run test:coverage # With coverage report
npm run test:e2e      # Playwright E2E tests
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
| Background Jobs | robfig/cron v3.0.1 |
| RBAC | Custom service (roles, permissions, decorator pattern) |
| Test PostgreSQL | testcontainers |
| Test coverage (Backend) | **20.6%** total — `domain/user` 86.4%, `rbac` 85.2%, `ratelimit` 73.1%, `config` 41.4% |
| Language (Frontend) | TypeScript |
| Framework (Frontend) | Next.js 16.2.6 (App Router) |
| Runtime (Frontend) | React 19.2.4 |
| CSS | Tailwind CSS v4 (CSS variables, `@theme`) |
| UI Components | shadcn/ui v4 (base-nova style, 20+ components) |
| Form Handling | react-hook-form + zod v4 |
| Icons | lucide-react |
| Notifications | sonner (Toaster) |
| Unit Tests | Vitest v4.1.8 + v8 coverage, jsdom |
| API Mocking | MSW v2.14.6 |
| E2E Tests | Playwright v1.60.0 |
| Test coverage (Frontend) | **8.37%** (statements) — `lib/` 75.5%, pages/UI 0% |
| Package Manager (Frontend) | npm |
| Node.js version | nvm (`lts/*` in `.nvmrc`) |
| Orchestration | Git submodules |
| License | Apache 2.0 |

---

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](./LICENSE) file for details.

All three repositories (orchestrator, back, front) are Apache 2.0 licensed.
