# Goxus — Development Process

## Repository Structure

```
goxus/                          # Orchestrator (this repo)
├── .gitmodules                 # Links to back/ and front/ submodules
├── README.md                   # Orchestrator-level docs
├── AGENTS.md                   # AI agent context
├── PROCESS.md                  # You are here
│
├── back/                       # Submodule → github.com/nobuenhombre/goxus.back
│   └── Go 1.26 + Gin + PostgreSQL + Wire DI + cron
│
└── front/                      # Submodule → github.com/nobuenhombre/goxus.front
    └── Next.js App Router + TypeScript + Tailwind v4 + shadcn/ui
```

**Three separate git repos.** Each has its own history, branches, CI. The orchestrator only tracks submodule pointers (commit hashes).

---

## First-Time Setup

```bash
# 1. Clone with submodules
git clone git@github.com:nobuenhombre/goxus.git
cd goxus
git submodule update --init --recursive

# 2. Backend dependencies
cd back
make install        # or: go mod download
cd ..

# 3. Frontend dependencies
cd front
nvm use             # picks version from .nvmrc
npm install
cd ..
```

---

## Daily Development

### Two IDEs, Two Projects

| Component | IDE | How to Open |
|-----------|-----|-------------|
| Backend (back/) | **GoLand** | `File > Open > goxus/back/` |
| Frontend (front/) | **PhpStorm** | `File > Open > goxus/front/` |
| Orchestrator (root) | Terminal / file manager | Rarely needs IDE |

Each submodule is a fully independent project inside its IDE. JetBrains handles this natively — no Makefile tricks needed.

### Running Locally

```bash
# Terminal 1 — Backend
cd back
make run          # or: go run ./src/cmd/goxus/...

# Terminal 2 — Frontend
cd front
npm run dev       # → http://localhost:3000
```

---

## Git Workflow

### The Core Rule

**Commit inside the submodule first, then commit the pointer in the orchestrator.**

### Changing Backend or Frontend Code

```bash
# 1. Work in the submodule as if it were a standalone repo
cd back          # or front/
git checkout -b feature/my-feature
# ... make changes ...
git add -A
git commit -m "feat: add user registration endpoint"
git push origin feature/my-feature

# 2. Open a PR on the submodule repo (GitHub)
#    github.com/nobuenhombre/goxus.back (or goxus.front)
```

### Updating the Orchestrator Pointer

After the submodule PR is merged (or after any commit in the submodule):

```bash
# 3. Back in the orchestrator, update the pointer
cd goxus
git add back    # stage the new submodule commit hash
git commit -m "chore(back): update submodule to latest"
git push
```

No separate PR needed for the orchestrator if it's just a pointer update — commit directly to main.

### Pulling Latest Changes

```bash
# Pull orchestrator + update all submodules
git pull --recurse-submodules

# Or, if already pulled:
git submodule update --remote --merge
```

### Branching Strategy

- **Feature branches live in the submodule repos** (goxus.back or goxus.front)
- The orchestrator's `main` branch always points to the latest stable commit of each submodule
- If a feature touches both back and front: two PRs (one in each submodule), then update both pointers in the orchestrator

---

## Typical Development Cycle

```
1. Pull latest: git pull --recurse-submodules
2. Checkout feature branch in back/ or front/
3. Code, test, commit (in submodule)
4. Push submodule branch, open PR on GitHub
5. After merge: update submodule pointer in orchestrator
6. git push orchestrator main
```

---

## Commands Cheat Sheet

```bash
# Submodule management
git submodule update --init --recursive   # clone/pull all submodules
git submodule update --remote             # update to latest upstream
git submodule foreach 'git status'        # run command in each submodule

# Backend (Go)
cd back && make run                       # dev server
cd back && make test                      # run tests
cd back && make build                     # build binary

# Frontend (Next.js)
cd front && npm run dev                   # dev server (localhost:3000)
cd front && npm run build                 # production build
cd front && npm run lint                  # lint check

# General
git pull --recurse-submodules             # pull everything
```

---

## CI/CD Note

Each submodule has its own CI (GitHub Actions). The orchestrator has no CI — it's just a container for submodule pointers and documentation.
