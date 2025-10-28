# ===================================
# Переиспользуемые функции
# ===================================

# Функции логирования
# Использование: $(call log-info,message)

define log-info
	printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) %s\n" "$(1)"
endef

define log-success
	printf "$(COLOR_SUCCESS)✓ OK:$(COLOR_RESET) %s\n" "$(1)"
endef

define log-warning
	printf "$(COLOR_WARNING)⚠ WARNING:$(COLOR_RESET) %s\n" "$(1)"
endef

define log-error
	printf "$(COLOR_ERROR)✗ ERROR:$(COLOR_RESET) %s\n" "$(1)" >&2
endef

define log-section
	printf "$(COLOR_SECTION)▶ %s$(COLOR_RESET)\n" "$(1)"
endef

# Проверка обязательной переменной
# Использование: $(call require-var,VAR_NAME)
define require-var
	if [ -z "$($(1))" ]; then \
		printf "$(COLOR_ERROR)✗ ERROR:$(COLOR_RESET) %s\n" "Переменная $(1) не определена" >&2; \
		exit 1; \
	fi
endef

# Запрос подтверждения (дефолт: NO)
# Использование: $(call ask-confirm,message)
define ask-confirm
	printf "$(COLOR_WARNING)$(1)? [yes/NO]:$(COLOR_RESET) "; \
	read answer; \
	if [ "$$answer" != "yes" ] && [ "$$answer" != "y" ] && [ "$$answer" != "Y" ]; then \
		printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) %s\n" "Отменено"; \
		exit 0; \
	fi
endef

# Запрос подтверждения (дефолт: YES)
# Использование: $(call ask-confirm-default-yes,message)
define ask-confirm-default-yes
	printf "$(COLOR_WARNING)$(1)? [YES/no]:$(COLOR_RESET) "; \
	read answer; \
	if [ "$$answer" = "no" ] || [ "$$answer" = "n" ] || [ "$$answer" = "N" ]; then \
		printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) %s\n" "Отменено"; \
		exit 0; \
	fi
endef

# Проверка существования команды
# Использование: $(call check-command,command-name)
define check-command
	command -v $(1) >/dev/null 2>&1 || \
		(printf "$(COLOR_ERROR)✗ ERROR:$(COLOR_RESET) %s\n" "Команда '$(1)' не найдена" >&2; exit 1)
endef

# Запуск контейнера если не запущен
# Использование: @$(call ensure-container-running)
define ensure-container-running
	if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		: ; \
	elif $(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) ps 2>/dev/null | grep -q "Up"; then \
		: ; \
	else \
		$(MAKE) up; \
	fi
endef

# Вывод команд в табличном формате (для help)
# Использование: $(call print-commands-table,pattern)
# Пример: $(call print-commands-table,"^## (init|up|down):")
define print-commands-table
	grep -hE $(1) $(MAKEFILE_LIST) | \
		sed 's/^## //' | \
		sort | \
		awk 'BEGIN {FS = ": "}; {printf "  $(COLOR_SUCCESS)make %-16s$(COLOR_RESET) %s\n", $$1, $$2}'
endef

# Обёртка для container compose команд
# Добавляет --in-pod false для Podman чтобы избежать проблем с user namespace mapping
# Использование: $(call container-compose,up -d) или $(call container-compose,down)
define container-compose
	if [ "$(CONTAINER_RUNTIME)" = "podman" ]; then \
		$(CONTAINER_RUNTIME) compose --in-pod false -f $(COMPOSE_FILE) $(1); \
	else \
		$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) $(1); \
	fi
endef
