# AGENTS.md — goxus Orchestrator Monorepo

## 1. Overview

**goxus** is a full-stack web application monorepo orchestrated by
`github.com/nobuenhombre/goxus`. The orchestrator repo contains **no Go code** and
**no Next.js code** directly — it is purely a submodule wrapper that aggregates
two sibling repositories:

| Repository | URL | Role |
|---|---|---|
| orchestrator | `github.com/nobuenhombre/goxus` | Root `.gitmodules`, docs, CI wiring |
| backend | `github.com/nobuenhombre/goxus.back` | Go 1.26 backend (`back/`) |
| frontend | `github.com/nobuenhombre/goxus.front` | Next.js frontend (`front/`) |

Each submodule tracks a **pinned commit** — there is no branch-based "latest"
semantic; updates are explicit.

## 2. Project Layout

```
goxus/
├── .gitmodules          # submodule definitions
├── AGENTS.md            # this file
├── back/  ──> goxus.back   (Go backend)
├── front/ ──> goxus.front  (Next.js frontend)
└── ... orchestrator-level docs / CI configs
```

The `.gitmodules` config looks like:

```ini
[submodule "back"]
  path = back
  url = https://github.com/nobuenhombre/goxus.back

[submodule "front"]
  path = front
  url = https://github.com/nobuenhombre/goxus.front
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
| Backend language | Go 1.26 |
| Backend framework | Gin HTTP API |
| Backend database | PostgreSQL |
| Backend ORM / codegen | xo (type-safe Go codegen from SQL) |
| Backend migrations | golang-migrate |
| Backend DI | Wire |
| Backend scheduling | cron jobs |
| Frontend framework | Next.js (App Router) |
| Frontend language | TypeScript |
| Frontend styling | Tailwind CSS v4 |
| Frontend UI library | shadcn/ui |

## 5. Gotchas

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

## 6. Commands

| Action | Command |
|---|---|
| Clone with submodules | `git clone --recurse-submodules <repo-url>` |
| Init submodules | `git submodule update --init` |
| Update to pinned SHA | `git submodule update --recursive` |
| Update to latest remote | `git submodule update --remote --merge` |
| Run command in each | `git submodule foreach '<command>'` |
| Pull + submodules | `git pull --recurse-submodules` |
| Status of submodules | `git submodule status` |
