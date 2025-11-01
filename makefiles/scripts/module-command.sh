#!/bin/sh
# ===================================
# DevContainer Workspace - Выполнение команд модулей
# ===================================
set -e

# Определяем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Загружаем библиотеки
. "$SCRIPT_DIR/lib/ui.sh"
. "$SCRIPT_DIR/lib/modules.sh"
. "$SCRIPT_DIR/lib/container.sh"

# Параметры
MODULE_NAME="$1"
MODULE_CMD="$2"
shift 2 2>/dev/null || true
MODULE_ARGS="$*"

MODULE_PATH="${MODULES_DIR:-modules}/$MODULE_NAME"

# Проверка существования модуля
if [ ! -d "$MODULE_PATH" ]; then
	log_error "Модуль '$MODULE_NAME' не найден в $MODULE_PATH"
	exit 1
fi

# Определить технологии модуля
MODULE_TECH=$(detect_module_tech "$MODULE_PATH")

# Если команда не передана - показать информацию о модуле
if [ -z "$MODULE_CMD" ]; then
	log_info "Модуль: $MODULE_NAME"
	printf "\n"

	# Вывод типа и версий для каждой технологии
	if [ -n "$MODULE_TECH" ]; then
		table_data=""
		for tech in $MODULE_TECH; do
			case "$tech" in
				nodejs)
					version=$(get_nodejs_version "$MODULE_PATH")
					if [ -n "$version" ]; then
						table_data="${table_data}Node.js<COL>$version<ROW>"
					else
						table_data="${table_data}Node.js<COL>(нет версии)<ROW>"
					fi
					;;
				php)
					version=$(get_php_version "$MODULE_PATH")
					if [ -n "$version" ]; then
						table_data="${table_data}PHP<COL>$version<ROW>"
					else
						table_data="${table_data}PHP<COL>(нет версии)<ROW>"
					fi
					;;
				python)
					version=$(get_python_version "$MODULE_PATH")
					if [ -n "$version" ]; then
						table_data="${table_data}Python<COL>$version<ROW>"
					else
						table_data="${table_data}Python<COL>(нет версии)<ROW>"
					fi
					;;
				rust)
					version=$(get_rust_version "$MODULE_PATH")
					if [ -n "$version" ]; then
						table_data="${table_data}Rust<COL>$version<ROW>"
					else
						table_data="${table_data}Rust<COL>(нет версии)<ROW>"
					fi
					;;
			esac
		done

		# Убираем последний <ROW> и выводим таблицу
		table_data=$(echo "$table_data" | sed 's/<ROW>$//')
		if [ -n "$table_data" ]; then
			printf "$table_data\n" | print_table 16
		fi
	fi

	# Вывод инструментов
	if [ -n "$MODULE_TECH" ]; then
		printf "\n"
		log_info "Инструменты:"

		for tech in $MODULE_TECH; do
			case "$tech" in
				nodejs)
					printf "make $MODULE_NAME build<COL>Собрать для production\n"
					printf "make $MODULE_NAME bun<COL>Выполнить команду пакетного менеджера Bun\n"
					printf "make $MODULE_NAME dev<COL>Запустить dev-сервер\n"
					printf "make $MODULE_NAME format<COL>Отформатировать код\n"
					printf "make $MODULE_NAME install<COL>Установить зависимости\n"
					printf "make $MODULE_NAME lint<COL>Проверить код линтером\n"
					printf "make $MODULE_NAME npm<COL>Выполнить команду пакетного менеджера npm\n"
					printf "make $MODULE_NAME pnpm<COL>Выполнить команду пакетного менеджера pnpm\n"
					printf "make $MODULE_NAME test<COL>Запустить тесты\n"
					printf "make $MODULE_NAME yarn<COL>Выполнить команду пакетного менеджера Yarn\n"
					;;
				php)
					printf "make $MODULE_NAME build<COL>Собрать для production\n"
					printf "make $MODULE_NAME composer<COL>Выполнить команду пакетного менеджера Composer\n"
					printf "make $MODULE_NAME install<COL>Установить зависимости\n"
					printf "make $MODULE_NAME lint<COL>Проверить код линтером\n"
					printf "make $MODULE_NAME test<COL>Запустить тесты\n"
					;;
				python)
					printf "make $MODULE_NAME format<COL>Отформатировать код\n"
					printf "make $MODULE_NAME install<COL>Установить зависимости\n"
					printf "make $MODULE_NAME lint<COL>Проверить код линтером\n"
					printf "make $MODULE_NAME pip<COL>Выполнить команду пакетного менеджера pip\n"
					printf "make $MODULE_NAME pipenv<COL>Выполнить команду пакетного менеджера Pipenv\n"
					printf "make $MODULE_NAME poetry<COL>Выполнить команду пакетного менеджера Poetry\n"
					printf "make $MODULE_NAME test<COL>Запустить тесты\n"
					printf "make $MODULE_NAME uv<COL>Выполнить команду пакетного менеджера uv\n"
					;;
				rust)
					printf "make $MODULE_NAME build<COL>Собрать релиз\n"
					printf "make $MODULE_NAME cargo<COL>Выполнить команду пакетного менеджера Cargo\n"
					printf "make $MODULE_NAME format<COL>Отформатировать код\n"
					printf "make $MODULE_NAME install<COL>Установить зависимости\n"
					printf "make $MODULE_NAME lint<COL>Проверить код clippy\n"
					printf "make $MODULE_NAME run<COL>Запустить приложение\n"
					printf "make $MODULE_NAME test<COL>Запустить тесты\n"
					;;
				makefile)
					printf "\nMakefile команды:\n"
					cd "$MODULE_PATH" && make help 2>/dev/null || printf "  (справка недоступна)\n"
					;;
			esac
		done | print_table 30
	else
		printf "\n"
		log_warning "Технологии не найдены в модуле"
		log_info "Создайте маркерные файлы (package.json, Cargo.toml, и т.д.)"
	fi
	exit 0
fi

# ===================================
# Выполнение команды
# ===================================

# Список известных пакетных менеджеров
KNOWN_PMS="bun cargo composer npm pip pipenv poetry pnpm uv yarn"

# Проверить, является ли команда пакетным менеджером
is_package_manager=0
for pm in $KNOWN_PMS; do
	if [ "$MODULE_CMD" = "$pm" ]; then
		is_package_manager=1
		break
	fi
done

# Если команда - пакетный менеджер
if [ $is_package_manager -eq 1 ]; then
	log_section "Модуль $MODULE_NAME: $MODULE_CMD $MODULE_ARGS"

	if [ -z "$MODULE_ARGS" ]; then
		container_exec "cd $MODULE_PATH && $MODULE_CMD --help"
	else
		container_exec "cd $MODULE_PATH && $MODULE_CMD $MODULE_ARGS"
	fi
	exit 0
fi

# Проверить, есть ли Makefile в модуле и содержит ли target
if [ -f "$MODULE_PATH/Makefile" ]; then
	if cd "$MODULE_PATH" && make -n "$MODULE_CMD" >/dev/null 2>&1; then
		# Target существует в Makefile - делегируем ему
		log_section "Модуль $MODULE_NAME: $MODULE_CMD"
		cd "$MODULE_PATH" && make "$MODULE_CMD" $MODULE_ARGS
		exit 0
	fi
fi

# Target не найден или нет Makefile - попробуем маппинг на PM
tech_count=$(echo "$MODULE_TECH" | wc -w)

if [ "$tech_count" -gt 1 ]; then
	# Несколько технологий - требуем Makefile
	log_error "Модуль '$MODULE_NAME' содержит несколько технологий: $MODULE_TECH"
	log_info "Создайте modules/$MODULE_NAME/Makefile для определения команды '$MODULE_CMD'"
	exit 1
fi

# Одна технология - маппируем команду на PM
case "$MODULE_TECH" in
	nodejs)
		pm=$(detect_nodejs_manager "$MODULE_PATH")
		mapped=$(map_nodejs_command "$MODULE_CMD")
		;;
	python)
		pm=$(detect_python_manager "$MODULE_PATH")
		mapped=$(map_python_command "$MODULE_CMD")
		;;
	php)
		pm="composer"
		mapped=$(map_php_command "$MODULE_CMD")
		;;
	rust)
		pm="cargo"
		mapped=$(map_rust_command "$MODULE_CMD")
		;;
	*)
		log_error "Неизвестная технология для модуля '$MODULE_NAME'"
		exit 1
		;;
esac

log_section "Модуль $MODULE_NAME: $pm $mapped $MODULE_ARGS"
container_exec "cd $MODULE_PATH && $pm $mapped $MODULE_ARGS"
