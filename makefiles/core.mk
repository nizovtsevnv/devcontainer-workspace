# ===================================
# Базовые команды управления средой
# ===================================

.PHONY: up down sh exec version

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
	@# Для Podman: исправить права если они принадлежат subuid namespace
	@if [ "$(CONTAINER_RUNTIME)" = "podman" ]; then \
		CURRENT_OWNER=$$(stat -c '%u' . 2>/dev/null || echo "$(HOST_UID)"); \
		if [ "$$CURRENT_OWNER" != "$(HOST_UID)" ] && [ "$$CURRENT_OWNER" != "0" ]; then \
			printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) Исправление прав доступа (владелец: $$CURRENT_OWNER → $(HOST_UID))...\n"; \
			if sudo -n chown -R $(HOST_UID):$(HOST_GID) . 2>/dev/null; then \
				printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Права исправлены\n"; \
			else \
				printf "  $(COLOR_WARNING)⚠$(COLOR_RESET) Требуется sudo: chown -R $(HOST_UID):$(HOST_GID) .\n"; \
			fi; \
		fi; \
	fi
	@$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) up -d
	@$(call log-success,DevContainer запущен: $(DEVCONTAINER_SERVICE))
	@printf "\n"
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
.PHONY: core-version
core-version:
	@$(call ensure-container-running)
	@$(call log-section,Версии инструментов среды разработки)
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		docker_ver=$$(docker --version 2>/dev/null | awk '{print $$3}' | sed 's/,$$//') || docker_ver="не установлен"; \
		git_ver=$$(git --version 2>/dev/null | awk '{print $$3}') || git_ver="не установлен"; \
		node_ver=$$(node --version 2>/dev/null | sed 's/^v//') || node_ver="не установлен"; \
		php_ver=$$(php --version 2>/dev/null | head -n1 | awk '{print $$2}') || php_ver="не установлен"; \
		rust_ver=$$(rustc --version 2>/dev/null | awk '{print $$2}') || rust_ver="не установлен"; \
		printf "  %-20s $$docker_ver\n" "Docker"; \
		printf "  %-20s $$git_ver\n" "Git"; \
		printf "  %-20s $$node_ver\n" "Node.js"; \
		printf "  %-20s $$php_ver\n" "PHP"; \
		printf "  %-20s $$rust_ver\n" "Rust"; \
	else \
		$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) exec -T $(DEVCONTAINER_SERVICE) bash -c '\
			docker_ver=$$(docker --version 2>/dev/null | awk "{print \$$3}" | sed "s/,\$$//") || docker_ver="не установлен"; \
			git_ver=$$(git --version 2>/dev/null | awk "{print \$$3}") || git_ver="не установлен"; \
			node_ver=$$(node --version 2>/dev/null | sed "s/^v//") || node_ver="не установлен"; \
			php_ver=$$(php --version 2>/dev/null | head -n1 | awk "{print \$$2}") || php_ver="не установлен"; \
			rust_ver=$$(rustc --version 2>/dev/null | awk "{print \$$2}") || rust_ver="не установлен"; \
			printf "  %-20s $$docker_ver\n" "Docker"; \
			printf "  %-20s $$git_ver\n" "Git"; \
			printf "  %-20s $$node_ver\n" "Node.js"; \
			printf "  %-20s $$php_ver\n" "PHP"; \
			printf "  %-20s $$rust_ver\n" "Rust"'; \
	fi
	@if [ -n "$(MODULE_NAMES)" ]; then \
		printf "\n"; \
		$(call log-section,Модули проекта); \
		for module in $$(echo "$(MODULE_NAMES)" | tr ' ' '\n' | sort); do \
			module_path="$(MODULES_DIR)/$$module"; \
			versions=""; \
			\
			if [ -f "$$module_path/Cargo.toml" ]; then \
				rust_ver=$$(grep '^version = ' "$$module_path/Cargo.toml" | head -1 | sed 's/version = "\(.*\)"/\1/' | xargs); \
				if [ -n "$$rust_ver" ]; then \
					versions="$$versions$$rust_ver (Rust)"; \
				fi; \
			fi; \
			\
			if [ -f "$$module_path/package.json" ]; then \
				node_ver=$$(grep '"version":' "$$module_path/package.json" | head -1 | sed 's/.*"version": "\(.*\)".*/\1/' | xargs); \
				if [ -n "$$node_ver" ]; then \
					[ -n "$$versions" ] && versions="$$versions, "; \
					versions="$$versions$$node_ver (Node.js)"; \
				fi; \
			fi; \
			\
			if [ -f "$$module_path/composer.json" ]; then \
				php_ver=$$(grep '"version":' "$$module_path/composer.json" | head -1 | sed 's/.*"version": "\(.*\)".*/\1/' | xargs); \
				if [ -n "$$php_ver" ]; then \
					[ -n "$$versions" ] && versions="$$versions, "; \
					versions="$$versions$$php_ver (PHP)"; \
				fi; \
			fi; \
			\
			if [ -f "$$module_path/pyproject.toml" ]; then \
				python_ver=$$(grep '^version = ' "$$module_path/pyproject.toml" | head -1 | sed 's/version = "\(.*\)"/\1/' | xargs); \
				if [ -n "$$python_ver" ]; then \
					[ -n "$$versions" ] && versions="$$versions, "; \
					versions="$$versions$$python_ver (Python)"; \
				fi; \
			fi; \
			\
			if [ -n "$$versions" ]; then \
				printf "  %-20s $$versions\n" "$$module"; \
			else \
				printf "  $$module\n"; \
			fi; \
		done; \
	fi

# Подавление ошибок для аргументов после exec --
%:
	@:
