#!/bin/sh
# ===================================
# DevContainer Workspace - Интерактивный shell
# ===================================
set -e

# Определяем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Загружаем библиотеки
. "$SCRIPT_DIR/lib/ui.sh"
. "$SCRIPT_DIR/lib/container.sh"

# ===================================
# Основная логика
# ===================================

# Проверка: уже внутри контейнера?
if [ "$IS_INSIDE_CONTAINER" = "0" ]; then
	log_warning "Уже внутри контейнера"
	exit 0
fi

# Убедиться что контейнер запущен
ensure_devenv_ready

# Запустить интерактивный shell
$CONTAINER_RUNTIME exec -it "$CONTAINER_NAME" /bin/bash
