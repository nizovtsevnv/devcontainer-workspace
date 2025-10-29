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

	@# Проверить существует ли контейнер
	@if $(CONTAINER_RUNTIME) ps -a --format "{{.Names}}" | grep -q "^$(CONTAINER_NAME)$$"; then \
		$(call log-info,Контейнер уже существует); \
		if ! $(CONTAINER_RUNTIME) ps --format "{{.Names}}" | grep -q "^$(CONTAINER_NAME)$$"; then \
			$(call log-info,Запуск существующего контейнера...); \
			$(CONTAINER_RUNTIME) start $(CONTAINER_NAME) >/dev/null; \
		fi; \
	else \
		$(call log-info,Создание нового контейнера...); \
		if [ "$(CONTAINER_RUNTIME)" = "podman" ]; then \
			$(CONTAINER_RUNTIME) run -d \
				--name $(CONTAINER_NAME) \
				--userns=keep-id \
				--network=host \
				-v "$(WORKSPACE_ROOT):$(CONTAINER_WORKDIR):Z" \
				-w $(CONTAINER_WORKDIR) \
				-e INSIDE_DEVCONTAINER=1 \
				-e USER=developer \
				-e HOME=/home/developer \
				$(CONTAINER_IMAGE) \
				/bin/bash -c "trap 'exit 0' TERM; while true; do sleep 1; done" >/dev/null; \
		else \
			$(CONTAINER_RUNTIME) run -d \
				--name $(CONTAINER_NAME) \
				--network=host \
				-v "$(WORKSPACE_ROOT):$(CONTAINER_WORKDIR)" \
				-w $(CONTAINER_WORKDIR) \
				--user "$(HOST_UID):$(HOST_GID)" \
				-e INSIDE_DEVCONTAINER=1 \
				-e USER=developer \
				-e HOME=/home/developer \
				$(CONTAINER_IMAGE) \
				/bin/bash -c "trap 'exit 0' TERM; while true; do sleep 1; done" >/dev/null; \
		fi; \
	fi
	@$(call log-success,DevContainer запущен: $(CONTAINER_NAME))
	@printf "\n"
endif

## down: Остановка DevContainer
down:
ifeq ($(IS_INSIDE_CONTAINER),0)
	@$(call log-warning,Нельзя остановить контейнер изнутри)
else
	@$(call log-section,Остановка DevContainer)
	@if $(CONTAINER_RUNTIME) ps --format "{{.Names}}" | grep -q "^$(CONTAINER_NAME)$$"; then \
		$(CONTAINER_RUNTIME) stop $(CONTAINER_NAME) >/dev/null 2>&1; \
		$(CONTAINER_RUNTIME) rm $(CONTAINER_NAME) >/dev/null 2>&1; \
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
	@$(CONTAINER_RUNTIME) exec -it $(CONTAINER_NAME) /bin/bash
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
		$(CONTAINER_RUNTIME) exec $(CONTAINER_NAME) bash -c "$$COMMAND"; \
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
		$(CONTAINER_RUNTIME) exec $(CONTAINER_NAME) bash -c '\
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
