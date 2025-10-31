# ===================================
# Базовые команды управления средой
# ===================================

.PHONY: up down sh exec

## up: Запуск DevContainer
up:
ifeq ($(IS_INSIDE_CONTAINER),0)
	@$(call log-warning,Уже внутри контейнера)
else
	@$(call check-command,$(CONTAINER_RUNTIME))

	@if $(CONTAINER_RUNTIME) ps --format "{{.Names}}" | grep -q "^$(CONTAINER_NAME)$$"; then \
		$(call log-info,Контейнер уже запущен); \
	elif $(CONTAINER_RUNTIME) ps -a --format "{{.Names}}" | grep -q "^$(CONTAINER_NAME)$$"; then \
		$(call log-spinner,Запуск существующего контейнера,$(CONTAINER_RUNTIME) start $(CONTAINER_NAME) >/dev/null 2>&1); \
		$(call log-success,Контейнер запущен); \
	else \
		$(call ensure-image-available); \
		$(call log-spinner,Создание контейнера ($(CONTAINER_NAME)),$(MAKE) --no-print-directory up-silent); \
		$(call log-success,Контейнер запущен); \
	fi
	@printf "\n"
endif

# Тихий запуск (для внутреннего использования)
.PHONY: up-silent
up-silent:
	@if $(CONTAINER_RUNTIME) ps -a --format "{{.Names}}" | grep -q "^$(CONTAINER_NAME)$$"; then \
		if ! $(CONTAINER_RUNTIME) ps --format "{{.Names}}" | grep -q "^$(CONTAINER_NAME)$$"; then \
			$(CONTAINER_RUNTIME) start $(CONTAINER_NAME) >/dev/null 2>&1; \
		fi; \
	else \
		if [ "$(CONTAINER_RUNTIME)" = "podman" ]; then \
			$(CONTAINER_RUNTIME) run -d --name $(CONTAINER_NAME) \
				--userns=keep-id:uid=$(HOST_UID),gid=$(HOST_GID) \
				--network=host \
				-v "$(WORKSPACE_ROOT):$(CONTAINER_WORKDIR)" \
				-w $(CONTAINER_WORKDIR) \
				-e INSIDE_DEVCONTAINER=1 -e USER=developer -e HOME=/home/developer \
				$(CONTAINER_IMAGE) \
				/bin/bash -c "trap 'exit 0' TERM; while true; do sleep 1; done" >/dev/null 2>&1; \
		else \
			$(CONTAINER_RUNTIME) run -d --name $(CONTAINER_NAME) \
				--user $(HOST_UID):$(HOST_GID) \
				--network=host \
				-v "$(WORKSPACE_ROOT):$(CONTAINER_WORKDIR)" \
				-w $(CONTAINER_WORKDIR) \
				-e INSIDE_DEVCONTAINER=1 -e USER=developer -e HOME=/home/developer \
				$(CONTAINER_IMAGE) \
				/bin/bash -c "trap 'exit 0' TERM; while true; do sleep 1; done" >/dev/null 2>&1; \
		fi; \
	fi

## down: Остановка DevContainer
down:
ifeq ($(IS_INSIDE_CONTAINER),0)
	@$(call log-warning,Нельзя остановить контейнер изнутри)
else
	@if $(CONTAINER_RUNTIME) ps --format "{{.Names}}" | grep -q "^$(CONTAINER_NAME)$$"; then \
		if command -v gum >/dev/null 2>&1; then \
			gum spin --spinner dot --title "Остановка контейнера ($(CONTAINER_NAME))" -- sh -c '$(CONTAINER_RUNTIME) stop $(CONTAINER_NAME) >/dev/null 2>&1 && $(CONTAINER_RUNTIME) rm $(CONTAINER_NAME) >/dev/null 2>&1'; \
		else \
			printf "⠙ Остановка контейнера ($(CONTAINER_NAME))...\n"; \
			$(CONTAINER_RUNTIME) stop $(CONTAINER_NAME) >/dev/null 2>&1; \
			$(CONTAINER_RUNTIME) rm $(CONTAINER_NAME) >/dev/null 2>&1; \
		fi; \
		$(call log-success,Контейнер остановлен); \
	else \
		$(call log-info,Контейнер уже остановлен); \
	fi
endif
# ВАЖНО: Здесь НЕ используется log-spinner, потому что:
# 1. При отсутствии gum на хосте log-spinner использует gum из контейнера
# 2. Это приводит к выполнению команд stop/rm ВНУТРИ контейнера (не работает)
# 3. Команды stop/rm должны выполняться на ХОСТЕ
# 4. Поэтому используем прямую проверку gum на хосте с fallback на статический спиннер

## sh: Интерактивный shell в DevContainer
sh:
ifeq ($(IS_INSIDE_CONTAINER),0)
	@$(call log-warning,Уже внутри контейнера)
else
	@$(call ensure-devenv-ready)
	@$(CONTAINER_RUNTIME) exec -it $(CONTAINER_NAME) /bin/bash
endif

## exec: Выполнение команды в DevContainer
## Использование:
##   make exec 'команда с && и другими операторами'
##   CMD='команда' make exec
exec:
	@$(call ensure-devenv-ready)
	@CMD_VALUE='$(CMD)'; \
	if [ -n "$$CMD_VALUE" ]; then \
		COMMAND="$$CMD_VALUE"; \
	else \
		COMMAND="$(filter-out exec,$(MAKECMDGOALS))"; \
	fi; \
	if [ -z "$$COMMAND" ]; then \
		$(call log-error,Использование: make exec 'команда' или CMD='команда' make exec); \
		exit 1; \
	fi; \
	if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		bash -c "$$COMMAND"; \
	else \
		$(CONTAINER_RUNTIME) exec -w $(CONTAINER_WORKDIR) $(CONTAINER_NAME) bash -c "$$COMMAND"; \
	fi

## exec-interactive: Выполнение интерактивной команды в DevContainer (с TTY)
## Использование:
##   make exec-interactive 'команда'
##   CMD='команда' make exec-interactive
.PHONY: exec-interactive
exec-interactive:
	@$(call ensure-devenv-ready)
	@CMD_VALUE='$(CMD)'; \
	if [ -n "$$CMD_VALUE" ]; then \
		COMMAND="$$CMD_VALUE"; \
	else \
		COMMAND="$(filter-out exec-interactive,$(MAKECMDGOALS))"; \
	fi; \
	if [ -z "$$COMMAND" ]; then \
		$(call log-error,Использование: make exec-interactive 'команда' или CMD='команда' make exec-interactive); \
		exit 1; \
	fi; \
	if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		bash -c "$$COMMAND"; \
	else \
		$(CONTAINER_RUNTIME) exec -it -w $(CONTAINER_WORKDIR) $(CONTAINER_NAME) bash -c "$$COMMAND"; \
	fi

## version: Вывод версий инструментов DevContainer и модулей
.PHONY: version core-version
version: core-version
core-version:
	@$(call ensure-devenv-ready)
	@$(call log-info,Версии инструментов в контейнере:)
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		docker_ver=$$(docker --version 2>/dev/null | awk '{print $$3}' | sed 's/,$$//') || docker_ver="не установлен"; \
		git_ver=$$(git --version 2>/dev/null | awk '{print $$3}') || git_ver="не установлен"; \
		node_ver=$$(node --version 2>/dev/null | sed 's/^v//') || node_ver="не установлен"; \
		php_ver=$$(php --version 2>/dev/null | head -n1 | awk '{print $$2}') || php_ver="не установлен"; \
		rust_ver=$$(rustc --version 2>/dev/null | awk '{print $$2}') || rust_ver="не установлен"; \
		printf '%s\n' "Docker<COL>$$docker_ver<ROW>Git<COL>$$git_ver<ROW>Node.js<COL>$$node_ver<ROW>PHP<COL>$$php_ver<ROW>Rust<COL>$$rust_ver" | { $(call print-table,16); }; \
	else \
		$(CONTAINER_RUNTIME) exec $(CONTAINER_NAME) bash -c ' \
			docker_ver=$$(docker --version 2>/dev/null | awk '\''{print $$3}'\'' | sed '\''s/,$$//'\'' ) || docker_ver="не установлен"; \
			git_ver=$$(git --version 2>/dev/null | awk '\''{print $$3}'\'') || git_ver="не установлен"; \
			node_ver=$$(node --version 2>/dev/null | sed '\''s/^v//'\'') || node_ver="не установлен"; \
			php_ver=$$(php --version 2>/dev/null | head -n1 | awk '\''{print $$2}'\'') || php_ver="не установлен"; \
			rust_ver=$$(rustc --version 2>/dev/null | awk '\''{print $$2}'\'') || rust_ver="не установлен"; \
			printf "%s\n" "Docker<COL>$$docker_ver<ROW>Git<COL>$$git_ver<ROW>Node.js<COL>$$node_ver<ROW>PHP<COL>$$php_ver<ROW>Rust<COL>$$rust_ver" \
		' | { $(call print-table,16); }; \
	fi
	@if [ -n "$(MODULE_NAMES)" ]; then \
		printf "\n"; \
		$(call log-info,Модули проекта:); \
		module_data=""; \
		for module in $$(echo "$(MODULE_NAMES)" | tr ' ' '\n' | sort); do \
			module_path="$(MODULES_DIR)/$$module"; \
			tech_info=$$($(call get-module-info,$$module_path)); \
			if [ -n "$$tech_info" ]; then \
				[ -n "$$module_data" ] && module_data="$$module_data<ROW>"; \
				module_data="$$module_data$$module<COL>$$tech_info"; \
			fi; \
		done; \
		if [ -n "$$module_data" ]; then \
			printf '%s\n' "$$module_data" | { $(call print-table,16); }; \
		fi; \
	fi

# Подавление ошибок для аргументов после exec --
%:
	@:
