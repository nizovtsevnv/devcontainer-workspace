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
. "$SCRIPT_DIR/lib/container.sh"

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
	stop_container_if_running 2>/dev/null || true

	# Fetch обновлений
	show_spinner "Проверка обновлений из template" git fetch template --tags --force 2>&1 || true

	# Определить текущую и последнюю версии
	current_version=$(get_template_version)

	# Проверить, содержит ли версия дополнительные коммиты (-N-gXXX)
	# Если в .template-version только базовая версия (например 0.4.0),
	# а есть файлы из более новых коммитов, это может привести к конфликтам
	if ! echo "$current_version" | grep -q -- '-'; then
		# Версия базовая (без -N-gXXX)
		# Проверим последний коммит template merge
		last_merge=$(git log --grep="devenv template" --format="%H" -1 2>/dev/null)
		if [ -n "$last_merge" ]; then
			# Попробуем определить точную версию из этого коммита
			merge_version=$(git describe --tags "$last_merge" 2>/dev/null | sed 's/^v//' || echo "")
			if [ -n "$merge_version" ] && [ "$merge_version" != "$current_version" ]; then
				log_warning "В .template-version базовая версия $current_version, но код из $merge_version"
				log_info "Рекомендуется обновиться на последнюю версию для избежания конфликтов"
			fi
		fi
	fi

	latest_version=$(get_latest_semantic_tag)
	latest_version_clean=$(echo "$latest_version" | sed 's/^v//')

	# Получить версию main (может содержать патч-коммиты)
	main_version=$(get_template_main_version)
	if [ -n "$main_version" ]; then
		display_version="$main_version"
	else
		display_version="$latest_version_clean"
	fi

	printf "Текущая версия шаблона:    %s\n" "$current_version"
	printf "Последняя версия шаблона:  %s\n" "$display_version"

	# Показать изменения
	printf "\n"
	log_info "Изменения ($current_version..$display_version):"
	show_changelog "$current_version" "template/main"
	printf "\n"

	# Интерактивный выбор версии (умная фильтрация)
	major=$(get_major_version "$current_version")
	version_options=$(get_filtered_version_options "$current_version" 10 | tr '\n' ' ')

	log_section "Выберите версию для обновления:"
	target_version=$(select_menu $version_options) || exit 0

	# Проверка: не пытаемся ли обновиться на ту же версию
	current_version_base=$(echo "$current_version" | sed 's/-.*$//')
	target_version_base=$(echo "$target_version" | sed 's/-.*$//')

	if [ "$target_version_base" = "$current_version_base" ]; then
		printf "\n"
		log_warning "Выбрана текущая или близкая версия ($target_version)"
		if ! ask_yes_no "Продолжить? (может привести к конфликтам)"; then
			log_info "Обновление отменено"
			exit 0
		fi
		printf "\n"
	fi

	# Проверка наличия .github перед merge
	has_project_github="no"
	if [ -d .github ]; then
		has_project_github="yes"
	fi

	# Определяем ref для merge
	if echo "$target_version" | grep -q -- '-[0-9]*-g'; then
		# Выбрана версия с патч-коммитами (X.Y.Z-N-gHASH) - используем template/main
		merge_ref="template/main"
	else
		# Выбран тег (X.Y.Z)
		merge_ref="v$target_version"
	fi

	# Выполняем merge
	tmpfile=$(mktemp)
	if ! git merge --allow-unrelated-histories --no-commit --no-ff "$merge_ref" > "$tmpfile" 2>&1; then
		# Merge с конфликтами - это нормально, продолжаем
		# Но показываем вывод если это не конфликт, а другая ошибка
		if ! grep -q "Automatic merge failed" "$tmpfile"; then
			cat "$tmpfile" >&2
		fi
	fi
	rm -f "$tmpfile"

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
	new_version="$target_version"

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
		tmpfile=$(mktemp)
		if git commit -m "$commit_msg" > "$tmpfile" 2>&1; then
			printf "\n"
			log_success "Обновление завершено!"
			printf "  Новая версия: %s\n" "$new_version"
			printf "  Коммит создан\n"
		else
			printf "\n"
			log_error "Ошибка при создании коммита:"
			cat "$tmpfile" >&2
			printf "\n"
			log_info "Изменения staged - выполните 'git commit' вручную"
		fi
		rm -f "$tmpfile"
	else
		log_warning "Пустое сообщение - коммит пропущен"
		printf "  Изменения staged - выполните 'git commit' вручную\n"
	fi

	# Обновить Docker образ и пересоздать контейнер
	update_container_image 2>/dev/null || true

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
	stop_container_if_running 2>/dev/null || true

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
	update_container_image 2>/dev/null || true
fi
