# ===================================
# Конфигурация workspace
# ===================================

# Определение проекта
PROJECT_NAME := devcontainer-workspace
WORKSPACE_ROOT := $(shell pwd)

# Определение: внутри или снаружи контейнера
IS_INSIDE_CONTAINER := $(shell [ -f /.dockerenv ] || [ -n "$$INSIDE_DEVCONTAINER" ]; echo $$?)

# Автоопределение container runtime (docker или podman)
# Проверяем реальный runtime, т.к. docker может быть symlink на podman
CONTAINER_RUNTIME := $(shell \
	if command -v podman >/dev/null 2>&1 && (podman --version 2>/dev/null | grep -q podman || docker --version 2>/dev/null | grep -qi podman); then \
		echo podman; \
	elif command -v docker >/dev/null 2>&1; then \
		echo docker; \
	else \
		echo podman; \
	fi)

# Экспортировать UID и GID хоста
# Это обеспечивает корректные права доступа к файлам
# Используем HOST_UID/HOST_GID, т.к. GID - встроенная переменная bash
export HOST_UID := $(shell id -u)
export HOST_GID := $(shell id -g)

# DevContainer настройки
# Генерация уникального имени контейнера на основе имени директории проекта
# Это позволяет каждому проекту иметь свой собственный контейнер без конфликтов
# Формат: <имя-директории>-devcontainer
# Пример: для /path/to/myproject получится myproject-devcontainer
WORKSPACE_BASENAME := $(shell basename "$(WORKSPACE_ROOT)")
CONTAINER_NAME := $(WORKSPACE_BASENAME)-devcontainer
# Автоопределение версии шаблона и образа
# Редуцируем версию до базовой (X.Y.Z) для Docker образа
# Полная версия (X.Y.Z-N-gXXX) сохраняется в .template-version для точного отслеживания
TEMPLATE_VERSION := $(shell \
	if [ -f .template-version ]; then \
		cat .template-version 2>/dev/null | sed 's/^v//' | sed 's/-[0-9]*-g.*//' || echo "latest"; \
	else \
		VERSION=$$(git describe --tags --exact-match HEAD 2>/dev/null || git describe --tags 2>/dev/null || echo ""); \
		if [ -n "$$VERSION" ]; then \
			echo "$$VERSION" | sed 's/^v//' | sed 's/-[0-9]*-g.*//'; \
		else \
			echo "latest"; \
		fi; \
	fi)
CONTAINER_IMAGE_VERSION := $(TEMPLATE_VERSION)
CONTAINER_IMAGE := ghcr.io/nizovtsevnv/devcontainer-workspace:$(CONTAINER_IMAGE_VERSION)
CONTAINER_WORKDIR := /workspace
DEVCONTAINER_USER := developer
DEVCONTAINER_WORKDIR := /workspace

# Пути для субмодулей
MODULES_DIR := modules
MODULES := $(wildcard $(MODULES_DIR)/*)
# Все модули: только директории (исключая файлы типа .gitkeep)
ALL_MODULES := $(filter-out $(MODULES_DIR)/.gitkeep,$(filter-out %/.gitkeep,$(MODULES)))

# Цвета для вывода (экспортируются в shell-скрипты через run-script)
COLOR_RESET := \033[0m
COLOR_INFO := \033[0;36m
COLOR_SUCCESS := \033[0;32m
COLOR_WARNING := \033[0;33m
COLOR_ERROR := \033[0;31m
COLOR_SECTION := \033[1;35m
COLOR_DIM := \033[2m

# ===================================
# Универсальная функция для запуска shell-скриптов
# ===================================
# Экспортирует все необходимые переменные окружения и запускает скрипт
# Использование: $(call run-script,путь/к/скрипту.sh,аргументы)
define run-script
	export COLOR_SUCCESS='$(COLOR_SUCCESS)'; \
	export COLOR_ERROR='$(COLOR_ERROR)'; \
	export COLOR_INFO='$(COLOR_INFO)'; \
	export COLOR_WARNING='$(COLOR_WARNING)'; \
	export COLOR_SECTION='$(COLOR_SECTION)'; \
	export COLOR_RESET='$(COLOR_RESET)'; \
	export COLOR_DIM='$(COLOR_DIM)'; \
	export WORKSPACE_ROOT='$(WORKSPACE_ROOT)'; \
	export MODULES_DIR='$(MODULES_DIR)'; \
	export CONTAINER_RUNTIME='$(CONTAINER_RUNTIME)'; \
	export CONTAINER_NAME='$(CONTAINER_NAME)'; \
	export CONTAINER_IMAGE='$(CONTAINER_IMAGE)'; \
	export CONTAINER_WORKDIR='$(CONTAINER_WORKDIR)'; \
	export IS_INSIDE_CONTAINER='$(IS_INSIDE_CONTAINER)'; \
	export HOST_UID='$(HOST_UID)'; \
	export HOST_GID='$(HOST_GID)'; \
	sh $(1) $(2)
endef
