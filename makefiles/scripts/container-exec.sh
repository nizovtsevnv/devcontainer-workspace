#!/bin/sh
# ===================================
# DevContainer Workspace - Выполнение команды
# ===================================

# Определяем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Загружаем библиотеки
. "$SCRIPT_DIR/lib/ui.sh"
. "$SCRIPT_DIR/lib/container.sh"

# ===================================
# Основная логика
# ===================================

# Параметры:
# $1 - флаг интерактивности (-it или пустая строка)
# $2.. - команда для выполнения

# Определение режима и команды
if [ "$1" = "-it" ]; then
	INTERACTIVE=1
	shift
else
	INTERACTIVE=0
fi

# Получить команду из аргументов или переменной CMD
if [ -n "$CMD" ]; then
	COMMAND="$CMD"
else
	COMMAND="$*"
fi

# Проверка что команда передана
if [ -z "$COMMAND" ]; then
	log_error "Использование: container-exec.sh [-it] 'команда'"
	log_info "Или: CMD='команда' container-exec.sh [-it]"
	exit 1
fi

# Убедиться что контейнер запущен
ensure_devenv_ready

# Выполнить команду
if [ "$INTERACTIVE" = "1" ]; then
	container_exec_interactive "$COMMAND"
else
	container_exec "$COMMAND"
fi
