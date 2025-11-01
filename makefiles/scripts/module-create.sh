#!/bin/sh
# ===================================
# DevContainer Workspace - Wizard создания модуля
# ===================================
# Возвращает: STACK TYPE NAME через stdout в формате "stack type name"
set -e

# Определяем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Загружаем библиотеки
. "$SCRIPT_DIR/lib/ui.sh"

# Переменные (могут быть переданы из окружения)
MODULE_STACK="${MODULE_STACK:-}"
MODULE_TYPE="${MODULE_TYPE:-}"
MODULE_NAME="${MODULE_NAME:-}"

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
	log_info "Шаг 3/3: Введите имя модуля (буквы, цифры, дефис, underscore)"
	printf "\n"
	name=$(ask_input "example-module" "Имя модуля")
	if [ -z "$name" ]; then
		log_error "Имя не может быть пустым"
		exit 1
	fi
	printf "\n"
else
	name="$MODULE_NAME"
fi

# Возвращаем результаты в формате "stack type name"
echo "$stack $type $name"
