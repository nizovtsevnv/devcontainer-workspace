# ===================================
# Управление модулями проекта
# ===================================

# ===================================
# Создание новых модулей
# ===================================

# Переменные
MODULE_TARGET ?= modules
MODULE_STACK ?=
MODULE_TYPE ?=
MODULE_NAME ?=

# Главная команда (запуск с хоста или изнутри контейнера)
.PHONY: module
module:
	@$(MAKE) module-interactive MODULE_STACK="$(MODULE_STACK)" MODULE_TYPE="$(MODULE_TYPE)" MODULE_NAME="$(MODULE_NAME)" MODULE_TARGET="$(MODULE_TARGET)"

# Интерактивная команда (только для запуска внутри контейнера)
.PHONY: module-interactive
module-interactive:
	@export MODULE_STACK="$(MODULE_STACK)"; \
	export MODULE_TYPE="$(MODULE_TYPE)"; \
	export MODULE_NAME="$(MODULE_NAME)"; \
	export MODULE_TARGET="$(MODULE_TARGET)"; \
	$(call run-script,makefiles/scripts/module-create.sh)

# ===================================
# Динамические команды модулей
# ===================================
# Все функции делегируются в makefiles/scripts/module-command.sh и lib/modules.sh

# Получение списка имён модулей (извлечь basename из путей)
MODULE_NAMES := $(notdir $(ALL_MODULES))

# Проверка: первый аргумент командной строки - имя модуля?
FIRST_GOAL := $(firstword $(MAKECMDGOALS))
SECOND_GOAL := $(word 2,$(MAKECMDGOALS))
REST_GOALS := $(wordlist 3,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

# Если первый аргумент - имя модуля
ifneq ($(filter $(FIRST_GOAL),$(MODULE_NAMES)),)
  .PHONY: $(FIRST_GOAL)
  $(FIRST_GOAL):
	@$(call run-script,makefiles/scripts/module-command.sh,$(FIRST_GOAL) $(SECOND_GOAL) $(REST_GOALS))

  # Подавить ошибки для остальных аргументов
  .PHONY: $(SECOND_GOAL) $(REST_GOALS)
  $(SECOND_GOAL):
	@:
  $(REST_GOALS):
	@:
endif
