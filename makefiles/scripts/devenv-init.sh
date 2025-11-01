#!/bin/sh
# ===================================
# DevContainer Workspace - Инициализация проекта
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

log_section "Инициализация проекта"

# Проверка что проект ещё не инициализирован
check_project_init_status
if [ "$STATUS" = "инициализирован" ]; then
	log_error "Проект уже инициализирован"
	log_info "Remote 'template' уже существует"
	exit 1
fi

# Определение версии и URL шаблона
current_version=$(git describe --tags 2>/dev/null || echo "unknown")
if [ "$current_version" = "unknown" ]; then
	log_error "Не удалось определить версию шаблона"
	log_info "Убедитесь что вы клонировали репозиторий с тегами: git clone --tags"
	exit 1
fi

template_url=$(git remote get-url origin 2>/dev/null)
if [ -z "$template_url" ]; then
	log_error "Не удалось определить URL шаблона из origin"
	log_info "Убедитесь что вы клонировали шаблон через git clone"
	exit 1
fi

log_info "Версия шаблона: $current_version"

# Сохраняем полную версию (с -N-gXXX если есть), а не только базовую
current_version_clean=$(echo "$current_version" | sed 's/^v//')

# ===========================================
# СЕКЦИЯ 1: Подготовка Git репозитория
# ===========================================
printf "\n"
log_section "Подготовка Git репозитория"

# 1.3. Выбор режима инициализации
printf "\n"
init_mode=$(select_menu "Новый репозиторий (локально)" "Удалённый репозиторий" "Отмена") || exit 0
if [ "$init_mode" = "Отмена" ]; then
	exit 0
fi
printf "\n"

# 1.4 или 1.5 в зависимости от режима
if [ "$init_mode" = "Новый репозиторий (локально)" ]; then
	rm -rf .git
	git init -q
	log_success "Создан новый Git репозиторий"
	origin_configured=false
else
	printf "\n"
	origin_url=$(ask_input_with_default "" "URL удалённого репозитория") || exit 0
	if [ -z "$origin_url" ]; then
		log_error "URL удалённого репозитория обязателен"
		exit 1
	fi

	# Клонирование репозитория
	temp_dir=$(mktemp -d /tmp/devenv-init.XXXXXX)

	if ! show_spinner "Клонирование репозитория" git clone -q "$origin_url" "$temp_dir" 2>&1; then
		rm -rf "$temp_dir"
		exit 1
	fi

	commit_count=$(count_commits "$temp_dir")
	if [ "$commit_count" -gt 0 ]; then
		log_info "В удалённом репозитории найдено $commit_count коммитов"
		printf "\n"
		if ! ask_yes_no "Продолжить инициализацию нового проекта? (история коммитов будет сохранена)"; then
			rm -rf "$temp_dir"
			exit 0
		fi
		printf "\n"
	fi

	rm -rf .git
	mv "$temp_dir/.git" ./
	rm -rf "$temp_dir"
	log_success "История Git перенесена из удалённого репозитория"
	origin_configured=true
fi

# 1.6. Настройка template remote
show_spinner "Настройка git remote template" git remote add template "$template_url" 2>/dev/null || true
git fetch template --tags --force >/dev/null 2>&1 || true

# 1.7. Обновление .gitignore
if grep -q "^modules/\*/" .gitignore 2>/dev/null; then
	sed -i '/^# Modules (template development)/,/^modules\/\*\//d' .gitignore
	log_success "Правило modules/*/ удалено из .gitignore"
fi

if grep -q "^\.template-version$" .gitignore 2>/dev/null; then
	sed -i '/^\.template-version$/d' .gitignore
	log_success ".template-version удалён из .gitignore"
fi

# ===========================================
# СЕКЦИЯ 2: Подготовка файлов проекта
# ===========================================
printf "\n"
log_section "Подготовка файлов проекта"

# 2.1. Создание README.md
create_project_readme

# 2.2. Сохранение .template-version
save_template_version "$current_version_clean"
log_success "Сохранена версия шаблона: $current_version_clean"

# 2.3. Удаление артефактов
remove_template_artifacts

# ===========================================
# СЕКЦИЯ 3: Завершение инициализации
# ===========================================
printf "\n"
log_section "Завершение инициализации"

# 3.1. git add -A
git add -A 2>/dev/null || true
log_success "Файлы добавлены в git staging область"

# 3.2. git commit
if [ "$init_mode" = "Новый репозиторий (локально)" ]; then
	commit_msg="chore: initialize project from devcontainer-workspace template"
else
	commit_msg="chore: reinitialize project from devcontainer-workspace template"
fi

git commit -q -m "$commit_msg" 2>/dev/null || true
printf "${COLOR_SUCCESS}✓${COLOR_RESET} Создан коммит \"$commit_msg\"\n"

# 3.3. git push (только если origin настроен)
if [ "$origin_configured" = "true" ]; then
	printf "\n"
	if ask_yes_no "Отправить изменения в удалённый репозиторий?"; then
		current_branch=$(git branch --show-current)
		if git push -u origin "$current_branch" 2>&1; then
			log_success "Изменения отправлены в удалённый репозиторий"
		else
			log_warning "Не удалось отправить изменения"
			log_info "Используйте: git push -u origin $current_branch"
		fi
	else
		log_info "Push пропущен - можно выполнить позже вручную"
	fi
fi

# Финальное сообщение
log_success "Проект успешно инициализирован!"
printf "\n"
log_info "Следующие шаги:"
printf "  1. Настройте README.md\n"
printf "  2. Добавьте модули в modules/\n"
printf "  3. Запустите: make up\n"
