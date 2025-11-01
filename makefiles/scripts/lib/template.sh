#!/bin/sh
# ===================================
# Template библиотека для DevContainer Workspace
# ===================================
# Функции управления шаблоном и инициализацией
# Использование: . lib/template.sh

# Определить статус инициализации проекта
# Возвращает: переменную STATUS="инициализирован" или STATUS="не инициализирован"
# Использование:
#   check_project_init_status
#   if [ "$STATUS" = "инициализирован" ]; then ...
check_project_init_status() {
	STATUS="не инициализирован"

	if git remote get-url template >/dev/null 2>&1; then
		origin_url=$(git remote get-url origin 2>/dev/null || echo "")
		template_url=$(git remote get-url template 2>/dev/null || echo "")

		if [ -z "$origin_url" ]; then
			STATUS="инициализирован"
		else
			# Нормализация URL для сравнения
			origin_norm=$(echo "$origin_url" | sed 's|git@github.com:|https://github.com/|' | sed 's|\.git$||')
			template_norm=$(echo "$template_url" | sed 's|git@github.com:|https://github.com/|' | sed 's|\.git$||')

			if [ "$origin_norm" != "$template_norm" ]; then
				STATUS="инициализирован"
			fi
		fi
	fi
}

# Удалить артефакты шаблона (.github/, README.project.md)
# Использование: remove_template_artifacts
remove_template_artifacts() {
	# Загружаем UI библиотеку для вывода (если еще не загружена)
	if ! command -v log_success >/dev/null 2>&1; then
		SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
		. "$SCRIPT_DIR/ui.sh"
	fi

	if [ -d ".github" ]; then
		rm -rf .github
		log_success "Удалена директория .github/"
	fi

	if [ -f "README.project.md" ]; then
		rm -f README.project.md
		log_success "Удалён файл README.project.md"
	fi
}

# Автоматически разрешить конфликты слияния шаблона
# Принцип: upstream версии файлов шаблона (Makefile, makefiles/*, .devcontainer/*)
#         current версии остальных файлов проекта
# Использование: auto_resolve_template_conflicts
auto_resolve_template_conflicts() {
	# Загружаем UI библиотеку для вывода (если еще не загружена)
	if ! command -v log_success >/dev/null 2>&1; then
		SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
		. "$SCRIPT_DIR/ui.sh"
	fi

	conflicts=$(git diff --name-only --diff-filter=U 2>/dev/null)

	if [ -n "$conflicts" ]; then
		echo "$conflicts" | while read -r conflict_file; do
			case "$conflict_file" in
				.template-version|Makefile|makefiles/*|.devcontainer/*)
					git checkout --theirs "$conflict_file" >/dev/null 2>&1
					git add "$conflict_file" >/dev/null 2>&1
					;;
				.gitignore|.editorconfig)
					git checkout --theirs "$conflict_file" >/dev/null 2>&1
					git add "$conflict_file" >/dev/null 2>&1
					;;
				modules/*|src/*|public/*|tests/*)
					git checkout --ours "$conflict_file" >/dev/null 2>&1
					git add "$conflict_file" >/dev/null 2>&1
					;;
				README.md)
					if [ -f ".template-version" ]; then
						# Инициализированный проект - оставляем свой README
						git checkout --ours "$conflict_file" >/dev/null 2>&1
						git add "$conflict_file" >/dev/null 2>&1
					else
						# Неинициализированный - берем из шаблона
						git checkout --theirs "$conflict_file" >/dev/null 2>&1
						git add "$conflict_file" >/dev/null 2>&1
					fi
					;;
			esac
		done

		remaining=$(git diff --name-only --diff-filter=U 2>/dev/null | wc -l)

		if [ "$remaining" -eq 0 ]; then
			log_success "Конфликты разрешены автоматически"
		else
			log_warning "Осталось конфликтов для ручного разрешения: $remaining"
		fi
	fi
}

# Создать README.md проекта автоматически
# Использование: create_project_readme
create_project_readme() {
	# Загружаем UI библиотеку для вывода (если еще не загружена)
	if ! command -v log_success >/dev/null 2>&1; then
		SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
		. "$SCRIPT_DIR/ui.sh"
	fi

	if [ -f "README.project.md" ]; then
		cp README.project.md README.md
		log_success "README.md создан из шаблона"
	else
		cat > README.md <<'EOF'
# My Project

Проект создан из [DevContainer Workspace](https://github.com/nizovtsevnv/devcontainer-workspace)
EOF
		log_success "README.md создан"
	fi
}
