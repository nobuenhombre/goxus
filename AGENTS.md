# AGENTS.md — goxus Orchestrator Monorepo

## 1. Overview

**goxus** is a full-stack SaaS admin panel orchestrated by
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
├── Makefile              # orchestrator Makefile (check-postgres, run-back, run-front, test-*)
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
| Orchestrator | git submodules, root `.gitmodules`, project-level Makefile |
| Backend language | Go 1.26.1 |
| Backend framework | Gin v1.12.0 |
| Backend avatar support | File-system based (user avatars, E2E test images) |
| Backend DI | Google Wire v0.7.0 |
| Backend database | PostgreSQL |
| Backend ORM / codegen | xo (type-safe Go codegen from SQL) |
| Backend DB driver | pgx (via suikat/pkg/db/connectors/postgres-pgx-db) |
| Backend migrations | golang-migrate (CLI) |
| Backend scheduling | robfig/cron v3.0.1 |
| Backend rate limiting | In-memory sliding-window rate limiter |
| Backend auth | Token-based (users_tokens table, Bearer header) |
| Backend RBAC | Custom service (roles, permissions, decorator pattern) |
| Backend tests | testcontainers (PostgreSQL) + custom postgres helper |
| Backend test coverage | **11.9%** total — `domain/settings` ~77%, `domain/user` 86.6%, `rbac` 97.3%, `ratelimit` 76.6%, `config` 96.8% |
| Backend license | Apache 2.0 |
| Backend LOC | 17,512 lines of Go (97 .go files, 11 test files) |
| Frontend framework | Next.js 16.2.6 (App Router) |
| Frontend language | TypeScript |
| Frontend runtime | React 19.2.4 + React Compiler |
| Frontend styling | Tailwind CSS v4 (`@theme` inline, CSS variables) |
| Frontend UI library | shadcn/ui v4 (base-nova style, 27 components) |
| Frontend form handling | react-hook-form + zod v4 |
| Frontend package manager | npm |
| Frontend icons | lucide-react |
| Frontend notifications | sonner (Toaster) |
| Frontend theme | next-themes v0.4.6 |
| Frontend AI skills | shadcn/ui skill installed via [skills.sh](https://skills.sh) → `~/.agents/skills/shadcn/` |
| Frontend tests | Vitest v4.1.8 + v8 coverage |
| Frontend API mocking | MSW v2.14.6 |
| Frontend E2E | Playwright v1.60.0 — 12 spec files |
| Frontend test coverage | **5.46%** total (statements) — `lib/` 33.17%, pages/UI 0% |
| Frontend license | Apache 2.0 |
| Frontend LOC | 8,230 lines of TS/TSX (62 files, 12 E2E specs) |
| Node.js version | v24.16.0 (managed via nvm, `lts/*` in `.nvmrc`) |

## 5. Backend Architecture (back/)

```
src/
  cmd/goxus/                    # Entrypoint, Wire injector
  internal/app/goxus/
    cli/                        # CLI flags (suikat/pkg/clivar)
    config/                     # YAML config (load/save via yaml.v3)
    domain/                     # Business logic orchestrator
      user/                     #   User domain (CRUD, auth, roles, token cleanup, avatar)
      settings/                 #   Settings domain (settings definitions, user settings CRUD)
    log/                        # Log file management
    version/                    # Version constant (v0.1.0, set via ldflags-compatible)
    api/server/                 # Gin HTTP server
      router/                   #   Base routes (unversioned /health)
        v1/                     #   v1 API routes
          handlers/             #     Welcome, Health, Auth, User CRUD, change password, Settings, Avatar
          middlewares/          #     CORS, API logger, Auth token, Rate limiter
    cron-job/                   # Cron scheduler
      jobs/example/             #   Example cron job (every 10 min)
      jobs/token-cleanup/       #   Token cleanup job (deletes expired tokens)
  internal/pkg/db/goxus/        # xo-generated PostgreSQL types + repo
  internal/pkg/services/rbac/   # RBAC service (roles, permissions)
  internal/pkg/services/ratelimit/ # In-memory sliding-window rate limiter
  internal/pkg/hash/            # Hashing utilities (md5)
  pkg/tests/postgres/           # Testcontainers helper (PostgreSQL 16-18)
  scripts/xo/                   # DB codegen & migrations
```

### API Routes

**Unversioned:**
- `GET /health` — Health check (status, app_version, server_time)

**v1 (all mounted under `/api/v1`):**

| Method | Path | Auth | Rate-limited | Description |
|--------|------|------|-------------|-------------|
| GET | `/api/v1/` | No | No | Welcome message |
| GET | `/api/v1/health` | No | No | Health check |
| POST | `/api/v1/auth/login` | No | **Yes** | Login (email + password → token). Returns 429 with Retry-After on rate limit |
| POST | `/api/v1/user/logout` | Bearer | No | Logout (invalidate token) |
| POST | `/api/v1/entity/user/` | Bearer | No | Create user |
| GET | `/api/v1/entity/user/` | Bearer | No | List users |
| GET | `/api/v1/entity/user/:id` | Bearer | No | Get user by ID |
| PUT | `/api/v1/entity/user/:id` | Bearer | No | Update user |
| DELETE | `/api/v1/entity/user/:id` | Bearer | No | Soft-delete user (sets deleted_at) |
| POST | `/api/v1/entity/user/:id/restore` | Bearer | No | Restore soft-deleted user |
| PUT | `/api/v1/entity/user/:id/password` | Bearer | No | Change user password (requires `user_edit`) |
| GET | `/api/v1/entity/user/:id/roles` | Bearer | No | Get user roles |
| POST | `/api/v1/entity/user/:id/roles` | Bearer | No | Assign role to user |
| DELETE | `/api/v1/entity/user/:id/roles/:slug` | Bearer | No | Revoke role from user |
| GET | `/api/v1/entity/user/:id/avatar` | Bearer | No | Get user avatar file |
| POST | `/api/v1/entity/user/:id/avatar` | Bearer | No | Upload user avatar (multipart, max 2MB, 200x200) |
| DELETE | `/api/v1/entity/user/:id/avatar` | Bearer | No | Delete user avatar |
| GET | `/api/v1/settings/definitions` | Bearer | No | Get settings definitions (groups, types, settings) |
| GET | `/api/v1/settings/user` | Bearer | No | Get current user's settings |
| PUT | `/api/v1/settings/user` | Bearer | No | Upsert a single user setting |

Auth middleware validates Bearer token from `users_tokens` table, checks
`deleted_at` is null on both token and user, updates `last_used_at`.

Login rate limiting uses in-memory sliding-window rate limiter keyed by client IP.
Returns HTTP 429 with `Retry-After` header when limit is exceeded.

### Database schema

16 migrations applied:

| # | File | Description |
|---|------|-------------|
| 000001 | `create_users_table` | users table (id, name, email, password, timestamps) |
| 000002 | `seed_user` | Seed first user (nobuenhombre@yandex.ru) |
| 000003 | `create_rbac_tables` | RBAC tables (rbac_roles, rbac_permissions, rbac_role_permissions, rbac_user_roles) |
| 000004 | `seed_rbac` | Seed RBAC (4 permissions, admin role, assigned to nobuenhombre@yandex.ru) |
| 000005 | `seed_user_role_permissions` | Seed 3 more permissions (user_role_add, user_role_view, user_role_delete) + link to admin |
| 000006 | `create_users_tokens_table` | users_tokens table (token, user_id FK, last_used_at, soft delete, expires_at) |
| 000007 | `create_users_email_partial_unique_index` | Partial unique index on `users(email)` WHERE deleted_at IS NULL |
| 000008 | `create_user_with_roles_view` | View joining users + roles for efficient listing |
| 000009 | `seed_data_rbac_roles` | Seed additional RBAC roles data |
| 000010 | `create_settings_types_table` | settings_types table (id, name) |
| 000011 | `create_settings_groups_table` | settings_groups table (id, name, slug, description, sort_order) |
| 000012 | `create_settings_table` | settings table (id, group_id FK, type_id FK, key, label, description, default_value, sort_order, validation_rules JSON) |
| 000013 | `create_users_settings_table` | users_settings table (id, user_id FK, setting_id FK, value, updated_at) |
| 000014 | `users_settings_user_id_setting_id_index` | Unique composite index on users_settings(user_id, setting_id) |
| 000015 | `seed_additional_settings` | Seed 47 settings across groups (general, security, notifications, privacy, accessibility, localization) |
| 000016 | `seed_accessibility_group` | Seed accessibility group + additional settings |

### User Domain Service

The user domain uses a **decorator pattern** for authorization:

```
Service interface
  └─ impl.go (pure business logic — CRUD, auth, password hashing, token cleanup, change password)
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
`DeleteExpiredTokens` is not permission-gated (internal cron job).

### RBAC service

Full CRUD service for roles and permissions with methods:
- CreateRole, CreatePermission, AssignPermissionsToRole, AssignRoleToUser
- CheckUserRole, CheckUserPermission, CheckRolePermission
- RevokeUserRole, RevokeRolePermission, DeleteRole, DeletePermission
- GetAllRoles, GetUserRoles, GetRolePermissions, GetAllPermissions

Tested via testcontainers with PostgreSQL (service_test.go, setup_test.go).

### Rate limiter service

In-memory sliding-window rate limiter with configurable limits per window.
Used for login rate limiting by client IP. Methods:
- `New(window time.Duration, maxRequests int)` — create limiter
- `Allow(key string) bool` — check + consume slot
- `Remaining(key string) int` — remaining requests in current window
- `ResetAfter(key string) time.Duration` — time until window resets

### Cron jobs

| Job | Schedule | Description |
|-----|----------|-------------|
| Example job | Every 10 minutes | Default example task |
| Token cleanup | Every hour (configurable) | Deletes expired tokens where `expires_at < NOW()`. TTL default: 7 days from `last_used_at` |

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
       ├─ ProvideRateLimiter()            → ratelimit.Service     [depends on Config]
       ├─ ProvideExampleJobs()            → *cron.Cron            [depends on Domain]
       ├─ ProvideAPI()                    → IHTTPServer           [depends on Config + Log + Domain + RateLimiter]
       └─ newApp()                        → IApp                  [top-level orchestrator]
```

Every provider returns `(Service, func(), error)` — Wire tracks cleanup in
reverse construction order.

### Architecture rule: DomainService as the sole gateway

**API handlers, cronjobs, and any other entry point MUST interact ONLY with
`domainapp.DomainService`** — never directly with repositories or internal
services (userdomain, rbac, ratelimit). See the
[domain-service-orchestrator-gateway](./golang/domain-service-orchestrator-gateway/SKILL.md)
skill for the full rule, motivation, code review checklist, and refactoring examples.

### 3 run modes (controlled by `-runtype`)

| Mode | Flag | Behaviour |
|---|---|---|
| `init` | `-runtype=init` | Placeholder init (default) |
| `service` | `-runtype=service` | Start cron + HTTP server, graceful shutdown |
| default | (no flag) | domain.Run() |

### Test coverage

**Backend (Go):** 11.9% total (statements).

| Package | Coverage | Notes |
|---------|----------|-------|
| `domain/user` (impl + authorized) | **86.6%** | Core business logic — auth, CRUD, role management, token cleanup, avatar (untested) |
| `domain/settings` (impl) | **~77%** | New — settings definitions, user settings CRUD (provider 0%) |
| `pkg/services/rbac` | **97.3%** | Full CRUD for roles, permissions, assignments |
| `pkg/services/ratelimit` | **76.6%** | In-memory sliding window rate limiter |
| `config` | **96.8%** | Load/save YAML config, SetDefaults |
| `pkg/tests/postgres` | 0.0% | Test helper only (no production code) |
| `db/goxus` (xo-generated) | 0.0% | Generated repos — tested via services |
| `api/server/**` | 0.0% | HTTP handlers, middlewares, router — untested |
| `cmd/goxus` | 0.0% | Entrypoint, Wire gen |
| `cron-job`, `log`, `hash`, `cli`, `ratelimit/provider`, `version` | 0.0% | Infrastructure packages |
| **Total** | **11.9%** | 17,512 LOC, 97 .go files, 11 test files |

**Frontend (TypeScript):** 5.46% statements (5.25% branches, 3.31% functions, 5.59% lines).

| Package | Coverage | Notes |
|---------|----------|-------|
| `lib/` total | **33.17%** | API client layer (api.ts, auth.ts, users.ts, role.ts, permission.ts, date.ts, utils.ts, settings.ts) |
| `lib/api.ts` | **100%** | Shared API fetch helpers (apiFetch, apiFetchJSON, ApiResponseError) |
| `lib/auth.ts` | **70.21%** | Login/logout, token helpers |
| `lib/users.ts` | **23.68%** | User CRUD API client |
| `lib/settings.ts` | 0.0% | Settings API client (new — untested) |
| `lib/role.ts` | 0.0% | Role management API client (untested) |
| `lib/permission.ts` | 0.0% | Permission constants (constants only) |
| `lib/date.ts` | 0.0% | Date formatting utility (no logic to test) |
| `lib/utils.ts` | 0.0% | cn() utility (no logic to test) |
| Pages, components, hooks, providers | 0.0% | No component tests yet |
| **Total** | **5.46%** | 8,230 LOC, 62 files, 12 E2E specs |

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
|   └── (dashboard)/              # Route group — authenticated admin shell
|   │   ├── layout.tsx            #   Dashboard layout (SidebarProvider, auth guard)
|   │   ├── page.tsx              #   Dashboard home (stats cards: users, sessions, roles, uptime)
|   │   ├── settings/
|   │   │   └── page.tsx          #   Settings page (groups, sections, combobox/switch/slider/radio inputs)
|   │   └── users/
│   │       ├── page.tsx              #   Users CRUD table (TanStack Table, filters, pagination, delete, restore, change password, roles badge)
│   │       ├── users-action-dialog.tsx #   Create/Edit user dialog (react-hook-form + zod)
│   │       ├── change-password-dialog.tsx # Change password dialog
│   │       └── roles-dialog.tsx     #   Roles management dialog (assign/revoke roles via checkboxes)
│   └── login/
│       └── page.tsx              # Login form (zod validation, react-hook-form)
├── components/                   # App components and shadcn/ui registry
│   ├── app-header.tsx            # Header: sidebar trigger, nav, search, theme toggle, user
│   ├── app-sidebar.tsx           # Sidebar: team switcher, nav groups, user profile, logout
│   ├── avatar-upload-dropzone.tsx # Drag-and-drop avatar upload with preview
│   ├── data-table/               # Reusable data table with pagination
│   │   ├── index.ts              #   Re-export
│   │   └── pagination.tsx        #   Pagination widget (page numbers with ellipsis, page size selector)
│   ├── settings-sidebar-nav.tsx  # Settings sidebar navigation (groups, sections)
│   └── ui/                       # shadcn/ui v4 components (base-nova style, 29 components)
│       ├── avatar.tsx, badge.tsx, button.tsx, card.tsx, checkbox.tsx, collapsible.tsx
│       ├── combobox.tsx, command.tsx, dialog.tsx, dropdown-menu.tsx, form.tsx, input.tsx
│       ├── input-group.tsx, item.tsx, label.tsx, popover.tsx, radio-group.tsx
│       ├── scroll-area.tsx, select.tsx, separator.tsx, sheet.tsx, sidebar.tsx
│       ├── skeleton.tsx, slider.tsx, sonner.tsx, switch.tsx, table.tsx
│       ├── tabs.tsx, textarea.tsx, tooltip.tsx
├── hooks/
│   ├── use-local-storage.ts      # useSyncExternalStore-based localStorage hook
│   └── use-mobile.ts             # Mobile breakpoint detection (768px)
├── lib/
│   ├── api.ts                    # Shared API fetch helpers (apiFetch, apiFetchJSON, API_BASE)
│   ├── auth.ts                   # Auth API client (login, logout, token CRUD, isAuthenticated)
│   ├── date.ts                   # formatDate() date formatting utility
│   ├── users.ts                  # User CRUD API client (fetchUsers, createUser, updateUser, deleteUser, restoreUser, changeUserPassword)
│   ├── role.ts                   # Role management API client (fetchAllRoles, fetchUserRoles, assignUserRole, revokeUserRole)
│   ├── permission.ts             # Permission slug constants
│   ├── settings.ts               # Settings API client (fetchSettingsDefinitions, fetchUserSettings, upsertUserSetting)
│   ├── utils.ts                  # cn() helper (clsx + tailwind-merge)
│   └── __tests__/
│       ├── setup.ts              # Vitest + MSW lifecycle (beforeAll/afterEach/afterAll)
│       ├── auth.test.ts           # 10 tests: token helpers + login + logout (MSW-mocked)
│       ├── users.test.ts         # 6 tests: fetchUsers (auth, success, 401) + deleteUser
│       └── mocks/
│           ├── handlers.ts       # MSW handlers for auth/login, /user/logout, /entity/user/, /entity/user/:id/restore
│           └── server.ts         # MSW server setup
├── providers/
│   └── theme-provider.tsx        # next-themes wrapper (supports light/dark/system, localStorage)
├── types/
│   └── tanstack-table.d.ts       # TanStack Table ColumnMeta extension (className)
├── e2e/
│   ├── auth.spec.ts              # Playwright: login form, validation, login→dashboard→logout flow
│   ├── avatar-sidebar-header.spec.ts  # Playwright: avatar in sidebar + header
│   ├── nav-links-users-filters.spec.ts  # Playwright: sidebar/header nav links preserve filter params (145 lines)
│   ├── settings.spec.ts          # Playwright: settings page rendering, interactions, persistence
│   ├── users-avatar.spec.ts      # Playwright: user avatar upload/delete flow
│   ├── users-delete.spec.ts      # Playwright: user soft delete flow with filter=all (74 lines)
│   ├── users-edit.spec.ts        # Playwright: user edit form data on multiple opens (90 lines)
│   ├── users-filters-email-verified.spec.ts  # Playwright: email verification filters (96 lines)
│   ├── users-filters-soft-deleted.spec.ts    # Playwright: soft-deleted status filters (120 lines)
│   ├── users-pagination.spec.ts  # Playwright: pagination, page size selector, page numbers (350 lines)
│   └── users-role-filter.spec.ts # Playwright: role filter via combobox (58 lines)
```

### Authentication flow

1. User navigates to any route under `(dashboard)`.
2. Dashboard layout checks `isAuthenticated()` (localStorage token presence).
3. If no token, redirects to `/login`.
4. Login page POSTs to `/api/v1/auth/login`, receives `{token, user_id, name, email}`.
5. Token is saved to localStorage via `setToken()`, user info to `goxus_user_name`/`goxus_user_email`.
6. Frontend redirects to `/` (dashboard).
7. All subsequent API calls include `Authorization: Bearer *** header via apiFetch()`.
8. Logout POSTs to `/api/v1/user/logout`, clears localStorage, redirects to `/login`.

### Route map

| URL | Page | Auth | Description |
|-----|------|------|-------------|
| `/` | Dashboard home | Required | Stats cards (total users, active sessions, roles, uptime) |
| `/users` | Users table | Required | List/search users with TanStack Table, status/email filter tabs, paginate, delete, restore, change password, edit |
| `/settings` | Settings | Required | Application settings with groups, combobox/switch/slider/radio inputs |
| `/login` | Login form | Public | Email + password login with zod validation |

Additional routes planned in sidebar but not yet implemented:
- `/roles` — RBAC management

### Testing

- **Unit tests**: Vitest + jsdom environment. Auth and users API clients tested with MSW-mocked HTTP.
  16 tests total: 10 for auth (token helpers, login, logout), 6 for users (fetchUsers, deleteUser).
- **E2E tests**: Playwright with two webServers (back + front). Tests login → dashboard → logout flow,
  user CRUD (edit, delete, restore), status/email/role filters, pagination, nav link persistence, avatar,
  and settings page. 12 spec files total.
- **Coverage**: Only `lib/` is covered (~33%). Pages, components, hooks, and providers are at 0%.
  New files `settings.ts` brings down the `lib/` average.

### Tech notes

- shadcn/ui v4 uses `components.json` with `style: "base-nova"` and `iconLibrary: "lucide"`.
- Tailwind v4 uses `@theme` inline CSS variables (no `tailwind.config.js`), `@import "tailwindcss"`.
- shadcn v4 components use Base UI `render` prop pattern (not Radix `asChild`).
- `DropdownMenuLabel` MUST be wrapped in `DropdownMenuGroup` to avoid runtime errors.
- Theme provider wraps `next-themes` `ThemeProvider` (light/dark/system, stored in localStorage).
- React Compiler is enabled in `next.config.ts` (`experimental.reactCompiler`).
- `NEXT_PUBLIC_API_URL` defaults to `http://localhost:8080`.
- Root route `/` is served by `(dashboard)/page.tsx` — the `(dashboard)` route group is transparent to URL.
- Root `app/page.tsx` does not exist; all routes live either in `(dashboard)` or `/login`.
- `@tanstack/react-table` v8.21.3 is used for table rendering (`useReactTable`, `flexRender`, `ColumnDef`).
  Type extensions for `ColumnMeta.className` are declared in `src/types/tanstack-table.d.ts`.

### AI Skills for shadcn/ui

The project has the [shadcn/ui skill](https://ui.shadcn.com/docs/skills) installed globally via [skills.sh](https://skills.sh):

```bash
npx skills add shadcn/ui     # installed → ~/.agents/skills/shadcn/
```

The skill provides AI assistants with:
- **Project context** — runs `npx shadcn@latest info --json` to read `components.json` (framework, aliases, installed components, icon library, base library)
- **CLI command reference** — `init`, `add`, `search`, `view`, `docs`, `diff`, `info`, `build`, presets, templates
- **Theming & customization** — CSS variables, OKLCH colors, dark mode, Tailwind v4 semantics
- **Registry authoring** — `registry.json` format, item types, dependencies, community registries
- **MCP Server** — search, browse, and install components from registries

To refresh the context for any shadcn-related task:
```bash
npx shadcn@latest info --json     # project config + installed components
npx shadcn@latest docs <component> # get docs + example URLs
npx shadcn@latest search -q "query" # search registries
```

Key rules enforced by the skill:
- Use `FieldGroup` + `Field` for forms (not raw `div` + `Label`)
- Use `gap-*` instead of `space-x-*`/`space-y-*`
- Use `size-*` for equal width/height
- Use semantic colors (`bg-primary`, `text-muted-foreground`) never raw Tailwind values
- shadcn v4 uses Base UI `render` prop (not Radix `asChild`)
- `TabsTrigger` must be inside `TabsList`

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
- **Orchestrator-level Makefile** with targets: check-postgres, run-back, run-front,
  kill-back, kill-front, dev, dev-bg, stop, open, test-back, test-back-cover, test-front, test-front-e2e, test.
  PostgreSQL is managed via `systemctl start postgresql` (not pg_ctlcluster).
- **v1 routes are split** — "public" (Welcome, Health, Login) and "protected"
  (everything under `:authMiddleware`). Login additionally has rate limiting middleware.
  Auth middleware reads Bearer token, validates against `users_tokens` table, and sets
  `token`/`user` in Gin context.
- **User domain decorator** — `authorized_service.go` wraps the raw service.
  Permission checks use `actorID` from context (set by auth middleware).
  Login/Logout bypass RBAC since the token identifies itself.
  `DeleteExpiredTokens` bypasses RBAC (internal cron job).
- **Frontend: no root page.tsx** — the `(dashboard)` route group handles `/`.
  The root layout wraps both dashboard and login with ThemeProvider + Toaster.
- **Frontend: nvm wrapper** — use `source /home/bookworker06JAN1979/.nvm/nvm.sh && nvm use`
  in scripts, not `. nvm.sh` (dash returns exit 3 silently) nor `$HOME/.nvm/nvm.sh`
  (HOME may not be set in subshells).
- **Frontend: shadcn v4** components use Base UI `render` prop, not Radix `asChild`.
  `DropdownMenuLabel` must be inside `DropdownMenuGroup`.
- **Frontend: Playwright webServer** uses `BACK_CONFIG=configs/e2e/config.yaml make -C .. run-back` to start the backend with rate limiting disabled. The e2e config at `back/configs/e2e/config.yaml` has `rate_limit.enabled: false` to avoid blocking login attempts during tests. Never rely on the local/dev config for E2E — rate limiting will lock out test logins.
- **E2E user password:** The seeded user `nobuenhombre@yandex.ru` may have a different password from the seed migration (e.g. changed to `654321`). Check the current password with `psql -c "SELECT password FROM users WHERE email='nobuenhombre@yandex.ru'"` before writing E2E tests.
- **`BACK_CONFIG` overridable:** The orchestrator Makefile supports `BACK_CONFIG` env variable (default: `configs/local/config.yaml`). Use `make BACK_CONFIG=configs/e2e/config.yaml run-back` to run the backend with a different config.
- **`make kill-back` / `make kill-front`:** New Makefile targets that kill processes by PID file AND port (via `fuser -k PORT/tcp`), then wait up to 10 seconds for port release. Used internally by `dev-bg` and `stop`.

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
| Check postgres | `make check-postgres` |
| Backend dev server | `cd back && go run ./src/cmd/goxus/... -runtype=service -config=configs/local/config.yaml` |
| Override backend config | `cd back && go run ./src/cmd/goxus/... -runtype=service -config=$(BACK_CONFIG)` or `make BACK_CONFIG=configs/e2e/config.yaml run-back` |
| Frontend dev server | `cd front && source /home/bookworker06JAN1979/.nvm/nvm.sh && nvm use && npm run dev` |
| Dev (bg, all services) | `make dev-bg` or `make dev` (opens browser) |
| Stop bg services | `make stop` |
| Kill backend (force) | `make kill-back` |
| Kill frontend (force) | `make kill-front` |
| Backend Wire gen | `cd back && make wire` |
| Backend tests | `cd back && go test ./... -count=1` |
| Backend test (with coverage) | `cd back && go test ./... -count=1 -coverprofile=c.out && go tool cover -func=c.out` |
| Backend coverage (total) | `cd back && go test ./... -count=1 -coverprofile=c.out && go tool cover -func=c.out | grep total` |
| Frontend tests | `cd front && source /home/bookworker06JAN1979/.nvm/nvm.sh && nvm use && npm test` |
| Frontend tests (with coverage) | `cd front && source /home/bookworker06JAN1979/.nvm/nvm.sh && nvm use && npm run test:coverage` |
| Frontend tests (watch) | `cd front && source /home/bookworker06JAN1979/.nvm/nvm.sh && nvm use && npm run test:watch` |
| Frontend E2E tests | `cd front && source /home/bookworker06JAN1979/.nvm/nvm.sh && nvm use && npm run test:e2e` |
| Frontend E2E single test | `cd front && source /home/bookworker06JAN1979/.nvm/nvm.sh && nvm use && npx playwright test e2e/<file>.spec.ts --reporter=line` |
| Frontend E2E (with UI) | `cd front && source /home/bookworker06JAN1979/.nvm/nvm.sh && nvm use && npm run test:e2e:ui` |
| Migrate up | `cd back && ./src/scripts/xo/migrate-up.sh` |
| Migrate down | `cd back && ./src/scripts/xo/migrate-down.sh` |
| Migrate new | `cd back && ./src/scripts/xo/migrate-new.sh` |
| DB codegen (xo) | `cd back && ./src/scripts/xo/xo.sh goxus/xo.yaml` |
| shadcn project info | `cd front && npx shadcn@latest info --json` |
| shadcn component docs | `cd front && npx shadcn@latest docs <component>` |
| shadcn search registries | `cd front && npx shadcn@latest search -q \"<query>\"` |
| shadcn add component | `cd front && npx shadcn@latest add <component>` |

## 9. Skills

| Skills | Description |
|-------|-------------|
| [`e2e-write-then-test`](../.hermes/skills/custom/e2e-write-then-test/SKILL.md) | Write E2E test, run it, and only report success if it passes. Never announce a feature as done without a passing E2E test. |
| [`nextjs-turbopack-workspace-root`](/home/bookworker06JAN1979/Sources/hermes-skills/nodejs/nextjs-turbopack-workspace-root/SKILL.md) | Fix Next.js Turbopack workspace root warning — use `pnpm-workspace.yaml` marker instead of `turbopack.root` (which breaks the dev server). |