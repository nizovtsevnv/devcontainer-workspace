# ===================================
# Динамические команды модулей
# ===================================

# Получение списка имён модулей (извлечь basename из путей)
MODULE_NAMES := $(notdir $(ALL_MODULES))

# Известные пакетные менеджеры
KNOWN_PACKAGE_MANAGERS := bun cargo composer npm pip pipenv poetry pnpm uv yarn

# Стандартные сокращённые команды
STANDARD_COMMANDS := build check clean dev doc docs format install lint run start test update

# ===================================
# Функции маппинга команд по технологиям
# ===================================

# Маппинг команд для Rust (cargo)
define map-rust-command
$(strip \
$(if $(filter $(1),install),install,\
$(if $(filter $(1),run),run,\
$(if $(filter $(1),dev),run,\
$(if $(filter $(1),test),test,\
$(if $(filter $(1),check),check,\
$(if $(filter $(1),lint),clippy,\
$(if $(filter $(1),format),fmt,\
$(if $(filter $(1),build),build --release,\
$(if $(filter $(1),doc),doc,\
$(if $(filter $(1),docs),doc,\
$(if $(filter $(1),clean),clean,\
$(if $(filter $(1),update),update,\
$(1))))))))))))) \
)
endef

# Маппинг команд для Node.js (npm/yarn/pnpm/bun)
define map-nodejs-command
$(strip \
$(if $(filter $(1),install),install,\
$(if $(filter $(1),run),run,\
$(if $(filter $(1),dev),run dev,\
$(if $(filter $(1),start),start,\
$(if $(filter $(1),test),test,\
$(if $(filter $(1),lint),run lint,\
$(if $(filter $(1),format),run format,\
$(if $(filter $(1),check),run check,\
$(if $(filter $(1),build),run build,\
$(if $(filter $(1),doc),run doc,\
$(if $(filter $(1),docs),run docs,\
$(if $(filter $(1),update),update,\
$(1))))))))))))) \
)
endef

# Маппинг команд для Python (pip/poetry/pipenv/uv)
define map-python-command
$(strip \
$(if $(filter $(1),run),run,\
$(if $(filter $(1),dev),run dev,\
$(if $(filter $(1),test),run pytest,\
$(if $(filter $(1),lint),run ruff check,\
$(if $(filter $(1),format),run ruff format,\
$(if $(filter $(1),check),run mypy,\
$(if $(filter $(1),doc),run doc,\
$(if $(filter $(1),docs),run docs,\
$(1))))))))) \
)
endef

# Маппинг команд для PHP (composer)
define map-php-command
$(strip \
$(if $(filter $(1),install),install,\
$(if $(filter $(1),run),run,\
$(if $(filter $(1),dev),run dev,\
$(if $(filter $(1),test),run test,\
$(if $(filter $(1),lint),run lint,\
$(if $(filter $(1),check),run check,\
$(if $(filter $(1),build),install --no-dev --optimize-autoloader,\
$(if $(filter $(1),doc),run doc,\
$(if $(filter $(1),docs),run docs,\
$(if $(filter $(1),update),update,\
$(1))))))))))) \
)
endef

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
			$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) exec -w $(DEVCONTAINER_WORKDIR)/$(MODULE_PATH) -T $(DEVCONTAINER_SERVICE) \
				$(PACKAGE_MANAGER) --help; \
		fi; \
	else \
		if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
			cd "$(MODULE_PATH)" && $(PACKAGE_MANAGER) $(PM_COMMAND); \
		else \
			$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) exec -w $(DEVCONTAINER_WORKDIR)/$(MODULE_PATH) -T $(DEVCONTAINER_SERVICE) \
				$(PACKAGE_MANAGER) $(PM_COMMAND); \
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
      # Это может быть сокращённая команда или команда в Makefile модуля

      MODULE_CMD := $(SECOND_GOAL)

      # Проверить, есть ли Makefile в модуле и содержит ли target
      ifneq ($(wildcard $(MODULE_PATH)/Makefile),)
        # Есть Makefile - проверить наличие target с помощью make -n
        MODULE_HAS_TARGET := $(shell cd "$(MODULE_PATH)" && $(MAKE) -n $(MODULE_CMD) >/dev/null 2>&1 && echo "yes" || echo "no")
      else
        MODULE_HAS_TARGET := no
      endif

      ifeq ($(MODULE_HAS_TARGET),yes)
        # Target существует в Makefile - делегируем ему
        .PHONY: $(MODULE_NAME)
        $(MODULE_NAME):
	@$(call ensure-container-running)
	@printf "$(COLOR_SECTION)▶ Модуль $(MODULE_NAME): $(MODULE_CMD)$(COLOR_RESET)\\n"
	@cd "$(MODULE_PATH)" && $(MAKE) $(MODULE_CMD) $(REST_GOALS)

        # Подавить ошибки для аргументов
        .PHONY: $(MODULE_CMD) $(REST_GOALS)
        $(MODULE_CMD):
	@:
        $(REST_GOALS):
	@:
      else
        # Target не найден или нет Makefile - попробуем маппинг на PM
        # Проверить количество технологий
        TECH_WORDS := $(words $(MODULE_TECH))

        ifeq ($(shell [ $(TECH_WORDS) -gt 1 ] && echo "multi" || echo "single"),multi)
          # Несколько технологий - требуем Makefile
          .PHONY: $(MODULE_NAME)
          $(MODULE_NAME):
	@printf "$(COLOR_ERROR)✗ ERROR:$(COLOR_RESET) Модуль '$(MODULE_NAME)' содержит несколько технологий: $(MODULE_TECH)\\n" >&2
	@printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) Создайте modules/$(MODULE_NAME)/Makefile для определения команды '$(SECOND_GOAL)'\\n"
	@exit 1

          .PHONY: $(MODULE_CMD) $(REST_GOALS)
          $(MODULE_CMD):
	@:
          $(REST_GOALS):
	@:
        else
          # Одна технология - маппируем команду на PM
          ifeq ($(MODULE_TECH),rust)
            PM_AUTO := cargo
            MAPPED_CMD := $(call map-rust-command,$(SECOND_GOAL))
          else ifeq ($(MODULE_TECH),nodejs)
            PM_AUTO := $(call detect-nodejs-manager,$(MODULE_PATH))
            MAPPED_CMD := $(call map-nodejs-command,$(SECOND_GOAL))
          else ifeq ($(MODULE_TECH),python)
            PM_AUTO := $(call detect-python-manager,$(MODULE_PATH))
            MAPPED_CMD := $(call map-python-command,$(SECOND_GOAL))
          else ifeq ($(MODULE_TECH),php)
            PM_AUTO := composer
            MAPPED_CMD := $(call map-php-command,$(SECOND_GOAL))
          else
            PM_AUTO :=
            MAPPED_CMD := $(SECOND_GOAL)
          endif

          .PHONY: $(MODULE_NAME)
          $(MODULE_NAME):
	@if [ -z "$(PM_AUTO)" ]; then \
		printf "$(COLOR_ERROR)✗ ERROR:$(COLOR_RESET) Неизвестная технология для модуля '$(MODULE_NAME)'\\n" >&2; \
		exit 1; \
	fi
	@printf "$(COLOR_SECTION)▶ Модуль $(MODULE_NAME): $(PM_AUTO) $(MAPPED_CMD) $(REST_GOALS)$(COLOR_RESET)\\n"
	@$(call ensure-container-running)
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		cd "$(MODULE_PATH)" && $(PM_AUTO) $(MAPPED_CMD) $(REST_GOALS); \
	else \
		$(CONTAINER_RUNTIME) compose -f $(COMPOSE_FILE) exec -w $(DEVCONTAINER_WORKDIR)/$(MODULE_PATH) -T $(DEVCONTAINER_SERVICE) \
			$(PM_AUTO) $(MAPPED_CMD) $(REST_GOALS); \
	fi

          .PHONY: $(MODULE_CMD) $(REST_GOALS)
          $(MODULE_CMD):
	@:
          $(REST_GOALS):
	@:
        endif
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
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) build      $(COLOR_RESET)Собрать для production\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) bun        $(COLOR_RESET)Выполнить команду пакетного менеджера Bun\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) dev        $(COLOR_RESET)Запустить dev-сервер\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) format     $(COLOR_RESET)Отформатировать код\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) install    $(COLOR_RESET)Установить зависимости\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) lint       $(COLOR_RESET)Проверить код линтером\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) npm        $(COLOR_RESET)Выполнить команду пакетного менеджера npm\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) pnpm       $(COLOR_RESET)Выполнить команду пакетного менеджера pnpm\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) test       $(COLOR_RESET)Запустить тесты\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) yarn       $(COLOR_RESET)Выполнить команду пакетного менеджера Yarn\\n"; \
					;; \
				php) \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) build      $(COLOR_RESET)Собрать для production\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) composer   $(COLOR_RESET)Выполнить команду пакетного менеджера Composer\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) install    $(COLOR_RESET)Установить зависимости\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) lint       $(COLOR_RESET)Проверить код линтером\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) test       $(COLOR_RESET)Запустить тесты\\n"; \
					;; \
				python) \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) format     $(COLOR_RESET)Отформатировать код\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) install    $(COLOR_RESET)Установить зависимости\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) lint       $(COLOR_RESET)Проверить код линтером\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) pip        $(COLOR_RESET)Выполнить команду пакетного менеджера pip\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) pipenv     $(COLOR_RESET)Выполнить команду пакетного менеджера Pipenv\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) poetry     $(COLOR_RESET)Выполнить команду пакетного менеджера Poetry\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) test       $(COLOR_RESET)Запустить тесты\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) uv         $(COLOR_RESET)Выполнить команду пакетного менеджера uv\\n"; \
					;; \
				rust) \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) build      $(COLOR_RESET)Собрать релиз\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) cargo      $(COLOR_RESET)Выполнить команду пакетного менеджера Cargo\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) format     $(COLOR_RESET)Отформатировать код\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) install    $(COLOR_RESET)Установить зависимости\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) lint       $(COLOR_RESET)Проверить код clippy\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) run        $(COLOR_RESET)Запустить приложение\\n"; \
					printf "  $(COLOR_SUCCESS)make $(MODULE_NAME) test       $(COLOR_RESET)Запустить тесты\\n"; \
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
