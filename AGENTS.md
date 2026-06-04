# AGENTS.md — goxus Orchestrator Monorepo

## 1. Overview

**goxus** is a full-stack SaaS admin panel monorepo orchestrated by
`github.com/nobuenhombre/goxus`. The orchestrator repo contains **no Go code** and
**no Next.js code** directly — it is purely a submodule wrapper that aggregates
two sibling repositories:

| Repository | URL | Role |
|---|---|---|
| orchestrator | `github.com/nobuenhombre/goxus` | Root `.gitmodules`, docs, CI wiring |
| backend | `github.com/nobuenhombre/goxus.back` | Go 1.26.1 backend (`back/`) |
| frontend | `github.com/nobuenhombre/goxus.front` | Next.js 16.2.6 admin dashboard (`front/`) |

Each submodule tracks a **pinned commit** — there is no branch-based "latest"
semantic; updates are explicit. Each submodule also has its own `AGENTS.md` and
README files inside its directory.

## 2. Project Layout

```
goxus/
├── .gitignore            # ignores .idea
├── .gitmodules           # submodule definitions
├── AGENTS.md             # this file
├── LICENSE               # Apache 2.0
├── PROCESS.md            # development workflow (EN)
├── PROCESS.RU.md         # development workflow (RU)
├── README.md             # orchestrator entry point (EN)
├── README.RU.md          # orchestrator entry point (RU)
├── config/               # empty — reserved for future use
├── back/  ──> goxus.back   (Go backend)
├── front/ ──> goxus.front  (Next.js frontend)
```

The `.gitmodules` config looks like:

```ini
[submodule "back"]
  path = back
  url = git@github.com:nobuenhombre/goxus.back.git

[submodule "front"]
  path = front
  url = git@github.com:nobuenhombre/goxus.front.git
```

Both submodules are checked out under the orchestrator root, each pinned to a
specific SHA. **Do not** commit changes to `back/` or `front/` from the
orchestrator root — work inside the submodule directories themselves.

## 3. Submodule Workflow

### Initial clone (first time on a machine)

```bash
git clone --recurse-submodules git@github.com:nobuenhombre/goxus.git
```

### If already cloned without submodules

```bash
git submodule update --init --recursive
```

### Pushing across submodules

Git does **not** auto-push submodules. After committing in a submodule:

```bash
cd back        # or front
git push origin main
cd ..
git add back   # stage the new submodule pointer
git commit -m "chore: bump back submodule"
git push
```

### Updating submodules to latest upstream

```bash
cd back
git checkout main && git pull
cd ..
git add back
git commit -m "chore(back): update to latest"
```

## 4. Tech Stack

| Layer | Technology |
|---|---|
| Orchestrator | git submodules, root `.gitmodules` |
| Backend language | Go 1.26.1 |
| Backend framework | Gin v1.12.0 |
| Backend DI | Google Wire v0.7.0 |
| Backend database | PostgreSQL |
| Backend ORM / codegen | xo (type-safe Go codegen from SQL) |
| Backend DB driver | pgx (via suikat/pkg/db/connectors/postgres-pgx-db) |
| Backend migrations | golang-migrate (CLI) |
| Backend scheduling | robfig/cron v3.0.1 |
| Backend auth | Token-based (users_tokens table, Bearer header) |
| Backend RBAC | Custom service (roles, permissions, decorator pattern) |
| Backend tests | testcontainers (PostgreSQL) + custom postgres helper |
| Backend test coverage | **19.0%** total — `domain/user` 86.4%, `rbac` 85.2%, `config` 41.4% |
| Backend license | Apache 2.0 |
| Frontend framework | Next.js 16.2.6 (App Router) |
| Frontend language | TypeScript |
| Frontend runtime | React 19.2.4 |
| Frontend styling | Tailwind CSS v4 (`@theme` inline, CSS variables) |
| Frontend UI library | shadcn/ui v4 (base-nova style, 20+ components) |
| Frontend form handling | react-hook-form + zod v4 |
| Frontend package manager | npm |
| Frontend icons | lucide-react |
| Frontend notifications | sonner (Toaster) |
| Frontend tests | Vitest v4.1.8 + v8 coverage |
| Frontend API mocking | MSW v2.14.6 |
| Frontend E2E | Playwright v1.60.0 |
| Frontend test coverage | **8.37%** total (statements) — `lib/` 75.5%, pages/UI 0% |
| Frontend license | Apache 2.0 |
| Node.js version | managed via nvm (`lts/*` in `.nvmrc`) |

## 5. Backend Architecture (back/)

```
src/
  cmd/goxus/                    # Entrypoint, Wire injector
  internal/app/goxus/
    cli/                        # CLI flags (suikat/pkg/clivar)
    config/                     # YAML config (load/save via yaml.v3)
    domain/                     # Business logic orchestrator
      user/                     #   User domain (CRUD, auth, roles)
    log/                        # Log file management
    api/server/                 # Gin HTTP server
      router/                   #   Base routes (unversioned /health)
        v1/                     #   v1 API routes
          handlers/             #     Welcome, Health, Auth, User CRUD
          middlewares/          #     CORS, API logger, Auth token
    cron-job/                   # Cron scheduler
      jobs/example/             #   Example cron job
  internal/pkg/db/goxus/        # xo-generated PostgreSQL types + repo
  internal/pkg/services/rbac/   # RBAC service (roles, permissions)
  internal/pkg/hash/            # Hashing utilities (md5)
  pkg/tests/postgres/           # Testcontainers helper (PostgreSQL 16-18)
  scripts/xo/                   # DB codegen & migrations
```

### API Routes

**Unversioned:**
- `GET /health` — Health check (status, app_version, server_time)

**v1 (all mounted under `/api/v1`):**

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/` | No | Welcome message |
| GET | `/api/v1/health` | No | Health check |
| POST | `/api/v1/auth/login` | No | Login (email + password → token) |
| POST | `/api/v1/user/logout` | Bearer | Logout (invalidate token) |
| POST | `/api/v1/entity/user/` | Bearer | Create user |
| GET | `/api/v1/entity/user/` | Bearer | List users |
| GET | `/api/v1/entity/user/:id` | Bearer | Get user by ID |
| PUT | `/api/v1/entity/user/:id` | Bearer | Update user |
| DELETE | `/api/v1/entity/user/:id` | Bearer | Soft-delete user (sets deleted_at) |
| POST | `/api/v1/entity/user/:id/restore` | Bearer | Restore soft-deleted user |
| GET | `/api/v1/entity/user/:id/roles` | Bearer | Get user roles |
| POST | `/api/v1/entity/user/:id/roles` | Bearer | Assign role to user |
| DELETE | `/api/v1/entity/user/:id/roles/:slug` | Bearer | Revoke role from user |

Auth middleware validates Bearer token from `users_tokens` table, checks
`deleted_at` is null on both token and user, updates `last_used_at`.

### Database schema

6 migrations applied:

| # | File | Description |
|---|------|-------------|
| 000001 | `create_users_table` | users table (id, name, email, password, timestamps) |
| 000002 | `seed_user` | Seed first user (nobuenhombre@yandex.ru) |
| 000003 | `create_rbac_tables` | RBAC tables (rbac_roles, rbac_permissions, rbac_role_permissions, rbac_user_roles) |
| 000004 | `seed_rbac` | Seed RBAC (4 permissions, admin role, assigned to nobuenhombre@yandex.ru) |
| 000005 | `seed_user_role_permissions` | Seed 3 more permissions (user_role_add, user_role_view, user_role_delete) + link to admin |
| 000006 | `create_users_tokens_table` | users_tokens table (token, user_id FK, last_used_at, soft delete) |

### User Domain Service

The user domain uses a **decorator pattern** for authorization:

```
Service interface
  └─ impl.go (pure business logic — CRUD, auth, password hashing)
       └─ authorized_service.go (RBAC decorator — checks permissions before delegation)
```

- `impl.go` implements `Service` with real DB operations
- `authorized_service.go` wraps `Service`, checks permissions via `rbac.Service`,
  then delegates to the inner implementation
- `provider.go` wires both layers: `NewAuthorized(New(dbRepo, rbacSvc), rbacSvc)`

Permissions used:
- `user_add`, `user_view`, `user_edit`, `user_delete` (from 000004)
- `user_role_add`, `user_role_view`, `user_role_delete` (from 000005)

Login/logout bypass RBAC (public endpoints; token self-identifies).

### RBAC service

Full CRUD service for roles and permissions with methods:
- CreateRole, CreatePermission, AssignPermissionsToRole, AssignRoleToUser
- CheckUserRole, CheckUserPermission, CheckRolePermission
- RevokeUserRole, RevokeRolePermission, DeleteRole, DeletePermission
- GetAllRoles, GetUserRoles, GetRolePermissions, GetAllPermissions

Tested via testcontainers with PostgreSQL (service_test.go, setup_test.go).

### DI dependency chain (Wire)

```
main()
  └─ initializeApp() [Wire]
       ├─ ProvideCLI()                    → cli.Service
       ├─ ProvideLogFile()                → ILogFile
       ├─ ProvideConfigApp()              → configapp.Service     [depends on CLI]
       ├─ ProviderGoxus()                 → *DbGoxusRepo          [depends on DB config]
       ├─ ProvideRBACService()            → rbac.Service          [depends on DbGoxusRepo]
       ├─ ProvideUserService()            → userdomain.Service    [depends on DbGoxusRepo + RBAC]
       ├─ ProvideDomain()                 → DomainService         [depends on CLI + Config + RBAC + UserService + DbGoxusRepo]
       ├─ ProvideExampleJobs()            → *cron.Cron            [depends on Domain]
       ├─ ProvideAPI()                    → IHTTPServer           [depends on Config + Log + Domain + UserService]
       └─ newApp()                        → IApp                  [top-level orchestrator]
```

Every provider returns `(Service, func(), error)` — Wire tracks cleanup in
reverse construction order.

### 3 run modes (controlled by `-runtype`)

| Mode | Flag | Behaviour |
|---|---|---|
| `init` | `-runtype=init` | Placeholder init (default) |
| `service` | `-runtype=service` | Start cron + HTTP server, graceful shutdown |
| default | (no flag) | domain.Run() |

### Test coverage

**Backend (Go):** 20.6% total (statements).

| Package | Coverage | Notes |
|---------|----------|-------|
| `domain/user` (impl + authorized) | **86.4%** | Core business logic — auth, CRUD, role management |
| `pkg/services/rbac` | **85.2%** | Full CRUD for roles, permissions, assignments |
| `pkg/services/ratelimit` | **73.1%** | In-memory sliding window rate limiter |
| `config` | **41.4%** | Load/save YAML config |
| `pkg/tests/postgres` | 0.0% | Test helper only (no production code) |
| `db/goxus` (xo-generated) | 0.0% | Generated repos — tested via services |
| `api/server/**` | 0.0% | HTTP handlers, middlewares, router — untested |
| `cmd/goxus` | 0.0% | Entrypoint, Wire gen |
| `cron-job`, `log`, `hash`, `cli`, `ratelimit/provider` | 0.0% | Infrastructure packages |
| **Total** | **20.6%** | |

**Frontend (TypeScript):** 8.37% statements (8.29% branches, 4.1% functions, 8.03% lines).

| Package | Coverage | Notes |
|---------|----------|-------|
| `lib/` total | **75.5%** | API client layer (auth.ts, users.ts, utils.ts) |
| `lib/auth.ts` | **85.0%** | Login/logout, token helpers |
| `lib/users.ts` | **71.4%** | User CRUD API client |
| `lib/utils.ts` | 0.0% | cn() utility (no logic to test) |
| Pages, components, hooks, providers | 0.0% | No component tests yet |
| **Total** | **8.37%** | |

### Test infrastructure

- `pkg/tests/postgres/postgres.go` — reusable testcontainers helper for
  PostgreSQL 16/17/18 (alpine). Returns container handle + DSN.
- RBAC tests use testcontainers directly (service_test.go, setup_test.go).
- User domain tests (service_test.go, authorized_service_test.go, setup_test.go).
- Frontend tests use Vitest 4.1.8 with v8 coverage provider and jsdom.
- Frontend API mocking via MSW handlers in `src/lib/__tests__/mocks/`.
- E2E tests via Playwright with webServer references to back and front.

## 6. Frontend Architecture (front/)

### Directory structure

```
src/
├── app/                          # Next.js App Router — file-based routing
│   ├── layout.tsx                # Root layout (Geist fonts, ThemeProvider, Toaster)
│   ├── globals.css               # Tailwind v4 + shadcn CSS variables + dark mode
│   ├── (dashboard)/              # Route group — authenticated admin shell
│   │   ├── layout.tsx            #   Dashboard layout (SidebarProvider, auth guard)
│   │   ├── page.tsx              #   Dashboard home (stats cards: users, sessions, roles, uptime)
│   │   └── users/
│   │       └── page.tsx          #   Users CRUD table (search, pagination, delete dialog)
│   └── login/
│       └── page.tsx              # Login form (zod validation, react-hook-form)
├── components/                   # App components and shadcn/ui registry
│   ├── app-header.tsx            # Header: sidebar trigger, nav, search, theme toggle, user
│   ├── app-sidebar.tsx           # Sidebar: team switcher, nav groups, user profile, logout
│   └── ui/                       # shadcn/ui v4 components (base-nova style)
│       ├── avatar.tsx, badge.tsx, button.tsx, card.tsx, checkbox.tsx, collapsible.tsx
│       ├── command.tsx, dialog.tsx, dropdown-menu.tsx, form.tsx, input.tsx
│       ├── input-group.tsx, label.tsx, scroll-area.tsx, separator.tsx, sheet.tsx
│       ├── sidebar.tsx, skeleton.tsx, sonner.tsx, table.tsx, textarea.tsx, tooltip.tsx
├── hooks/
│   └── use-mobile.ts             # Mobile breakpoint detection (768px)
├── lib/
│   ├── auth.ts                   # Auth API client (login, logout, token CRUD, isAuthenticated)
│   ├── users.ts                  # User CRUD API client (fetchUsers, deleteUser)
│   ├── utils.ts                  # cn() helper (clsx + tailwind-merge)
│   └── __tests__/
│       ├── setup.ts              # Vitest + MSW lifecycle (beforeAll/afterEach/afterAll)
│       ├── auth.test.ts          # 6 tests: token helpers + login + logout
│       ├── users.test.ts         # 4 tests: fetchUsers (auth, success, 401) + deleteUser
│       └── mocks/
│           ├── handlers.ts       # MSW handlers for /api/v1/auth/login, /user/logout, /entity/user/
│           └── server.ts         # MSW server setup
├── providers/
│   └── theme-provider.tsx        # Custom light/dark theme provider (localStorage persistence)
└── e2e/
    └── auth.spec.ts              # Playwright: login form, validation, login→dashboard→logout flow
```

### Authentication flow

1. User navigates to any route under `(dashboard)`.
2. Dashboard layout checks `isAuthenticated()` (localStorage token presence).
3. If no token, redirects to `/login`.
4. Login page POSTs to `/api/v1/auth/login`, receives `{token, user_id, name, email}`.
5. Token is saved to localStorage via `setToken()`, user info to `goxus_user_name`/`goxus_user_email`.
6. Frontend redirects to `/` (dashboard).
7. All subsequent API calls include `Authorization: Bearer <token>` header.
8. Logout POSTs to `/api/v1/user/logout`, clears localStorage, redirects to `/login`.

### Route map

| URL | Page | Auth | Description |
|-----|------|------|-------------|
| `/` | Dashboard home | Required | Stats cards (total users, active sessions, roles, uptime) |
| `/users` | Users table | Required | List/search users, paginate, delete with confirmation |
| `/login` | Login form | Public | Email + password login with zod validation |

Additional routes planned in sidebar but not yet implemented:
- `/roles` — RBAC management
- `/settings` — Application settings

### Testing

- **Unit tests**: Vitest + jsdom environment. Auth and users API clients tested with MSW-mocked HTTP.
- **E2E tests**: Playwright with two webServers (back + front). Tests login form rendering,
  validation, and the full login→dashboard→logout flow.
- **Coverage**: Only `lib/` is covered (~75%). Pages, components, hooks, and providers are at 0%.

### Tech notes

- shadcn/ui v4 uses `components.json` with `style: "base-nova"` and `iconLibrary: "lucide"`.
- Tailwind v4 uses `@theme` inline CSS variables (no `tailwind.config.js`), `@import "tailwindcss"`.
- shadcn v4 components use Base UI `render` prop pattern (not Radix `asChild`).
- `DropdownMenuLabel` MUST be wrapped in `DropdownMenuGroup` to avoid runtime errors.
- Theme provider is custom (not `next-themes`), stores theme in localStorage under `goxus_theme` key.
- `NEXT_PUBLIC_API_URL` defaults to `http://localhost:8080`.
- Root route `/` is served by `(dashboard)/page.tsx` — the `(dashboard)` route group is transparent to URL.
- Root `app/page.tsx` does not exist; all routes live either in `(dashboard)` or `/login`.

## 7. Gotchas

- **Submodules are pinned to commits.** Every `git submodule update` checks out
  the exact SHA recorded in the orchestrator index — NOT the latest on any
  branch. To update, you must explicitly `cd` into the submodule, pull, and
  commit the new pointer.
- **Detached HEAD.** After `git submodule update`, each submodule is in
  detached-HEAD state. Always `cd back && git checkout main` (or whichever
  branch you work on) before making new commits, or use `--remote` carefully.
- **Separate git operations.** A `git push` from the orchestrator root does
  **not** push submodule contents. You must push each submodule independently,
  then push the orchestrator to record the new submodule pointers.
- **`git pull` is not recursive by default.** Use `git pull --recurse-submodules`
  or pull inside each submodule manually.
- **CI/CD must handle submodules.** Any CI pipeline cloning the orchestrator
  must use `--recurse-submodules` or run `git submodule update --init` manually.
- **Two clones possible.** The user may have standalone clones of back/front
  (e.g. `~/Sources/golang.app/goxus.back/`) in addition to the submodule copies.
  Push from either, then pull the submodule copy and update the pointer.
- **License is Apache 2.0** for all three repos — not MIT as older README badges
  claimed.
- **Orchestrator-level docs** include PROCESS.md and PROCESS.RU.md with detailed
  submodule workflow, IDE setup (GoLand for back/, PhpStorm for front/), and a
  worked example of changing .gitignore across clones.
- **v1 routes are split** — "public" (Welcome, Health, Login) and "protected"
  (everything under `:authMiddleware`). Auth middleware reads Bearer token,
  validates against `users_tokens` table, and sets `token`/`user` in Gin context.
- **User domain decorator** — `authorized_service.go` wraps the raw service.
  Permission checks use `actorID` from context (set by auth middleware).
  Login/Logout bypass RBAC since the token identifies itself.
- **Frontend: no root page.tsx** — the `(dashboard)` route group handles `/`.
  The root layout wraps both dashboard and login with ThemeProvider + Toaster.
- **Frontend: nvm wrapper** — use `bash -c 'source $(HOME)/.nvm/nvm.sh && nvm use && CMD'`
  in scripts, not `. nvm.sh` (dash returns exit 3 silently).
- **Frontend: shadcn v4** components use Base UI `render` prop, not Radix `asChild`.
  `DropdownMenuLabel` must be inside `DropdownMenuGroup`.
- **Frontend: Playwright webServer** uses `make -C .. run-back` and `make -C .. run-front` from the orchestrator root (these Makefile targets must exist).

## 8. Commands

| Action | Command |
|---|---|
| Clone with submodules | `git clone --recurse-submodules <repo-url>` |
| Init submodules | `git submodule update --init` |
| Update to pinned SHA | `git submodule update --recursive` |
| Update to latest remote | `git submodule update --remote --merge` |
| Run command in each | `git submodule foreach '<command>'` |
| Pull + submodules | `git pull --recurse-submodules` |
| Status of submodules | `git submodule status` |
| Backend dev server | `cd back && go run ./src/cmd/goxus/... -runtype=service -config=configs/local/config.yaml` |
| Backend Wire gen | `cd back && make wire` |
| Backend tests | `cd back && go test ./...` |
| Backend test (with coverage) | `cd back && go test ./... -coverprofile=c.out && go tool cover -func=c.out` |
| Backend coverage (total) | `cd back && go test ./... -coverprofile=c.out && go tool cover -func=c.out | grep total` |
| Frontend dev server | `cd front && nvm use && npm run dev` |
| Frontend build | `cd front && nvm use && npm run build` |
| Frontend lint | `cd front && nvm use && npm run lint` |
| Frontend tests | `cd front && nvm use && npm test` |
| Frontend tests (with coverage) | `cd front && nvm use && npm run test:coverage` |
| Frontend tests (watch) | `cd front && nvm use && npm run test:watch` |
| Frontend E2E tests | `cd front && nvm use && npm run test:e2e` |
| Frontend E2E (with UI) | `cd front && nvm use && npm run test:e2e:ui` |
| Migrate up | `cd back && ./src/scripts/xo/goxus/migrate-up.sh` |
| Migrate down | `cd back && ./src/scripts/xo/goxus/migrate-down.sh` |
| Migrate new | `cd back && ./src/scripts/xo/goxus/migrate-new.sh` |
| DB codegen (xo) | `cd back && ./src/scripts/xo/xo.sh goxus/xo.yaml` |
