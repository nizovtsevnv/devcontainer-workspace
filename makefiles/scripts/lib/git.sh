#!/bin/sh
# ===================================
# Git библиотека для DevContainer Workspace
# ===================================
# Функции работы с версиями и git
# Использование: . lib/git.sh

# Определить версию шаблона (без префикса v)
# В неинициализированном шаблоне: из git тега
# В инициализированном проекте: из .template-version
# Использование: version=$(get_template_version)
get_template_version() {
	if [ -f .template-version ]; then
		version=$(cat .template-version 2>/dev/null | sed 's/^v//')
		if [ -n "$version" ]; then
			echo "$version"
		else
			echo "unknown"
		fi
	else
		# Сначала пробуем exact match
		version=$(git describe --tags --exact-match HEAD 2>/dev/null | sed 's/^v//')
		if [ -n "$version" ]; then
			echo "$version"
			return
		fi

		# Затем пробуем обычный describe
		version=$(git describe --tags 2>/dev/null | sed 's/^v//')
		if [ -n "$version" ]; then
			echo "$version"
			return
		fi

		echo "unknown"
	fi
}

# Получить последний семантический тег (vX.Y.Z)
# Использование: latest_tag=$(get_latest_semantic_tag)
get_latest_semantic_tag() {
	git tag --list | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1
}

# Получить все семантические теги (vX.Y.Z)
# Использование: all_tags=$(get_all_semantic_tags)
get_all_semantic_tags() {
	git tag --list | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V
}

# Получить мажорную версию из версии
# Параметр: $1 - версия (может быть с префиксом v)
# Использование: major=$(get_major_version "0.4.0")
get_major_version() {
	echo "$1" | sed 's/^v//' | cut -d'.' -f1
}

# Получить последний патч для каждой группы MAJOR.MINOR
# Параметр: $1 - мажорная версия (без v)
# Возвращает: список тегов (с v), по одному на MAJOR.MINOR группу
# Использование: patches=$(get_latest_patch_per_minor "0")
get_latest_patch_per_minor() {
	major="$1"
	git tag --list | grep -E "^v${major}\.[0-9]+\.[0-9]+$" | sort -V | \
	awk -F'.' '{key=$1"."$2; last[key]=$0} END {for (k in last) print last[k]}' | sort -Vr
}

# Получить версию HEAD ветки template/main
# Возвращает: версию без префикса v (например "0.4.0-10-gdef456")
# Использование: main_ver=$(get_template_main_version)
get_template_main_version() {
	git describe --tags template/main 2>/dev/null | sed 's/^v//' || echo ""
}

# Получить отфильтрованный список версий для выбора
# Параметр: $1 - текущая версия, $2 - макс количество (по умолчанию 10)
# Возвращает: список версий через пробел
# Использование: options=$(get_filtered_version_options "0.4.0" 10)
get_filtered_version_options() {
	current_version="$1"
	max_count="${2:-10}"

	# Извлечь мажорную версию
	major=$(get_major_version "$current_version")

	# Получить версию template/main
	main_version=$(get_template_main_version)
	latest_tag=$(get_latest_semantic_tag | sed 's/^v//')

	# Собрать результат
	result=""

	# Если есть патч-коммиты после последнего тега, добавить как первую опцию
	main_version_base=$(echo "$main_version" | sed 's/-[0-9]*-g.*//')
	if [ -n "$main_version" ] && [ "$main_version" != "$latest_tag" ] && [ "$main_version_base" = "$latest_tag" ]; then
		result="$main_version"
	fi

	# Получить последние патчи по каждой minor версии
	patches=$(get_latest_patch_per_minor "$major" | sed 's/^v//' | head -n "$max_count")

	# Объединить результаты
	if [ -n "$result" ]; then
		echo "$result"
		echo "$patches"
	else
		echo "$patches"
	fi
}

# Форматировать список версий для вывода (убрать v, через запятую)
# Параметр: $1 - список тегов (newline-separated)
# Использование: formatted=$(format_versions_list "$tags")
format_versions_list() {
	echo "$1" | sed 's/^v//g' | tr '\n' ',' | sed 's/,$//'
}

# Сохранить версию шаблона в .template-version и добавить в git
# Параметр: $1 - версия (без префикса v)
# Использование: save_template_version "1.0.0"
save_template_version() {
	echo "$1" > .template-version
	git add -f .template-version 2>/dev/null || true
}

# Показать changelog между двумя версиями
# Параметры: $1 - from version (с или без v), $2 - to ref (tag/branch)
# Использование: show_changelog "v1.0.0" "origin/main"
show_changelog() {
	from_ver="$1"
	if ! echo "$from_ver" | grep -q '^v'; then
		from_ver="v$from_ver"
	fi
	git log --oneline --decorate "$from_ver..$2" 2>/dev/null || \
		printf "  (changelog недоступен)\n"
}

# Проверить наличие uncommitted изменений
# Возвращает: 0 если нет изменений, 1 если есть
# Использование: if ! require_clean_working_tree; then ...
require_clean_working_tree() {
	if ! git diff-index --quiet HEAD -- 2>/dev/null; then
		# Загружаем UI библиотеку для вывода (если еще не загружена)
		if ! command -v log_error >/dev/null 2>&1; then
			SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
			. "$SCRIPT_DIR/ui.sh"
		fi
		log_error "Есть незакоммиченные изменения!"
		log_info "Закоммитьте или stash их перед обновлением"
		git status --short
		return 1
	fi
	return 0
}

# Проверить доступность удалённого репозитория
# Параметр: $1 - URL репозитория
# Возвращает: 0 если доступен, 1 если нет
# Использование: if check_remote_accessible "git@github.com:user/repo.git"; then ...
check_remote_accessible() {
	if ! git ls-remote "$1" >/dev/null 2>&1; then
		if ! command -v log_error >/dev/null 2>&1; then
			SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
			. "$SCRIPT_DIR/ui.sh"
		fi
		log_error "Удалённый репозиторий недоступен: $1"
		log_info "Проверьте URL и доступ к репозиторию"
		return 1
	fi
	return 0
}

# Подсчитать количество коммитов в репозитории
# Параметр: $1 - путь к git репозиторию (опционально, по умолчанию текущий)
# Возвращает: число коммитов
# Использование: count=$(count_commits "/path/to/repo")
count_commits() {
	if [ -n "$1" ]; then
		git -C "$1" rev-list --count HEAD 2>/dev/null || echo "0"
	else
		git rev-list --count HEAD 2>/dev/null || echo "0"
	fi
}

# Клонировать репозиторий во временную папку
# Параметр: $1 - URL репозитория
# Возвращает: путь к временной папке через stdout, exit code 0 при успехе
# Использование: temp_dir=$(clone_to_temp "https://github.com/user/repo.git")
clone_to_temp() {
	temp_dir=$(mktemp -d /tmp/devenv-init.XXXXXX)
	if git clone -q "$1" "$temp_dir" 2>&1; then
		echo "$temp_dir"
		return 0
	else
		rm -rf "$temp_dir"
		return 1
	fi
}
