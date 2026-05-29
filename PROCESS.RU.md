# Goxus — Процесс разработки

## Структура репозитория

```
goxus/                          # Оркестратор (этот репозиторий)
├── .gitmodules                 # Ссылки на submodule back/ и front/
├── README.md                   # Документация оркестратора (EN)
├── README.RU.md                # Документация оркестратора (RU)
├── AGENTS.md                   # Контекст для AI-агентов
├── PROCESS.md                  # Процесс разработки (EN)
├── PROCESS.RU.md               # Процесс разработки (RU) — вы здесь
│
├── back/                       # Submodule → github.com/nobuenhombre/goxus.back
│   └── Go 1.26 + Gin + PostgreSQL + Wire DI + cron
│
└── front/                      # Submodule → github.com/nobuenhombre/goxus.front
    └── Next.js App Router + TypeScript + Tailwind v4 + shadcn/ui
```

**Три отдельных git-репозитория.** У каждого своя история, ветки, CI. Оркестратор хранит только pointer-коммиты (хеши коммитов submodule).

---

## Первоначальная настройка

```bash
# 1. Клонирование с submodule
git clone git@github.com:nobuenhombre/goxus.git
cd goxus
git submodule update --init --recursive

# 2. Зависимости бэкенда
cd back
make install        # или: go mod download
cd ..

# 3. Зависимости фронтенда
cd front
nvm use             # подхватывает версию из .nvmrc
npm install
cd ..
```

---

## Ежедневная разработка

### Две IDE, два проекта

| Компонент | IDE | Как открыть |
|-----------|-----|-------------|
| Бэкенд (back/) | **GoLand** | `File > Open > goxus/back/` |
| Фронтенд (front/) | **PhpStorm** | `File > Open > gохус/front/` |
| Оркестратор (корень) | Терминал / файловый менеджер | Открывать в IDE редко требуется |

Каждый submodule — это полностью независимый проект внутри своей IDE. JetBrains работает с submodules «из коробки» — никаких Makefile-трюков не нужно.

### Локальный запуск

```bash
# Терминал 1 — Бэкенд
cd back
make run          # или: go run ./src/cmd/goxus/...

# Терминал 2 — Фронтенд
cd front
npm run dev       # → http://localhost:3000
```

---

## Git Workflow

### Главное правило

**Сначала коммит в submodule, потом обновление pointer-коммита в оркестраторе.**

### Изменение кода бэкенда или фронтенда

```bash
# 1. Работаем в submodule как в самостоятельном репозитории
cd back          # или front/
git checkout -b feature/my-feature
# ... вносим изменения ...
git add -A
git commit -m "feat: add user registration endpoint"
git push origin feature/my-feature

# 2. Открываем PR в репозитории submodule (GitHub)
#    github.com/nobuenhombre/goxus.back (или goxus.front)
```

### Обновление pointer-коммита в оркестраторе

После слияния PR (или любого коммита в submodule):

```bash
# 3. Возвращаемся в оркестратор, обновляем pointer
cd goxus
git add back    # индексируем новый хеш коммита submodule
git commit -m "chore(back): update submodule to latest"
git push
```

Для pointer-обновления не нужен отдельный PR — коммитим прямо в main.

### Получение последних изменений

```bash
# Стянуть оркестратор + обновить все submodule
git pull --recurse-submodules

# Или, если уже стянули:
git submodule update --remote --merge
```

### Стратегия ветвления

- **Feature-ветки живут в репозиториях submodule** (goxus.back или goxus.front)
- `main` оркестратора всегда указывает на последний стабильный коммит каждого submodule
- Если фича затрагивает и бэкенд, и фронтенд: два PR (по одному в каждом submodule), затем обновление обоих pointer'ов в оркестраторе

---

## Типичный цикл разработки

```
1. Стянуть последнее: git pull --recurse-submodules
2. Переключиться на feature-ветку в back/ или front/
3. Писать код, тестировать, коммитить (в submodule)
4. Запушить ветку submodule, открыть PR на GitHub
5. После слияния: обновить pointer в оркестраторе
6. git push orchestrator main
```

---

## Шпаргалка по командам

```bash
# Управление submodule
git submodule update --init --recursive   # клонировать/обновить все submodule
git submodule update --remote             # обновить до последних коммитов upstream
git submodule foreach 'git status'        # выполнить команду в каждом submodule

# Бэкенд (Go)
cd back && make run                       # dev-сервер
cd back && make test                      # запустить тесты
cd back && make build                     # собрать бинарник

# Фронтенд (Next.js)
cd front && npm run dev                   # dev-сервер (localhost:3000)
cd front && npm run build                 # production-сборка
cd front && npm run lint                  # проверка линтером

# Общее
git pull --recurse-submodules             # стянуть всё
```

---

## CI/CD

У каждого submodule свой CI (GitHub Actions). У оркестратора CI нет — он только контейнер для pointer-коммитов и документации.

---

---

## Пример из реальной работы: изменение `.gitignore` в `front`

В этом примере — точные шаги из реальной сессии. У пользователя **два клона** front-репозитория:

| Клон | Путь | Назначение |
|------|------|------------|
| Отдельный | `~/Sources/golang.app/goxus.front/` | Самостоятельный репозиторий для работы |
| Submodule | `goxus/front/` | Submodule внутри оркестратора |

Оба указывают на один remote: `github.com/nobuenhombre/goxus.front.git`

### Что произошло

Пользователь добавил `.idea` в `front/.gitignore` в отдельном клоне.

### Пошагово

**Шаг 1 — Проверить, что изменилось в отдельном репозитории**

```bash
cd ~/Sources/golang.app/goxus.front
git diff
```

Показывает:
```diff
+.idea
+```

**Шаг 2 — Закоммитить и запушить из отдельного репозитория**

```bash
git add .gitignore
git commit -m "chore: add .idea to .gitignore"
git push
```

> **Гвоздь:** Если отдельный клон отстал от remote (потому что раньше пушили из submodule), push будет отклонён:
> ```
> ! [rejected] main -> main (fetch first)
> ```
>
> Решение: pull с rebase, затем push:
> ```bash
> git pull --rebase origin main
> git push
> ```

**Шаг 3 — Стянуть новый коммит в submodule**

```bash
cd /путь/к/goxus/front
git pull origin main
```

**Шаг 4 — Обновить pointer в оркестраторе**

```bash
cd /путь/к/goxus
git add front
git commit -m "chore(front): update submodule — .gitignore now excludes .idea"
git push
```

### Выводы

1. **Коммитим в репозитории submodule в первую очередь** — неважно, через submodule (`goxus/front/`) или через отдельный клон (`~/.../goxus.front/`). Пушим на GitHub.
2. **Проверяем, что submodule-клон содержит последний коммит** — `git pull` внутри `goxus/front/`.
3. **Обновляем pointer оркестратора** — `git add front` в `goxus/` индексирует новый хеш, затем коммит и push.