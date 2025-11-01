#!/bin/sh
# ===================================
# DevContainer Workspace - Создание модуля
# ===================================
set -e

# Определяем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Загружаем библиотеки
. "$SCRIPT_DIR/lib/ui.sh"
. "$SCRIPT_DIR/lib/container.sh"

# Переменные (могут быть переданы из окружения)
MODULE_STACK="${MODULE_STACK:-}"
MODULE_TYPE="${MODULE_TYPE:-}"
MODULE_NAME="${MODULE_NAME:-}"
MODULE_TARGET="${MODULE_TARGET:-modules}"

# ===================================
# Wizard
# ===================================

log_section "Создание нового модуля"
printf "\n"

# Шаг 1/3: Выбор стека технологий
if [ -z "$MODULE_STACK" ]; then
	log_info "Шаг 1/3: Выберите стек технологий"
	display=$(select_menu "Node.js" "PHP" "Python" "Rust") || exit 1
	case "$display" in
		"Node.js") stack="nodejs" ;;
		"PHP") stack="php" ;;
		"Python") stack="python" ;;
		"Rust") stack="rust" ;;
	esac
	printf "\n"
else
	stack="$MODULE_STACK"
fi

# Шаг 2/3: Выбор типа проекта
if [ -z "$MODULE_TYPE" ]; then
	log_info "Шаг 2/3: Выберите тип проекта"

	case "$stack" in
		nodejs)
			sel=$(select_menu "Bun (TypeScript)" "npm (TypeScript)" "pnpm (TypeScript)" "yarn (TypeScript)" "Next.js (TypeScript + Tailwind)" "Expo (TypeScript)" "SvelteKit (TypeScript)") || exit 1
			case "$sel" in
				"Bun"*) type="bun" ;;
				"npm"*) type="npm" ;;
				"pnpm"*) type="pnpm" ;;
				"yarn"*) type="yarn" ;;
				"Next.js"*) type="nextjs" ;;
				"Expo"*) type="expo" ;;
				"SvelteKit"*) type="svelte" ;;
			esac
			;;
		php)
			sel=$(select_menu "Composer library" "Composer project" "Laravel") || exit 1
			case "$sel" in
				"Composer library") type="composer-lib" ;;
				"Composer project") type="composer-project" ;;
				"Laravel") type="laravel" ;;
			esac
			;;
		python)
			sel=$(select_menu "UV (быстрый, рекомендуется)" "Poetry") || exit 1
			case "$sel" in
				"UV"*) type="uv" ;;
				"Poetry") type="poetry" ;;
			esac
			;;
		rust)
			sel=$(select_menu "Binary (приложение)" "Library (библиотека)" "Dioxus (веб-приложение)") || exit 1
			case "$sel" in
				"Binary"*) type="bin" ;;
				"Library"*) type="lib" ;;
				"Dioxus"*) type="dioxus" ;;
			esac
			;;
	esac
	printf "\n"
else
	type="$MODULE_TYPE"
fi

# Шаг 3/3: Запрос имени модуля
if [ -z "$MODULE_NAME" ]; then
	log_info "Шаг 3/3: Введите имя модуля (буквы, цифры, дефис, подчеркивание)"
	printf "\n"
	name=$(ask_input_with_default "example-module" "Имя модуля")
	if [ -z "$name" ]; then
		log_error "Имя не может быть пустым"
		exit 1
	fi
	printf "\n"
else
	name="$MODULE_NAME"
fi

# ===================================
# Валидация
# ===================================

# Валидация имени (только буквы, цифры, дефис, подчеркивание)
if ! echo "$name" | grep -qE '^[a-zA-Z0-9_-]+$'; then
	log_error "Имя может содержать только буквы цифры дефис и подчеркивание"
	exit 1
fi

# Проверка что модуль не существует
if [ -d "$MODULE_TARGET/$name" ]; then
	log_error "Модуль $name уже существует в $MODULE_TARGET/"
	exit 1
fi

# Создание директории если не существует
container_exec "mkdir -p $MODULE_TARGET" >/dev/null 2>&1

# ===================================
# Генераторы модулей
# ===================================

create_module() {
	case "$stack-$type" in
		nodejs-bun)
			show_spinner "Создание Bun проекта: $name" \
				container_exec "cd $MODULE_TARGET && bun init -y $name"

			# Добавить scripts для тестов
			container_exec "cd $MODULE_TARGET/$name && npm pkg set scripts.test=\"echo 'nodejs test passed'\" && npm pkg set scripts.build=\"echo 'nodejs build passed'\"" >/dev/null 2>&1

			log_success "Bun проект создан: $MODULE_TARGET/$name"
			;;

		nodejs-npm)
			show_spinner "Создание npm проекта: $name" \
				container_exec "mkdir -p $MODULE_TARGET/$name && cd $MODULE_TARGET/$name && npm init -y && npm pkg set type=module"

			log_success "npm проект создан: $MODULE_TARGET/$name"
			;;

		nodejs-pnpm)
			show_spinner "Создание pnpm проекта: $name" \
				container_exec "mkdir -p $MODULE_TARGET/$name && cd $MODULE_TARGET/$name && pnpm init"

			log_success "pnpm проект создан: $MODULE_TARGET/$name"
			;;

		nodejs-yarn)
			show_spinner "Создание yarn проекта: $name" \
				container_exec "mkdir -p $MODULE_TARGET/$name && cd $MODULE_TARGET/$name && yarn init -y"

			log_success "yarn проект создан: $MODULE_TARGET/$name"
			;;

		nodejs-nextjs)
			log_info "Создание Next.js проекта: $name"
			printf "\n"

			container_exec_interactive "cd $MODULE_TARGET && bunx create-next-app@latest $name --typescript --tailwind --app --no-src-dir --import-alias @/* --turbopack --skip-install"

			printf "\n"
			log_success "Next.js проект создан: $MODULE_TARGET/$name"

			show_spinner "Установка зависимостей" \
				container_exec "cd $MODULE_TARGET/$name && bun install"

			log_success "Зависимости установлены"
			;;

		nodejs-expo)
			show_spinner "Создание Expo проекта: $name" \
				container_exec "cd $MODULE_TARGET && bunx create-expo-app@latest $name --template blank-typescript"

			log_success "Expo проект создан: $MODULE_TARGET/$name"
			;;

		nodejs-svelte)
			show_spinner "Создание SvelteKit проекта: $name" \
				container_exec "cd $MODULE_TARGET && bunx sv create $name --template minimal --types ts --no-add-ons --no-install"

			log_success "SvelteKit проект создан: $MODULE_TARGET/$name"

			show_spinner "Установка зависимостей" \
				container_exec "cd $MODULE_TARGET/$name && bun install"

			log_success "Зависимости установлены"
			;;

		php-composer-lib)
			show_spinner "Создание Composer library: $name" \
				container_exec "mkdir -p $MODULE_TARGET/$name && cd $MODULE_TARGET/$name && composer init --name=vendor/$name --type=library --no-interaction"

			# Добавить test script
			container_exec "cd $MODULE_TARGET/$name && composer config scripts.test \"echo 'php test passed'\"" >/dev/null 2>&1

			log_success "Composer library создан: $MODULE_TARGET/$name"
			;;

		php-composer-project)
			show_spinner "Создание Composer project: $name" \
				container_exec "mkdir -p $MODULE_TARGET/$name && cd $MODULE_TARGET/$name && composer init --name=vendor/$name --type=project --no-interaction"

			log_success "Composer project создан: $MODULE_TARGET/$name"
			;;

		php-laravel)
			# Проверка установки Laravel installer
			if ! container_exec "command -v laravel" >/dev/null 2>&1; then
				log_info "Установка Laravel installer..."
				container_exec "composer global require laravel/installer" >/dev/null 2>&1
			fi

			show_spinner "Создание Laravel проекта: $name" \
				container_exec "cd $MODULE_TARGET && laravel new $name --no-interaction"

			log_success "Laravel проект создан: $MODULE_TARGET/$name"
			;;

		python-uv)
			show_spinner "Создание UV проекта: $name" \
				container_exec "cd $MODULE_TARGET && uv init $name"

			log_success "UV проект создан: $MODULE_TARGET/$name"
			;;

		python-poetry)
			show_spinner "Создание Poetry проекта: $name" \
				container_exec "cd $MODULE_TARGET && poetry new $name"

			# Создать test_main.py
			container_exec "printf 'def test_main():\n    print(\"python test passed\")\n    assert True\n' > $MODULE_TARGET/$name/tests/test_main.py" >/dev/null 2>&1

			log_success "Poetry проект создан: $MODULE_TARGET/$name"
			;;

		rust-bin)
			show_spinner "Создание Cargo binary: $name" \
				container_exec "cd $MODULE_TARGET && cargo new $name"

			log_success "Cargo binary создан: $MODULE_TARGET/$name"
			;;

		rust-lib)
			show_spinner "Создание Cargo library: $name" \
				container_exec "cd $MODULE_TARGET && cargo new $name --lib"

			log_success "Cargo library создан: $MODULE_TARGET/$name"
			;;

		rust-dioxus)
			# Проверка установки dioxus-cli
			if ! container_exec "command -v dx" >/dev/null 2>&1; then
				log_info "Установка Dioxus CLI..."
				container_exec "cargo install dioxus-cli" >/dev/null 2>&1
			fi

			show_spinner "Создание Dioxus проекта: $name" \
				container_exec "cd $MODULE_TARGET && dx new $name --platform web"

			log_success "Dioxus проект создан: $MODULE_TARGET/$name"
			;;

		*)
			log_error "Неизвестный тип модуля: $stack-$type"
			exit 1
			;;
	esac
}

# Запуск генератора
create_module
