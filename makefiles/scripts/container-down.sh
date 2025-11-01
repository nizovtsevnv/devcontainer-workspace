#!/bin/sh
# ===================================
# DevContainer Workspace - Остановка контейнера
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
	log_warning "Нельзя остановить контейнер изнутри"
	exit 1
fi

# Проверка: контейнер запущен?
if $CONTAINER_RUNTIME ps --format "{{.Names}}" 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
	if show_spinner "Остановка контейнера ($CONTAINER_NAME)" sh -c "$CONTAINER_RUNTIME stop $CONTAINER_NAME >/dev/null 2>&1 && $CONTAINER_RUNTIME rm $CONTAINER_NAME >/dev/null 2>&1"; then
		log_success "Контейнер остановлен"
	else
		log_error "Не удалось остановить контейнер"
		exit 1
	fi
else
	log_info "Контейнер уже остановлен"
fi
