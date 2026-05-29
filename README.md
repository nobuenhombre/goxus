# goxus

<p align="center">
  <img src="https://img.shields.io/badge/Go-1.22+-00ADD8?logo=go&logoColor=white" alt="Go version">
  <img src="https://img.shields.io/badge/Next.js-15-000000?logo=next.js&logoColor=white" alt="Next.js">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License MIT">
</p>

**goxus** is a full-stack SaaS platform powered by a Go backend and a Next.js frontend, orchestrated from this monorepo. The backend delivers a Gin HTTP API backed by PostgreSQL with scheduled cron jobs; the frontend is a modern TypeScript application built with Tailwind CSS v4 and shadcn/ui components.

---

## Overview

goxus combines a minimal, high-performance Go API layer with a responsive Next.js user interface. The monorepo uses **git submodules** to keep the backend and frontend repositories independently versioned while providing a single entry point for development, deployment, and CI/CD.

---

## Project Structure

| Directory | Component | Description |
|-----------|-----------|-------------|
| `back/`   | Go Backend | Gin HTTP API, PostgreSQL migrations, cron job runners. Repository: [goxus.back](https://github.com/nobuenhombre/goxus.back) |
| `front/`  | Next.js Frontend | TypeScript app with Tailwind CSS v4 and shadcn/ui. Repository: [goxus.front](https://github.com/nobuenhombre/goxus.front) |
| `README.md` | Orchestrator | This file — monorepo entry point, documentation, and coordination scripts |

---

## Getting Started

### Prerequisites

- Go 1.22+
- Node.js 20+
- pnpm (recommended) or npm
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
pnpm install
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
│  │  Gin API ◄─────────────────►  Next.js App      │   │
│  │               │            │                    │   │
│  │  PostgreSQL   │            │  shadcn/ui +       │   │
│  │  Cron Jobs    │            │  Tailwind CSS v4   │   │
│  └──────────────┘            └───────────────────┘   │
└──────────────────────────────────────────────────────┘
```

- The **orchestrator** wraps both submodules and is the entry point for scripts, CI pipelines, and deployment.
- The **Go backend** exposes a RESTful JSON API via Gin, connects to PostgreSQL for persistence, and runs background cron tasks.
- The **Next.js frontend** consumes the API, renders server- and client-side pages, and uses shadcn/ui for consistent design.

---

## Development

Start both services locally for development.

### Backend

```bash
cd back
go run cmd/server/main.go
```

The API server starts at `http://localhost:8080`.

### Frontend

```bash
cd front
pnpm dev
```

The development server starts at `http://localhost:3000` and proxies API requests to the backend.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language (Backend) | Go 1.22+ |
| Framework (Backend) | Gin |
| Database | PostgreSQL |
| Background Jobs | Go cron |
| Language (Frontend) | TypeScript |
| Framework (Frontend) | Next.js 15 |
| CSS | Tailwind CSS v4 |
| UI Components | shadcn/ui |
| Package Manager (Frontend) | pnpm |
| Orchestration | Git submodules |

---

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.