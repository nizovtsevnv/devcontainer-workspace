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
		$(call log-section,Модуль $(MODULE_NAME)\: $(PACKAGE_MANAGER) --help); \
	else \
		$(call log-section,Модуль $(MODULE_NAME)\: $(PACKAGE_MANAGER) $(PM_COMMAND)); \
	fi
	@$(call ensure-devenv-ready)
	@if [ -z "$(PM_COMMAND)" ]; then \
		if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
			cd "$(MODULE_PATH)" && $(PACKAGE_MANAGER) --help; \
		else \
			$(CONTAINER_RUNTIME) exec $(CONTAINER_NAME) bash -c "cd $(CONTAINER_WORKDIR)/modules/$(MODULE_NAME) && $(PACKAGE_MANAGER) --help"; \
		fi; \
	else \
		if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
			cd "$(MODULE_PATH)" && $(PACKAGE_MANAGER) $(PM_COMMAND); \
		else \
			$(CONTAINER_RUNTIME) exec $(CONTAINER_NAME) bash -c "cd $(CONTAINER_WORKDIR)/modules/$(MODULE_NAME) && $(PACKAGE_MANAGER) $(PM_COMMAND)"; \
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
	@$(call ensure-devenv-ready)
	@$(call log-section,Модуль $(MODULE_NAME)\: $(MODULE_CMD))
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
	@$(call log-error,Модуль '$(MODULE_NAME)' содержит несколько технологий: $(MODULE_TECH))
	@$(call log-info,Создайте modules/$(MODULE_NAME)/Makefile для определения команды '$(SECOND_GOAL)')
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
		$(call log-error,Неизвестная технология для модуля '$(MODULE_NAME)'); \
		exit 1; \
	fi
	@$(call log-section,Модуль $(MODULE_NAME)\: $(PM_AUTO) $(MAPPED_CMD) $(REST_GOALS))
	@$(call ensure-devenv-ready)
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		cd "$(MODULE_PATH)" && $(PM_AUTO) $(MAPPED_CMD) $(REST_GOALS); \
	else \
		$(CONTAINER_RUNTIME) exec $(CONTAINER_NAME) bash -c "cd $(CONTAINER_WORKDIR)/modules/$(MODULE_NAME) && $(PM_AUTO) $(MAPPED_CMD) $(REST_GOALS)"; \
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
	@$(call log-info,Модуль: $(MODULE_NAME))
	@# Вывод типа и версии модуля
	@version=$$($(call get-module-version,$(MODULE_PATH))); \
	tech_list="$(MODULE_TECH)"; \
	if [ -n "$$version" ] && [ -n "$$tech_list" ]; then \
		printf '%s\n' "Тип<COL>$$tech_list<ROW>Версия<COL>$$version" | { $(call print-table,16); }; \
	elif [ -n "$$tech_list" ]; then \
		printf '%s\n' "Тип<COL>$$tech_list" | { $(call print-table,16); }; \
	fi
	@# Вывод инструментов
	@if [ -n "$(MODULE_TECH)" ]; then \
		printf "\\n"; \
		$(call log-info,Инструменты:); \
		commands_data=""; \
		for tech in $(MODULE_TECH); do \
			case $$tech in \
				nodejs) \
					[ -n "$$commands_data" ] && commands_data="$$commands_data<ROW>"; \
					commands_data="$$commands_data""make $(MODULE_NAME) build<COL>Собрать для production"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) bun<COL>Выполнить команду пакетного менеджера Bun"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) dev<COL>Запустить dev-сервер"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) format<COL>Отформатировать код"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) install<COL>Установить зависимости"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) lint<COL>Проверить код линтером"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) npm<COL>Выполнить команду пакетного менеджера npm"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) pnpm<COL>Выполнить команду пакетного менеджера pnpm"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) test<COL>Запустить тесты"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) yarn<COL>Выполнить команду пакетного менеджера Yarn"; \
					;; \
				php) \
					[ -n "$$commands_data" ] && commands_data="$$commands_data<ROW>"; \
					commands_data="$$commands_data""make $(MODULE_NAME) build<COL>Собрать для production"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) composer<COL>Выполнить команду пакетного менеджера Composer"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) install<COL>Установить зависимости"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) lint<COL>Проверить код линтером"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) test<COL>Запустить тесты"; \
					;; \
				python) \
					[ -n "$$commands_data" ] && commands_data="$$commands_data<ROW>"; \
					commands_data="$$commands_data""make $(MODULE_NAME) format<COL>Отформатировать код"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) install<COL>Установить зависимости"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) lint<COL>Проверить код линтером"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) pip<COL>Выполнить команду пакетного менеджера pip"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) pipenv<COL>Выполнить команду пакетного менеджера Pipenv"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) poetry<COL>Выполнить команду пакетного менеджера Poetry"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) test<COL>Запустить тесты"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) uv<COL>Выполнить команду пакетного менеджера uv"; \
					;; \
				rust) \
					[ -n "$$commands_data" ] && commands_data="$$commands_data<ROW>"; \
					commands_data="$$commands_data""make $(MODULE_NAME) build<COL>Собрать релиз"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) cargo<COL>Выполнить команду пакетного менеджера Cargo"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) format<COL>Отформатировать код"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) install<COL>Установить зависимости"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) lint<COL>Проверить код clippy"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) run<COL>Запустить приложение"; \
					commands_data="$$commands_data<ROW>make $(MODULE_NAME) test<COL>Запустить тесты"; \
					;; \
				makefile) \
					printf "\\nMakefile команды:\\n"; \
					cd "$(MODULE_PATH)" && $(MAKE) help 2>/dev/null || printf "  (справка недоступна)\\n"; \
					;; \
			esac; \
		done; \
		if [ -n "$$commands_data" ]; then \
			printf '%s\n' "$$commands_data" | { $(call print-table,30); }; \
		fi; \
	else \
		printf "\\n"; \
		$(call log-warning,Технологии не найдены в модуле); \
		$(call log-info,Создайте маркерные файлы (package.json, Cargo.toml, и т.д.)); \
	fi
  endif
endif
