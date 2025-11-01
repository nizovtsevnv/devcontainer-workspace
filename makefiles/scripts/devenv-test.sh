#!/bin/sh
# ===================================
# DevContainer Workspace - Автотесты
# ===================================
set -e

# Определяем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Загружаем библиотеки
. "$SCRIPT_DIR/lib/ui.sh"
. "$SCRIPT_DIR/lib/container.sh"

# Директория для тестов
TEST_DIR="${TEST_DIR:-/tmp/devcontainer-workspace}"

# ===================================
# Вспомогательные функции
# ===================================

run_test() {
	test_name="$1"
	shift

	log_info "Тест: $test_name"
	if "$@"; then
		log_success "Тест успешно пройден"
		return 0
	else
		log_error "ОШИБКА! Тест провален"
		return 1
	fi
}

# ===================================
# Основная логика
# ===================================

log_section "Подготовка тестового окружения"

# Остановка контейнера если запущен
make --no-print-directory down >/dev/null 2>&1 || true
log_success "Окружение очищено"
printf "\n"

# Запуск контейнера
if show_spinner "Запуск контейнера для диагностики" make --no-print-directory up; then
	log_success "Контейнер запущен"
else
	log_error "Не удалось запустить контейнер"
	exit 1
fi
printf "\n"

# CONTAINER ENVIRONMENT
log_info "Контейнерная среда:"
container_info=$(container_exec 'U=$(id -u); G=$(id -g); USR=$(whoami); D=$(pwd); echo "$U|$G|$USR|$D"' 2>/dev/null)
uid=$(echo "$container_info" | cut -d'|' -f1)
gid=$(echo "$container_info" | cut -d'|' -f2)
user=$(echo "$container_info" | cut -d'|' -f3)
cwd=$(echo "$container_info" | cut -d'|' -f4)

printf "  ${COLOR_SUCCESS}UID              ${COLOR_RESET} %s\n" "$uid"
printf "  ${COLOR_SUCCESS}GID              ${COLOR_RESET} %s\n" "$gid"
printf "  ${COLOR_SUCCESS}USER             ${COLOR_RESET} %s\n" "$user"
printf "  ${COLOR_SUCCESS}CWD              ${COLOR_RESET} %s\n" "$cwd"
printf "\n"

# Подготовка изолированного тестового окружения
printf "⠙ Подготовка изолированной копии шаблона...\n"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/modules"
cp Makefile "$TEST_DIR/"
cp -r makefiles "$TEST_DIR/"
cp -r .devcontainer "$TEST_DIR/"
echo "=== Test Run: $(date) ===" > "$TEST_DIR/test-results.log"
log_success "Копия шаблона подготовлена"
printf "\n"

# Создание тестовых модулей
log_section "Создание модулей пакетными менеджерами"

show_spinner "Создание test-nodejs" make --no-print-directory module MODULE_STACK=nodejs MODULE_TYPE=bun MODULE_NAME=test-nodejs MODULE_TARGET="$TEST_DIR/modules"
show_spinner "Создание test-php" make --no-print-directory module MODULE_STACK=php MODULE_TYPE=composer-lib MODULE_NAME=test-php MODULE_TARGET="$TEST_DIR/modules"
show_spinner "Создание test-python" make --no-print-directory module MODULE_STACK=python MODULE_TYPE=poetry MODULE_NAME=test-python MODULE_TARGET="$TEST_DIR/modules"
show_spinner "Создание test-rust" make --no-print-directory module MODULE_STACK=rust MODULE_TYPE=bin MODULE_NAME=test-rust MODULE_TARGET="$TEST_DIR/modules"
printf "\n"

# Тестирование базовых команд
log_section "Тестирование базовых команд"

run_test "make up" sh -c "make --no-print-directory up >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -q '^.*-devcontainer$' || podman ps --format '{{.Names}}' | grep -q '^.*-devcontainer$'"

run_test "container exec" sh -c "container_exec 'echo test-output' 2>/dev/null | grep -q 'test-output'"

run_test "make version" sh -c "make --no-print-directory version 2>/dev/null | grep -q 'Node.js'"

run_test "Контейнер работает" sh -c "docker ps --format '{{.Names}}' | grep -q '^.*-devcontainer$' || podman ps --format '{{.Names}}' | grep -q '^.*-devcontainer$'"

# Тестирование прав доступа
printf "\n"
log_section "Тестирование прав доступа"

run_test "Создание файла в контейнере" container_exec "touch $TEST_DIR/perm-test.txt" >/dev/null 2>&1

run_test "Запись файла работает" container_exec "echo write-test > $TEST_DIR/perm-test.txt" >/dev/null 2>&1

run_test "Чтение файла работает" sh -c "container_exec 'cat $TEST_DIR/perm-test.txt' 2>/dev/null | grep -q 'write-test'"

run_test "Перезапись файла работает" sh -c "container_exec 'echo rewrite-test > $TEST_DIR/perm-test.txt && cat $TEST_DIR/perm-test.txt' 2>/dev/null | grep -q 'rewrite-test'"

# Тестирование технологических стеков
printf "\n"
log_section "Тестирование команд внутри модулей в контейнере"

run_test "test-nodejs / npm install" container_exec "cd $TEST_DIR/modules/test-nodejs && npm install --silent" >/dev/null 2>&1

run_test "test-nodejs / npm test" sh -c "container_exec 'cd $TEST_DIR/modules/test-nodejs && npm test' 2>&1 | grep -q 'nodejs test passed'"

run_test "test-nodejs / npm run build" sh -c "container_exec 'cd $TEST_DIR/modules/test-nodejs && npm run build' 2>&1 | grep -q 'nodejs build passed'"

run_test "test-php / composer install" container_exec "cd $TEST_DIR/modules/test-php && composer install --quiet" >/dev/null 2>&1

run_test "test-php / composer test" sh -c "container_exec 'cd $TEST_DIR/modules/test-php && composer test' 2>&1 | grep -q 'php test passed'"

run_test "test-python / pytest" container_exec "cd $TEST_DIR/modules/test-python && pytest -q tests/test_main.py" >/dev/null 2>&1

run_test "test-rust / cargo build" container_exec "cd $TEST_DIR/modules/test-rust && cargo build --quiet" >/dev/null 2>&1

run_test "test-rust / cargo test" container_exec "cd $TEST_DIR/modules/test-rust && cargo test --quiet" >/dev/null 2>&1

# Остановка тестового контейнера
printf "\n"
if show_spinner "Остановка тестового контейнера" make --no-print-directory down; then
	log_success "Тестовый контейнер остановлен"
else
	log_warning "Не удалось остановить контейнер"
fi
printf "\n"

# Итоговая информация
log_success "ВСЕ ТЕСТЫ ПРОЙДЕНЫ!"
printf "\n"
log_info "Тестовое окружение (внутри контейнера):"
printf "  ${COLOR_SUCCESS}Каталог        ${COLOR_RESET} %s\n" "$TEST_DIR/"
printf "  ${COLOR_SUCCESS}Модули         ${COLOR_RESET} %s\n" "$TEST_DIR/modules/"
printf "  ${COLOR_SUCCESS}Журнал         ${COLOR_RESET} %s\n" "$TEST_DIR/test-results.log"
printf "\n"
log_info "Артефакты в /tmp автоматически очистятся при перезагрузке"
