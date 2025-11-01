#!/bin/sh
# ===================================
# Библиотека для работы с модулями
# ===================================

# ===================================
# Функции определения технологий
# ===================================

# Определить технологии в модуле по наличию маркерных файлов
# Параметр: $1 - путь к модулю
# Возвращает: список технологий (nodejs php python rust makefile gitlab github)
detect_module_tech() {
	module_path="$1"
	techs=""

	[ -f "$module_path/package.json" ] && techs="$techs nodejs"
	[ -f "$module_path/composer.json" ] && techs="$techs php"
	[ -f "$module_path/pyproject.toml" ] || [ -f "$module_path/requirements.txt" ] || [ -f "$module_path/setup.py" ] && techs="$techs python"
	[ -f "$module_path/Cargo.toml" ] && techs="$techs rust"
	[ -f "$module_path/Makefile" ] && techs="$techs makefile"
	[ -f "$module_path/.gitlab-ci.yml" ] && techs="$techs gitlab"
	[ -d "$module_path/.github/workflows" ] && techs="$techs github"

	echo "$techs" | sed 's/^ //'
}

# ===================================
# Функции определения пакетных менеджеров
# ===================================

# Определить Node.js пакетный менеджер по lock файлам
# Параметр: $1 - путь к модулю
# Приоритет: bun.lockb > pnpm-lock.yaml > yarn.lock > package-lock.json > bun (default)
detect_nodejs_manager() {
	module_path="$1"

	[ -f "$module_path/bun.lockb" ] && echo "bun" && return
	[ -f "$module_path/pnpm-lock.yaml" ] && echo "pnpm" && return
	[ -f "$module_path/yarn.lock" ] && echo "yarn" && return
	[ -f "$module_path/package-lock.json" ] && echo "npm" && return

	echo "bun"  # default
}

# Определить Python пакетный менеджер по lock файлам
# Параметр: $1 - путь к модулю
# Приоритет: uv.lock > poetry.lock > Pipfile > requirements.txt > uv (default)
detect_python_manager() {
	module_path="$1"

	[ -f "$module_path/uv.lock" ] && echo "uv" && return
	[ -f "$module_path/poetry.lock" ] && echo "poetry" && return
	[ -f "$module_path/Pipfile" ] && echo "pipenv" && return
	[ -f "$module_path/requirements.txt" ] && echo "pip" && return

	echo "uv"  # default
}

# PHP всегда использует composer
detect_php_manager() {
	echo "composer"
}

# Rust всегда использует cargo
detect_rust_manager() {
	echo "cargo"
}

# ===================================
# Функции получения информации о версиях
# ===================================

# Получить версию Node.js модуля из package.json
# Параметр: $1 - путь к модулю
# Возвращает: строку вида "1.0.0" или пустую строку
get_nodejs_version() {
	module_path="$1"
	if [ -f "$module_path/package.json" ]; then
		grep -m1 '"version"' "$module_path/package.json" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo ""
	else
		echo ""
	fi
}

# Получить версию PHP модуля из composer.json
# Параметр: $1 - путь к модулю
# Возвращает: строку вида "1.0.0" или пустую строку
get_php_version() {
	module_path="$1"
	if [ -f "$module_path/composer.json" ]; then
		grep -m1 '"version"' "$module_path/composer.json" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo ""
	else
		echo ""
	fi
}

# Получить версию Python модуля из pyproject.toml
# Параметр: $1 - путь к модулю
# Возвращает: строку вида "1.0.0" или пустую строку
get_python_version() {
	module_path="$1"
	if [ -f "$module_path/pyproject.toml" ]; then
		grep -m1 '^version[[:space:]]*=' "$module_path/pyproject.toml" | sed 's/.*version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/' || echo ""
	else
		echo ""
	fi
}

# Получить версию Rust модуля из Cargo.toml
# Параметр: $1 - путь к модулю
# Возвращает: строку вида "1.0.0" или пустую строку
get_rust_version() {
	module_path="$1"
	if [ -f "$module_path/Cargo.toml" ]; then
		grep -m1 '^version[[:space:]]*=' "$module_path/Cargo.toml" | sed 's/.*version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/' || echo ""
	else
		echo ""
	fi
}

# DEPRECATED: Оставлено для обратной совместимости
# Использует get_nodejs_version как fallback
get_module_version() {
	get_nodejs_version "$1"
}

# Получить информацию о версиях модуля
# Параметр: $1 - путь к модулю
# Возвращает: строку вида "Node.js-модуль 1.0.0, PHP-модуль 2.0.0"
# Для каждой технологии читает версию из соответствующего файла
get_module_info() {
	module_path="$1"
	tech_info=""

	# Node.js модуль
	if [ -f "$module_path/package.json" ]; then
		[ -n "$tech_info" ] && tech_info="$tech_info, "
		nodejs_version=$(get_nodejs_version "$module_path")
		if [ -n "$nodejs_version" ]; then
			tech_info="${tech_info}Node.js-модуль $nodejs_version"
		else
			tech_info="${tech_info}Node.js-модуль"
		fi
	fi

	# PHP модуль
	if [ -f "$module_path/composer.json" ]; then
		[ -n "$tech_info" ] && tech_info="$tech_info, "
		php_version=$(get_php_version "$module_path")
		if [ -n "$php_version" ]; then
			tech_info="${tech_info}PHP-модуль $php_version"
		else
			tech_info="${tech_info}PHP-модуль"
		fi
	fi

	# Python модуль
	if [ -f "$module_path/pyproject.toml" ] || [ -f "$module_path/requirements.txt" ] || [ -f "$module_path/setup.py" ]; then
		[ -n "$tech_info" ] && tech_info="$tech_info, "
		python_version=$(get_python_version "$module_path")
		if [ -n "$python_version" ]; then
			tech_info="${tech_info}Python-модуль $python_version"
		else
			tech_info="${tech_info}Python-модуль"
		fi
	fi

	# Rust модуль
	if [ -f "$module_path/Cargo.toml" ]; then
		[ -n "$tech_info" ] && tech_info="$tech_info, "
		rust_version=$(get_rust_version "$module_path")
		if [ -n "$rust_version" ]; then
			tech_info="${tech_info}Rust-модуль $rust_version"
		else
			tech_info="${tech_info}Rust-модуль"
		fi
	fi

	echo "$tech_info"
}

# Получить только версии модуля (компактный вывод)
# Параметр: $1 - путь к модулю
# Возвращает: строку вида "1.0.0" или "1.0.0, 2.0.0" или пустую строку
get_module_versions_compact() {
	module_path="$1"
	versions=""
	count=0

	# Собираем все версии
	if [ -f "$module_path/package.json" ]; then
		v=$(get_nodejs_version "$module_path")
		if [ -n "$v" ]; then
			[ -n "$versions" ] && versions="$versions, "
			versions="${versions}$v"
		fi
		count=$((count + 1))
	fi

	if [ -f "$module_path/composer.json" ]; then
		v=$(get_php_version "$module_path")
		if [ -n "$v" ]; then
			[ -n "$versions" ] && versions="$versions, "
			versions="${versions}$v"
		fi
		count=$((count + 1))
	fi

	if [ -f "$module_path/pyproject.toml" ] || [ -f "$module_path/requirements.txt" ] || [ -f "$module_path/setup.py" ]; then
		v=$(get_python_version "$module_path")
		if [ -n "$v" ]; then
			[ -n "$versions" ] && versions="$versions, "
			versions="${versions}$v"
		fi
		count=$((count + 1))
	fi

	if [ -f "$module_path/Cargo.toml" ]; then
		v=$(get_rust_version "$module_path")
		if [ -n "$v" ]; then
			[ -n "$versions" ] && versions="$versions, "
			versions="${versions}$v"
		fi
		count=$((count + 1))
	fi

	# Если модуль мультитехнологичный и версий нет, пометить это
	if [ $count -gt 1 ] && [ -z "$versions" ]; then
		echo "(мультитехнологичный)"
	else
		echo "$versions"
	fi
}

# ===================================
# Функции маппинга команд по технологиям
# ===================================

# Маппинг команд для Node.js (npm/yarn/pnpm/bun)
map_nodejs_command() {
	cmd="$1"

	case "$cmd" in
		install) echo "install" ;;
		run) echo "run" ;;
		dev) echo "run dev" ;;
		start) echo "start" ;;
		test) echo "test" ;;
		lint) echo "run lint" ;;
		format) echo "run format" ;;
		check) echo "run check" ;;
		build) echo "run build" ;;
		doc|docs) echo "run doc" ;;
		update) echo "update" ;;
		*) echo "$cmd" ;;
	esac
}

# Маппинг команд для Python (pip/poetry/pipenv/uv)
map_python_command() {
	cmd="$1"

	case "$cmd" in
		run) echo "run" ;;
		dev) echo "run dev" ;;
		test) echo "run pytest" ;;
		lint) echo "run ruff check" ;;
		format) echo "run ruff format" ;;
		check) echo "run mypy" ;;
		doc|docs) echo "run doc" ;;
		*) echo "$cmd" ;;
	esac
}

# Маппинг команд для PHP (composer)
map_php_command() {
	cmd="$1"

	case "$cmd" in
		install) echo "install" ;;
		run) echo "run" ;;
		dev) echo "run dev" ;;
		test) echo "run test" ;;
		lint) echo "run lint" ;;
		check) echo "run check" ;;
		build) echo "install --no-dev --optimize-autoloader" ;;
		doc|docs) echo "run doc" ;;
		update) echo "update" ;;
		*) echo "$cmd" ;;
	esac
}

# Маппинг команд для Rust (cargo)
map_rust_command() {
	cmd="$1"

	case "$cmd" in
		install) echo "install" ;;
		run) echo "run" ;;
		dev) echo "run" ;;
		test) echo "test" ;;
		check) echo "check" ;;
		lint) echo "clippy" ;;
		format) echo "fmt" ;;
		build) echo "build --release" ;;
		doc|docs) echo "doc" ;;
		clean) echo "clean" ;;
		update) echo "update" ;;
		*) echo "$cmd" ;;
	esac
}

# ===================================
# CLI интерфейс (если скрипт вызван напрямую)
# ===================================

# Проверка: скрипт вызван напрямую, а не через source?
# Если basename $0 содержит "modules.sh", значит вызван напрямую
if [ "$#" -gt 0 ] && [ "$(basename "$0")" = "modules.sh" ]; then
	command="$1"
	shift

	case "$command" in
		detect-tech)
			detect_module_tech "$@"
			;;
		detect-nodejs-pm)
			detect_nodejs_manager "$@"
			;;
		detect-python-pm)
			detect_python_manager "$@"
			;;
		detect-php-pm)
			detect_php_manager "$@"
			;;
		detect-rust-pm)
			detect_rust_manager "$@"
			;;
		get-version)
			get_module_version "$@"
			;;
		get-info)
			get_module_info "$@"
			;;
		map-nodejs)
			map_nodejs_command "$@"
			;;
		map-python)
			map_python_command "$@"
			;;
		map-php)
			map_php_command "$@"
			;;
		map-rust)
			map_rust_command "$@"
			;;
		*)
			echo "Unknown command: $command" >&2
			exit 1
			;;
	esac
fi
