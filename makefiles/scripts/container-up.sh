#!/bin/sh
# ===================================
# DevContainer Workspace - Запуск контейнера
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

# Проверка наличия container runtime
check_command "$CONTAINER_RUNTIME"

# Проверка: контейнер уже запущен?
if $CONTAINER_RUNTIME ps --format "{{.Names}}" 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
	log_info "Контейнер уже запущен"
# Проверка: контейнер существует но остановлен?
elif $CONTAINER_RUNTIME ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
	if show_spinner "Запуск существующего контейнера" $CONTAINER_RUNTIME start "$CONTAINER_NAME"; then
		log_success "Контейнер запущен"
	else
		log_error "Не удалось запустить контейнер"
		exit 1
	fi
else
	# Контейнер не существует - создаём новый
	ensure_image_available

	if show_spinner "Создание контейнера ($CONTAINER_NAME)" container_up_silent; then
		log_success "Контейнер запущен"
	else
		log_error "Не удалось создать контейнер"
		exit 1
	fi
fi

printf "\n"
