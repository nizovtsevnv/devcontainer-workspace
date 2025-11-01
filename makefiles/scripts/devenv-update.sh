#!/bin/sh
# ===================================
# DevContainer Workspace - Обновление версии шаблона
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

log_section "Обновление версии шаблона"

# Определить статус инициализации
check_project_init_status

if [ "$STATUS" = "инициализирован" ]; then
	# ===========================================
	# Обновление инициализированного проекта
	# ===========================================
	log_success "Режим: инициализированный проект"

	# Проверка: есть uncommitted changes
	if ! require_clean_working_tree; then
		exit 1
	fi

	# Остановить контейнер если запущен
	# (вызываем через Make, т.к. это Make-специфичная логика)
	if command -v make >/dev/null 2>&1; then
		if make --no-print-directory stop-container-if-running 2>/dev/null; then
			:
		fi
	fi

	# Fetch обновлений
	git fetch template --tags --force >/dev/null 2>&1 || true

	# Определить текущую и последнюю версии
	current_version=$(get_template_version)
	latest_version=$(get_latest_semantic_tag)
	latest_version_clean=$(echo "$latest_version" | sed 's/^v//')

	printf "Текущая версия шаблона:    %s\n" "$current_version"
	printf "Последняя версия шаблона:  %s\n" "$latest_version_clean"

	# Показать изменения
	printf "\n"
	log_info "Изменения ($current_version..$latest_version_clean):"
	show_changelog "$current_version" "$latest_version"
	printf "\n"

	# Интерактивный выбор версии
	all_tags=$(get_all_semantic_tags)
	version_options=$(echo "$all_tags" | sed 's/^v//g' | tac | tr '\n' ' ')

	log_section "Выберите версию для обновления:"
	printf "${COLOR_INFO}(по умолчанию: %s, используйте ↑↓ и Enter)${COLOR_RESET}\n" "$latest_version_clean"
	target_version=$(select_menu $version_options) || exit 0

	# Проверка наличия .github перед merge
	has_project_github="no"
	if [ -d .github ]; then
		has_project_github="yes"
	fi

	# Определяем ref для merge
	if [ "$target_version" = "main" ]; then
		merge_ref="template/main"
	else
		merge_ref="v$target_version"
	fi

	# Выполняем merge
	git merge --allow-unrelated-histories --no-commit --no-ff "$merge_ref" >/dev/null 2>&1 || true

	# Автоматически разрешаем конфликты
	auto_resolve_template_conflicts

	# Проверяем нерешённые конфликты
	unresolved=$(git diff --name-only --diff-filter=U 2>/dev/null)
	if [ -n "$unresolved" ]; then
		printf "\n"
		log_error "Нерешённые конфликты:"
		echo "$unresolved" | while read -r file; do
			log_warning "$file"
		done
		printf "\n"
		log_info "Разрешите конфликты и выполните:"
		printf "  git add <файлы>\n"
		printf "  git commit\n"
		exit 1
	fi

	# Удаление артефактов шаблона
	remove_template_artifacts

	# Определяем новую версию
	if [ "$target_version" != "main" ]; then
		new_version="$target_version"
	else
		new_version=$(git describe --tags template/main 2>/dev/null | sed 's/^v//' || echo "main")
	fi

	# Сохраняем новую версию
	save_template_version "$new_version"

	# Показываем изменения
	printf "\n"
	log_info "Изменения подготовлены к коммиту:"
	git diff --cached --stat --color=always
	printf "\n"

	# Запрос на создание коммита
	if ! ask_yes_no "Создать коммит обновления шаблона?"; then
		printf "\n"
		log_info "Обновление завершено без коммита"
		printf "  Новая версия: %s\n" "$new_version"
		printf "  Изменения staged - выполните 'git commit' когда будете готовы\n"
		exit 0
	fi

	# Запрос сообщения коммита
	default_msg="chore: update devenv template to $new_version"
	commit_msg=$(ask_input_with_default "$default_msg" "Сообщение коммита:")

	if [ -n "$commit_msg" ]; then
		git commit -m "$commit_msg" >/dev/null 2>&1
		printf "\n"
		log_success "Обновление завершено!"
		printf "  Новая версия: %s\n" "$new_version"
		printf "  Коммит создан\n"
	else
		log_warning "Пустое сообщение - коммит пропущен"
		printf "  Изменения staged - выполните 'git commit' вручную\n"
	fi

	# Обновить Docker образ и пересоздать контейнер
	if command -v make >/dev/null 2>&1; then
		make --no-print-directory update-container-image 2>/dev/null || true
	fi

else
	# ===========================================
	# Обновление неинициализированного шаблона
	# ===========================================
	log_info "Режим: неинициализированный шаблон"

	# Проверка: есть uncommitted changes
	if ! require_clean_working_tree; then
		exit 1
	fi

	# Остановить контейнер если запущен
	if command -v make >/dev/null 2>&1; then
		if make --no-print-directory stop-container-if-running 2>/dev/null; then
			:
		fi
	fi

	# Определить текущую ветку
	current_branch=$(git branch --show-current)
	log_info "Обновление ветки: $current_branch"

	# Pull изменений
	if git pull 2>&1; then
		log_success "Изменения получены"
	else
		log_error "Не удалось выполнить git pull"
		exit 1
	fi

	# Определить версию шаблона через git
	template_version=$(git describe --tags 2>/dev/null | sed 's/^v//' || echo "unknown")
	printf "\n"
	log_success "Обновление завершено!"
	printf "  Версия шаблона: %s\n" "$template_version"

	# Обновить Docker образ и пересоздать контейнер
	if command -v make >/dev/null 2>&1; then
		make --no-print-directory update-container-image 2>/dev/null || true
	fi
fi
