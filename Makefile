# Goxus — orchestrator Makefile
# ===============================
# Запуск backend и frontend из корня монорепозитория

BACK_DIR  := back
FRONT_DIR := front

BACK_PORT := 8080
FRONT_PORT := 3000

BACK_CONFIG ?= configs/local/config.yaml

BACK_CMD  := cd $(BACK_DIR) && go run ./src/cmd/goxus/... -runtype=service -config=$(BACK_CONFIG)
FRONT_CMD := cd $(FRONT_DIR) && . $(HOME)/.nvm/nvm.sh && nvm use && npm run dev

CHROME    := /usr/bin/google-chrome-stable
FRONT_URL := http://localhost:$(FRONT_PORT)
BACK_URL  := http://localhost:$(BACK_PORT)

# PostgreSQL
PG_PORT := 5432
PG_HOST := 127.0.0.1

.PHONY: help check-postgres run-back run-front dev dev-bg stop open \
        kill-back kill-front \
        test-back test-back-cover test-front test-front-e2e test

help:
	@echo "Доступные команды:"
	@echo "  make check-postgres — проверить/запустить PostgreSQL"
	@echo "  make run-back       — запустить backend (Go) в текущем терминале"
	@echo "  make run-front      — запустить frontend (Next.js) в текущем терминале"
	@echo "  make dev            — запустить PostgreSQL + backend + frontend + открыть Chrome"
	@echo "  make dev-bg         — запустить PostgreSQL + backend + frontend в фоне (без браузера)"
	@echo "  make stop           — остановить фоновые процессы backend и frontend"
	@echo "  make open           — открыть frontend в Chrome"
	@echo "  make test-back      — запустить Go-тесты (back)"
	@echo "  make test-back-cover — Go-тесты с покрытием (back)"
	@echo "  make test-front     — запустить Vitest-тесты (front)"
	@echo "  make test-front-e2e — запустить Playwright E2E (front)"
	@echo "  make test           — запустить test-back + test-front"
	@echo ""
	@echo "Порты: backend=$(BACK_PORT), frontend=$(FRONT_PORT), postgres=$(PG_PORT)"

# --- PostgreSQL ---

check-postgres:
	@if pg_isready -q -h $(PG_HOST) -p $(PG_PORT) 2>/dev/null; then \
		echo "PostgreSQL уже запущен на $(PG_HOST):$(PG_PORT)"; \
	else \
		echo "PostgreSQL не запущен. Запуск..."; \
		sudo systemctl start postgresql; \
		echo "Ожидание готовности PostgreSQL..."; \
		for i in $$(seq 1 15); do \
			if pg_isready -q -h $(PG_HOST) -p $(PG_PORT) 2>/dev/null; then \
				echo "PostgreSQL готов."; \
				break; \
			fi; \
			sleep 1; \
		done; \
		if ! pg_isready -q -h $(PG_HOST) -p $(PG_PORT) 2>/dev/null; then \
			echo "Ошибка: PostgreSQL не запустился за 15 секунд."; \
			exit 1; \
		fi; \
	fi

# --- Запуск в текущем терминале (foreground) ---

run-back: check-postgres
	@echo "Запуск backend на $(BACK_URL)..."
	$(BACK_CMD)

run-front:
	@echo "Запуск frontend на $(FRONT_URL)..."
	$(FRONT_CMD)

# --- Запуск в фоне + опционально браузер ---

dev: dev-bg open
	@echo ""
	@echo "Оба сервера запущены в фоне:"
	@echo "  Backend:   $(BACK_URL)"
	@echo "  Frontend:  $(FRONT_URL)"
	@echo "  PostgreSQL: $(PG_HOST):$(PG_PORT)"
	@echo ""
	@echo "  make stop  — остановить"

dev-bg: check-postgres
	@echo "Остановка предыдущих фоновых процессов (если есть)..."
	@$(MAKE) kill-back kill-front
	@sleep 1
	@echo "Запуск backend в фоне..."
	@nohup bash -c '$(BACK_CMD)' > /tmp/goxus-back.log 2>&1 & \
		echo $$! > /tmp/goxus-back.pid
	@echo "  PID: $$(cat /tmp/goxus-back.pid)"
	@echo "  Лог: /tmp/goxus-back.log"
	@sleep 2
	@echo "Запуск frontend в фоне..."
	@nohup bash -c '$(FRONT_CMD)' > /tmp/goxus-front.log 2>&1 & \
		echo $$! > /tmp/goxus-front.pid
	@echo "  PID: $$(cat /tmp/goxus-front.pid)"
	@echo "  Лог: /tmp/goxus-front.log"

# --- Принудительное завершение по PID файлу + порту ---

kill-back:
	@-kill $$(cat /tmp/goxus-back.pid 2>/dev/null) 2>/dev/null; true
	@-fuser -k $(BACK_PORT)/tcp >/dev/null 2>&1; true
	@rm -f /tmp/goxus-back.pid
	@# Ждём освобождения порта (макс 10 сек)
	@for i in $$(seq 1 10); do \
		if ! lsof -ti :$(BACK_PORT) >/dev/null 2>&1; then \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "  ⚠️  Порт $(BACK_PORT) не освободился за 10 сек" >&2

kill-front:
	@-kill $$(cat /tmp/goxus-front.pid 2>/dev/null) 2>/dev/null; true
	@-fuser -k $(FRONT_PORT)/tcp >/dev/null 2>&1; true
	@rm -f /tmp/goxus-front.pid
	@for i in $$(seq 1 10); do \
		if ! lsof -ti :$(FRONT_PORT) >/dev/null 2>&1; then \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "  ⚠️  Порт $(FRONT_PORT) не освободился за 10 сек" >&2

# --- Остановка фоновых процессов ---

stop:
	@$(MAKE) kill-back kill-front
	@echo "Backend остановлен"
	@echo "Frontend остановлен"

# --- Браузер ---

open:
	@echo "Открытие $(FRONT_URL) в Chrome..."
	$(CHROME) --new-window $(FRONT_URL) $(BACK_URL) &

# --- Тестирование ---

test-back:
	@echo "Запуск Go-тестов (back)..."
	cd $(BACK_DIR) && go test ./... -count=1

test-back-cover:
	@echo "Запуск Go-тестов с покрытием (back)..."
	cd $(BACK_DIR) && go test ./... -count=1 -coverprofile=c.out && go tool cover -func=c.out

test-front:
	@echo "Запуск Vitest-тестов (front)..."
	cd $(FRONT_DIR) && bash -c 'source $(HOME)/.nvm/nvm.sh && nvm use && npm test'

test-front-e2e:
	@echo "Остановка backend и frontend (если работают)..."
	@$(MAKE) kill-back kill-front
	@echo "Сброс goxus_e2e БД..."
	$(MAKE) -C $(BACK_DIR)/src/scripts/xo/goxus reset-e2e
	@sleep 2
	@echo "Запуск Playwright E2E (front)..."
	cd $(FRONT_DIR) && bash -c 'source $(HOME)/.nvm/nvm.sh && nvm use && NEXT_PUBLIC_API_URL=http://localhost:8081 npm run test:e2e'

test: test-back test-front test-front-e2e
	@echo "Все тесты пройдены."
