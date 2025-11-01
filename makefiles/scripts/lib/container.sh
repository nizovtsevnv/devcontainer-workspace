#!/bin/sh
# ===================================
# Container библиотека для DevContainer Workspace
# ===================================
# Функции управления контейнерами
# Использование: . lib/container.sh

# Загружаем UI библиотеку если ещё не загружена
if ! command -v log_info >/dev/null 2>&1; then
	SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")" && pwd)}"
	. "$SCRIPT_DIR/ui.sh"
fi

# ===================================
# Функции проверки и подготовки
# ===================================

# Проверка доступности команды
# Параметр: $1 - имя команды
# Использование: check_command "docker"
check_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		log_error "Команда '$1' не найдена"
		log_info "Установите '$1' для использования DevContainer"
		exit 1
	fi
}

# Проверка и скачивание образа контейнера с показом прогресса
# Использование: ensure_image_available
ensure_image_available() {
	if ! $CONTAINER_RUNTIME images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q "^${CONTAINER_IMAGE}$"; then
		log_info "Скачивание образа $CONTAINER_IMAGE..."
		printf "\n"
		if $CONTAINER_RUNTIME pull "$CONTAINER_IMAGE"; then
			printf "\n"
			log_success "Образ готов"
		else
			printf "\n"
			log_error "Не удалось скачать образ"
			exit 1
		fi
	fi
}

# Умная проверка готовности контейнерной среды
# Запускает контейнер если ещё не запущен
# Использование: ensure_devenv_ready
ensure_devenv_ready() {
	if [ "$IS_INSIDE_CONTAINER" = "0" ]; then
		# Уже внутри контейнера - всё готово
		return 0
	elif $CONTAINER_RUNTIME ps --format "{{.Names}}" 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
		# Контейнер уже запущен - всё готово
		return 0
	else
		# Контейнер не запущен - запускаем

		# Сначала проверяем наличие образа (с прямым выводом прогресса)
		ensure_image_available

		# Запускаем контейнер со спиннером
		if show_spinner "Запуск контейнера ($CONTAINER_NAME)" container_up_silent; then
			return 0
		else
			log_error "Не удалось запустить контейнер"
			exit 1
		fi
	fi
}

# ===================================
# Функции управления контейнером
# ===================================

# Тихий запуск контейнера (без вывода)
# Используется внутри других функций
# Использование: container_up_silent
container_up_silent() {
	if $CONTAINER_RUNTIME ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
		# Контейнер существует но не запущен - стартуем
		if ! $CONTAINER_RUNTIME ps --format "{{.Names}}" 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
			$CONTAINER_RUNTIME start "$CONTAINER_NAME" >/dev/null 2>&1
		fi
	else
		# Контейнер не существует - создаём
		if [ "$CONTAINER_RUNTIME" = "podman" ]; then
			$CONTAINER_RUNTIME run -d --name "$CONTAINER_NAME" \
				--userns=keep-id:uid="$HOST_UID",gid="$HOST_GID" \
				--network=host \
				-v "$WORKSPACE_ROOT:$CONTAINER_WORKDIR" \
				-w "$CONTAINER_WORKDIR" \
				-e INSIDE_DEVCONTAINER=1 -e USER=developer -e HOME=/home/developer \
				"$CONTAINER_IMAGE" \
				/bin/bash -c "trap 'exit 0' TERM; while true; do sleep 1; done" >/dev/null 2>&1
		else
			$CONTAINER_RUNTIME run -d --name "$CONTAINER_NAME" \
				--user "$HOST_UID:$HOST_GID" \
				--network=host \
				-v "$WORKSPACE_ROOT:$CONTAINER_WORKDIR" \
				-w "$CONTAINER_WORKDIR" \
				-e INSIDE_DEVCONTAINER=1 -e USER=developer -e HOME=/home/developer \
				"$CONTAINER_IMAGE" \
				/bin/bash -c "trap 'exit 0' TERM; while true; do sleep 1; done" >/dev/null 2>&1
		fi
	fi
}

# Остановить контейнер если запущен
# Использование: stop_container_if_running
stop_container_if_running() {
	if $CONTAINER_RUNTIME ps --format "{{.Names}}" 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
		$CONTAINER_RUNTIME stop "$CONTAINER_NAME" >/dev/null 2>&1
		$CONTAINER_RUNTIME rm "$CONTAINER_NAME" >/dev/null 2>&1
	fi
}

# Обновить Docker образ и пересоздать контейнер
# Использование: update_container_image
update_container_image() {
	printf "\n"
	log_info "Обновление Docker образа..."
	printf "\n"

	if $CONTAINER_RUNTIME pull "$CONTAINER_IMAGE"; then
		printf "\n"
		if show_spinner "Пересоздание контейнера" sh -c "stop_container_if_running && container_up_silent"; then
			log_success "Контейнер обновлен"
		else
			log_error "Не удалось пересоздать контейнер"
			exit 1
		fi
	else
		printf "\n"
		log_error "Не удалось обновить образ"
		exit 1
	fi
}

# ===================================
# Функция выполнения команд в контейнере
# ===================================

# Выполнить команду в контейнере или локально (автоопределение)
# Параметры: все параметры передаются как команда
# Использование: container_exec "echo test"
container_exec() {
	ensure_devenv_ready

	if [ "$IS_INSIDE_CONTAINER" = "0" ]; then
		# Уже внутри контейнера - выполняем напрямую
		bash -c "$*"
	else
		# Снаружи контейнера - выполняем через exec
		$CONTAINER_RUNTIME exec -w "$CONTAINER_WORKDIR" "$CONTAINER_NAME" bash -c "$*"
	fi
}

# Выполнить интерактивную команду в контейнере
# Параметры: все параметры передаются как команда
# Использование: container_exec_interactive "vim file.txt"
container_exec_interactive() {
	ensure_devenv_ready

	if [ "$IS_INSIDE_CONTAINER" = "0" ]; then
		# Уже внутри контейнера - выполняем напрямую
		bash -c "$*"
	else
		# Снаружи контейнера - выполняем через exec с TTY
		$CONTAINER_RUNTIME exec -it -w "$CONTAINER_WORKDIR" "$CONTAINER_NAME" bash -c "$*"
	fi
}
