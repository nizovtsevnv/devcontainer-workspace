#!/bin/sh
# ===================================
# DevContainer Workspace - Статус шаблона
# ===================================
set -e

# Определяем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Загружаем библиотеки
. "$SCRIPT_DIR/lib/ui.sh"
. "$SCRIPT_DIR/lib/git.sh"
. "$SCRIPT_DIR/lib/template.sh"

# ===================================
# Основная логика
# ===================================

log_info "Текущий статус шаблона разработки:"

# Определить текущую версию и статус
check_project_init_status
if [ "$STATUS" = "инициализирован" ]; then
	remote="template"
else
	remote="origin"
fi

# Получить текущую версию
current_version=$(get_template_version)

# Вывести статус
if [ "$STATUS" = "инициализирован" ]; then
	printf '%s\n' "Версия шаблона<COL>$current_version<ROW>Статус<COL>инициализирован" | print_table 16
else
	printf '%s\n' "Версия шаблона<COL>$current_version<ROW>Статус<COL>неинициализирован (разработка шаблона)" | print_table 16
fi

# Проверка обновлений
printf '\n'
if ! show_spinner "Проверка обновлений из $remote" git fetch "$remote" --tags; then
	log_error "Не удалось fetch из $remote remote"
	exit 1
fi

# Получить последний тег
latest_tag=$(git ls-remote --tags "$remote" 2>/dev/null | grep -v '\^{}' | awk '{print $2}' | sed 's|refs/tags/||' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
latest_tag_clean=$(echo "$latest_tag" | sed 's/^v//')
current_version_base=$(echo "$current_version" | sed 's/-.*$//')

# Определить суффикс версии
if [ -f .template-version ] || git describe --tags --exact-match HEAD >/dev/null 2>&1; then
	version_suffix=""
else
	version_suffix=" (модифицирована)"
fi

# Вывести результат проверки
if [ -z "$latest_tag" ]; then
	log_warning "Теги не найдены в upstream"
	printf "\n  Используйте: make devenv update для обновления\n"
elif [ "$current_version" = "unknown" ]; then
	log_warning "Текущая версия неизвестна"
	log_info "Последняя версия: $latest_tag_clean"
	printf "\n  Обновить: "
	log_success "make devenv update"
	printf "\n"
elif [ "$latest_tag_clean" = "$current_version_base" ]; then
	if [ -n "$version_suffix" ]; then
		log_info "У вас актуальная версия$version_suffix"
	else
		log_success "У вас актуальная версия"
	fi
else
	log_warning "Доступна новая версия: $latest_tag_clean"
	printf "\n"
	log_info "Changelog:"
	show_changelog "$current_version_base" "$remote/main"
	printf "\n  Обновить: "
	log_success "make devenv update"
	printf "\n"
fi
