# ===================================
# Базовые команды управления средой
# ===================================

.PHONY: init up down sh exec version

## init: Интерактивная инициализация проекта
init:
	@$(call log-section,Инициализация workspace)
	@git submodule update --init --recursive 2>/dev/null && $(call log-success,Субмодули инициализированы) || true
	@$(call ask-confirm-default-yes,Запустить DevContainer) && $(MAKE) up || true
	@$(call log-success,Инициализация завершена)

## up: Запуск DevContainer
up:
ifeq ($(IS_INSIDE_CONTAINER),0)
	@$(call log-warning,Уже внутри контейнера)
else
	@$(call log-section,Запуск DevContainer)
	@$(call check-command,$(CONTAINER_RUNTIME))
	@if [ ! -f "$(COMPOSE_FILE)" ]; then \
		$(call log-error,Файл $(COMPOSE_FILE) не найден); \
		exit 1; \
	fi
	@$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) up -d
	@$(call log-success,DevContainer запущен: $(DEVCONTAINER_SERVICE))
endif

## down: Остановка DevContainer
down:
ifeq ($(IS_INSIDE_CONTAINER),0)
	@$(call log-warning,Нельзя остановить контейнер изнутри)
else
	@$(call log-section,Остановка DevContainer)
	@if $(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) ps 2>/dev/null | grep -q "Up"; then \
		$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) down; \
		$(call log-success,DevContainer остановлен); \
	else \
		$(call log-warning,DevContainer уже остановлен); \
	fi
endif

## sh: Интерактивный shell в DevContainer
sh:
ifeq ($(IS_INSIDE_CONTAINER),0)
	@$(call log-warning,Уже внутри контейнера)
else
	@$(call ensure-container-running)
	@$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) exec $(DEVCONTAINER_SERVICE) /bin/bash
endif

## exec: Выполнение команды в DevContainer
## Использование:
##   make exec 'команда с && и другими операторами'
##   CMD='команда' make exec
exec:
	@$(call ensure-container-running)
	@if [ -n "$(CMD)" ]; then \
		COMMAND="$(CMD)"; \
	else \
		COMMAND="$(filter-out exec,$(MAKECMDGOALS))"; \
	fi; \
	if [ -z "$$COMMAND" ]; then \
		printf "\033[0;31m✗ ERROR:\033[0m %s\n" "Использование: make exec 'команда' или CMD='команда' make exec" >&2; \
		exit 1; \
	fi; \
	if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		bash -c "$$COMMAND"; \
	else \
		$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) exec -T $(DEVCONTAINER_SERVICE) bash -c "$$COMMAND"; \
	fi

## version: Вывод версий инструментов DevContainer и модулей
version:
	@$(call ensure-container-running)
	@$(call log-section,Версии инструментов)
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		node --version 2>/dev/null | sed 's/^/  Node.js:  /' || echo "  Node.js:  не установлен"; \
		php --version 2>/dev/null | head -n1 | sed 's/^/  PHP:      /' || echo "  PHP:      не установлен"; \
		rustc --version 2>/dev/null | sed 's/^/  Rust:     /' || echo "  Rust:     не установлен"; \
		docker --version 2>/dev/null | sed 's/^/  Docker:   /' || echo "  Docker:   не установлен"; \
		git --version 2>/dev/null | sed 's/^/  Git:      /' || echo "  Git:      не установлен"; \
	else \
		$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) exec -T $(DEVCONTAINER_SERVICE) bash -c '\
			node --version 2>/dev/null | sed "s/^/  Node.js:  /" || echo "  Node.js:  не установлен"; \
			php --version 2>/dev/null | head -n1 | sed "s/^/  PHP:      /" || echo "  PHP:      не установлен"; \
			rustc --version 2>/dev/null | sed "s/^/  Rust:     /" || echo "  Rust:     не установлен"; \
			docker --version 2>/dev/null | sed "s/^/  Docker:   /" || echo "  Docker:   не установлен"; \
			git --version 2>/dev/null | sed "s/^/  Git:      /" || echo "  Git:      не установлен"'; \
	fi
	@if [ -n "$(MODULE_NAMES)" ]; then \
		$(call log-section,Модули проекта); \
		for module in $(MODULE_NAMES); do \
			printf "  • $$module\n"; \
		done; \
	fi

# Подавление ошибок для аргументов после exec --
%:
	@:
