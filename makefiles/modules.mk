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
	@if [ -z "$(PM_COMMAND)" ]; then \
		printf "$(COLOR_SECTION)▶ Модуль $(MODULE_NAME): $(PACKAGE_MANAGER) --help$(COLOR_RESET)\\n"; \
	else \
		printf "$(COLOR_SECTION)▶ Модуль $(MODULE_NAME): $(PACKAGE_MANAGER) $(PM_COMMAND)$(COLOR_RESET)\\n"; \
	fi
	@$(call ensure-container-running)
	@if [ -z "$(PM_COMMAND)" ]; then \
		if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
			cd "$(MODULE_PATH)" && $(PACKAGE_MANAGER) --help; \
		else \
			$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) exec -T $(DEVCONTAINER_SERVICE) \
				bash -c "cd $(DEVCONTAINER_WORKDIR)/$(MODULE_PATH) && $(PACKAGE_MANAGER) --help"; \
		fi; \
	else \
		if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
			cd "$(MODULE_PATH)" && $(PACKAGE_MANAGER) $(PM_COMMAND); \
		else \
			$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) exec -T $(DEVCONTAINER_SERVICE) \
				bash -c "cd $(DEVCONTAINER_WORKDIR)/$(MODULE_PATH) && $(PACKAGE_MANAGER) $(PM_COMMAND)"; \
		fi; \
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
	@printf "$(COLOR_SECTION)▶ Модуль: $(MODULE_NAME)$(COLOR_RESET)\\n"
	@# Вывод версии модуля
	@module_path="$(MODULE_PATH)"; \
	versions=""; \
	if [ -f "$$module_path/Cargo.toml" ]; then \
		rust_ver=$$(grep '^version = ' "$$module_path/Cargo.toml" | head -1 | sed 's/version = "\(.*\)"/\1/' | xargs); \
		if [ -n "$$rust_ver" ]; then \
			versions="$$versions$$rust_ver (Rust)"; \
		fi; \
	fi; \
	if [ -f "$$module_path/package.json" ]; then \
		node_ver=$$(grep '"version":' "$$module_path/package.json" | head -1 | sed 's/.*"version": "\(.*\)".*/\1/' | xargs); \
		if [ -n "$$node_ver" ]; then \
			[ -n "$$versions" ] && versions="$$versions, "; \
			versions="$$versions$$node_ver (Node.js)"; \
		fi; \
	fi; \
	if [ -f "$$module_path/composer.json" ]; then \
		php_ver=$$(grep '"version":' "$$module_path/composer.json" | head -1 | sed 's/.*"version": "\(.*\)".*/\1/' | xargs); \
		if [ -n "$$php_ver" ]; then \
			[ -n "$$versions" ] && versions="$$versions, "; \
			versions="$$versions$$php_ver (PHP)"; \
		fi; \
	fi; \
	if [ -f "$$module_path/pyproject.toml" ]; then \
		python_ver=$$(grep '^version = ' "$$module_path/pyproject.toml" | head -1 | sed 's/version = "\(.*\)"/\1/' | xargs); \
		if [ -n "$$python_ver" ]; then \
			[ -n "$$versions" ] && versions="$$versions, "; \
			versions="$$versions$$python_ver (Python)"; \
		fi; \
	fi; \
	if [ -n "$$versions" ]; then \
		printf "Версия: $$versions\\n"; \
	fi
	@# Вывод инструментов
	@if [ -n "$(MODULE_TECH)" ]; then \
		printf "\\nИнструменты:\\n"; \
		for tech in $(MODULE_TECH); do \
			case $$tech in \
				nodejs) \
					printf "  make $(MODULE_NAME) npm        Помощь по использованию пакетного менеджера npm\\n"; \
					printf "  make $(MODULE_NAME) yarn       Помощь по использованию пакетного менеджера Yarn\\n"; \
					printf "  make $(MODULE_NAME) pnpm       Помощь по использованию пакетного менеджера pnpm\\n"; \
					printf "  make $(MODULE_NAME) bun        Помощь по использованию пакетного менеджера Bun\\n"; \
					;; \
				php) \
					printf "  make $(MODULE_NAME) composer   Помощь по использованию пакетного менеджера Composer\\n"; \
					;; \
				python) \
					printf "  make $(MODULE_NAME) pip        Помощь по использованию пакетного менеджера pip\\n"; \
					printf "  make $(MODULE_NAME) poetry     Помощь по использованию пакетного менеджера Poetry\\n"; \
					printf "  make $(MODULE_NAME) pipenv     Помощь по использованию пакетного менеджера Pipenv\\n"; \
					printf "  make $(MODULE_NAME) uv         Помощь по использованию пакетного менеджера uv\\n"; \
					;; \
				rust) \
					printf "  make $(MODULE_NAME) cargo      Помощь по использованию пакетного менеджера Cargo\\n"; \
					;; \
				makefile) \
					printf "\\nMakefile команды:\\n"; \
					cd "$(MODULE_PATH)" && $(MAKE) help 2>/dev/null || printf "  (справка недоступна)\\n"; \
					;; \
			esac; \
		done; \
	else \
		printf "\\n$(COLOR_WARNING)⚠ WARNING:$(COLOR_RESET) Технологии не найдены в модуле\\n"; \
		printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) Создайте маркерные файлы (package.json, Cargo.toml, и т.д.)\\n"; \
	fi
  endif
endif
