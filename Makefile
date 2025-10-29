# ===================================
# DevContainer Workspace - Makefile
# ===================================
#
# Система многоуровневых команд для управления workspace и модулями
#
# Использование:
#   make help              - справка
#   make up                - запуск среды (с авто-инициализацией)
#   make exec '<команда>'  - выполнение команды
#   make <модуль> <команда> - работа с модулем
#   make devenv <cmd>      - управление шаблоном (init, version, update)
#

.DEFAULT_GOAL := help
MAKEFLAGS += --no-print-directory

# Подключение модулей в правильном порядке
# Порядок важен: сначала config, потom functions, detect, остальные - в любом порядке
include makefiles/config.mk
include makefiles/functions.mk
include makefiles/detect.mk
include makefiles/core.mk
include makefiles/modules/commands.mk
include makefiles/modules/create.mk
include makefiles/devenv/main.mk
include makefiles/devenv/test.mk
include makefiles/help.mk

# Универсальное правило для подавления ошибок о несуществующих targets
# Позволяет передавать произвольные аргументы в make exec и команды модулей
%:
	@:
