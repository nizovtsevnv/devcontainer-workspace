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
CONTAINER_NAME := devcontainer-workspace-dev
# Автоопределение версии шаблона и образа
TEMPLATE_VERSION := $(shell \
	if [ -f .template-version ]; then \
		cat .template-version 2>/dev/null | sed 's/^v//' || echo "latest"; \
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

# Цвета для вывода (используются в functions.mk)
COLOR_RESET := \033[0m
COLOR_INFO := \033[0;36m
COLOR_SUCCESS := \033[0;32m
COLOR_WARNING := \033[0;33m
COLOR_ERROR := \033[0;31m
COLOR_SECTION := \033[1;35m
