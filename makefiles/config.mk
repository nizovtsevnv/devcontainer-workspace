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

# Отключить предупреждения podman-compose
export PODMAN_COMPOSE_WARNING_LOGS = 0

# Экспортировать UID и GID хоста для docker-compose
# Это обеспечивает корректные права доступа к файлам
export UID := $(shell id -u)
export GID := $(shell id -g)

# DevContainer настройки
DEVCONTAINER_SERVICE := devcontainer-workspace-dev
DEVCONTAINER_USER := developer
DEVCONTAINER_WORKDIR := /workspace

# Docker Compose файл для headless режима
COMPOSE_FILE := .devcontainer/docker-compose.yml

# Пути для субмодулей
MODULES_DIR := modules
MODULES := $(wildcard $(MODULES_DIR)/*)
# Все модули (не только с Makefile, т.к. используем автоопределение технологий)
ALL_MODULES := $(filter-out %/., $(wildcard $(MODULES_DIR)/*/.))

# Цвета для вывода (используются в functions.mk)
COLOR_RESET := \033[0m
COLOR_INFO := \033[0;36m
COLOR_SUCCESS := \033[0;32m
COLOR_WARNING := \033[0;33m
COLOR_ERROR := \033[0;31m
COLOR_SECTION := \033[1;35m
