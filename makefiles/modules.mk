# ===================================
# Динамические команды модулей
# ===================================

# Получение списка имён модулей (извлечь basename из путей)
MODULE_NAMES := $(notdir $(ALL_MODULES))

# Известные пакетные менеджеры
KNOWN_PACKAGE_MANAGERS := npm yarn pnpm bun pip poetry pipenv uv composer cargo

# Проверка: первый аргумент командной строки - имя модуля?
FIRST_GOAL := $(firstword $(MAKECMDGOALS))
SECOND_GOAL := $(word 2,$(MAKECMDGOALS))
REST_GOALS := $(wordlist 3,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

# Если первый аргумент - имя модуля
ifneq ($(filter $(FIRST_GOAL),$(MODULE_NAMES)),)
  MODULE_NAME := $(FIRST_GOAL)
  MODULE_PATH := $(MODULES_DIR)/$(MODULE_NAME)

  # Определить технологии модуля
  MODULE_TECH := $(call detect-module-tech,$(MODULE_PATH))

  # Если есть второй аргумент
  ifneq ($(SECOND_GOAL),)
    # Проверить, является ли второй аргумент пакетным менеджером
    ifneq ($(filter $(SECOND_GOAL),$(KNOWN_PACKAGE_MANAGERS)),)
      # Это команда пакетного менеджера
      PACKAGE_MANAGER := $(SECOND_GOAL)
      PM_COMMAND := $(REST_GOALS)

      # Создать target для модуля с пакетным менеджером
      .PHONY: $(MODULE_NAME)
      $(MODULE_NAME):
	@$(call ensure-container-running)
	@printf "\\n$(COLOR_SECTION)▶ Модуль $(MODULE_NAME): $(PACKAGE_MANAGER) $(PM_COMMAND)$(COLOR_RESET)\\n"
	@if [ -z "$(PM_COMMAND)" ]; then \
		printf "$(COLOR_ERROR)✗ ERROR:$(COLOR_RESET) %s\\n" "Использование: make $(MODULE_NAME) $(PACKAGE_MANAGER) <команда>" >&2; \
		exit 1; \
	fi; \
	if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		cd "$(MODULE_PATH)" && $(PACKAGE_MANAGER) $(PM_COMMAND); \
	else \
		$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) exec -T $(DEVCONTAINER_SERVICE) \
			bash -c "cd $(DEVCONTAINER_WORKDIR)/$(MODULE_PATH) && $(PACKAGE_MANAGER) $(PM_COMMAND)"; \
	fi

      # Подавить ошибки для остальных аргументов
      .PHONY: $(SECOND_GOAL) $(REST_GOALS)
      $(SECOND_GOAL):
	@:
      $(REST_GOALS):
	@:

    else
      # Второй аргумент - не пакетный менеджер
      # Проверить, есть ли Makefile в модуле
      ifneq ($(wildcard $(MODULE_PATH)/Makefile),)
        # Есть Makefile - передать команду в него
        MODULE_CMD := $(SECOND_GOAL)

        .PHONY: $(MODULE_NAME)
        $(MODULE_NAME):
	@$(call ensure-container-running)
	@printf "\\n$(COLOR_SECTION)▶ Модуль $(MODULE_NAME): $(MODULE_CMD)$(COLOR_RESET)\\n"
	@cd "$(MODULE_PATH)" && $(MAKE) $(MODULE_CMD)

        # Подавить ошибки для второго аргумента
        .PHONY: $(MODULE_CMD)
        $(MODULE_CMD):
	@:
      else
        # Нет Makefile и команда не является пакетным менеджером
        .PHONY: $(MODULE_NAME)
        $(MODULE_NAME):
	@printf "$(COLOR_ERROR)✗ ERROR:$(COLOR_RESET) %s\\n" "Неизвестная команда '$(SECOND_GOAL)' для модуля $(MODULE_NAME)" >&2
	@printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) %s\\n" "Используйте: make $(MODULE_NAME) <package-manager> <команда>"
	@printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) %s\\n" "Доступные менеджеры: $(KNOWN_PACKAGE_MANAGERS)"
	@exit 1

        # Подавить ошибки для второго аргумента
        .PHONY: $(SECOND_GOAL)
        $(SECOND_GOAL):
	@:
      endif
    endif
  else
    # Только имя модуля без команды
    .PHONY: $(MODULE_NAME)
    $(MODULE_NAME):
	@printf "\\n$(COLOR_SECTION)▶ Модуль: $(MODULE_NAME)$(COLOR_RESET)\\n"
	@printf "$(COLOR_INFO)Путь:$(COLOR_RESET) $(MODULE_PATH)\\n\\n"
	@if [ -n "$(MODULE_TECH)" ]; then \
		printf "$(COLOR_INFO)Найденные технологии:$(COLOR_RESET)\\n"; \
		for tech in $(MODULE_TECH); do \
			case $$tech in \
				nodejs) \
					printf "  $(COLOR_SUCCESS)• Node.js$(COLOR_RESET)\\n"; \
					managers="$(call get-all-managers,$(MODULE_PATH),nodejs)"; \
					primary="$(call get-primary-manager,$(MODULE_PATH),nodejs)"; \
					printf "    Менеджеры: $$managers"; \
					if [ -n "$$primary" ]; then printf " (основной: $$primary)"; fi; \
					printf "\\n"; \
					printf "    Команды: make $(MODULE_NAME) <npm|yarn|pnpm|bun> <команда>\\n"; \
					;; \
				php) \
					printf "  $(COLOR_SUCCESS)• PHP$(COLOR_RESET)\\n"; \
					printf "    Менеджер: composer\\n"; \
					printf "    Команды: make $(MODULE_NAME) composer <команда>\\n"; \
					;; \
				python) \
					printf "  $(COLOR_SUCCESS)• Python$(COLOR_RESET)\\n"; \
					managers="$(call get-all-managers,$(MODULE_PATH),python)"; \
					primary="$(call get-primary-manager,$(MODULE_PATH),python)"; \
					printf "    Менеджеры: $$managers"; \
					if [ -n "$$primary" ]; then printf " (основной: $$primary)"; fi; \
					printf "\\n"; \
					printf "    Команды: make $(MODULE_NAME) <pip|poetry|pipenv|uv> <команда>\\n"; \
					;; \
				rust) \
					printf "  $(COLOR_SUCCESS)• Rust$(COLOR_RESET)\\n"; \
					printf "    Менеджер: cargo\\n"; \
					printf "    Команды: make $(MODULE_NAME) cargo <команда>\\n"; \
					;; \
				makefile) \
					printf "  $(COLOR_SUCCESS)• Makefile$(COLOR_RESET)\\n"; \
					printf "    Команды: make $(MODULE_NAME) <команда>\\n"; \
					;; \
				gitlab) \
					printf "  $(COLOR_SUCCESS)• GitLab CI$(COLOR_RESET)\\n"; \
					;; \
				github) \
					printf "  $(COLOR_SUCCESS)• GitHub Actions$(COLOR_RESET)\\n"; \
					;; \
			esac; \
		done; \
	else \
		printf "$(COLOR_WARNING)⚠ WARNING:$(COLOR_RESET) %s\\n" "Технологии не найдены в модуле"; \
		printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) %s\\n" "Создайте маркерные файлы (package.json, Cargo.toml, и т.д.)"; \
	fi; \
	if [ -f "$(MODULE_PATH)/Makefile" ]; then \
		printf "\\n$(COLOR_INFO)Makefile команды:$(COLOR_RESET)\\n"; \
		cd "$(MODULE_PATH)" && $(MAKE) help 2>/dev/null || printf "  (справка недоступна)\\n"; \
	fi; \
	printf "\\n"
  endif
endif
