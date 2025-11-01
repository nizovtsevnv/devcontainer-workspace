# ===================================
# Функции управления шаблоном и инициализацией
# ===================================

# Определить статус инициализации проекта
# Возвращает: STATUS=инициализирован или STATUS=не инициализирован
# Использование: @$(call check-project-init-status)
define check-project-init-status
	STATUS="не инициализирован"; \
	if git remote get-url template >/dev/null 2>&1; then \
		ORIGIN_URL=$$(git remote get-url origin 2>/dev/null || echo ""); \
		TEMPLATE_URL=$$(git remote get-url template 2>/dev/null || echo ""); \
		if [ -z "$$ORIGIN_URL" ]; then \
			STATUS="инициализирован"; \
		else \
			ORIGIN_NORM=$$(echo "$$ORIGIN_URL" | sed 's|git@github.com:|https://github.com/|' | sed 's|\.git$$||'); \
			TEMPLATE_NORM=$$(echo "$$TEMPLATE_URL" | sed 's|git@github.com:|https://github.com/|' | sed 's|\.git$$||'); \
			if [ "$$ORIGIN_NORM" != "$$TEMPLATE_NORM" ]; then \
				STATUS="инициализирован"; \
			fi; \
		fi; \
	fi
endef

# Удалить артефакты шаблона (README.project.md, .github/)
# Использование: @$(call remove-template-artifacts)
define remove-template-artifacts
	if [ -f ".github/workflows/release.yml" ]; then \
		rm -f .github/workflows/release.yml; \
		if [ -z "$$(ls -A .github/workflows/ 2>/dev/null)" ]; then \
			rm -rf .github; \
		fi; \
	fi; \
	if [ -f "README.project.md" ]; then \
		rm -f README.project.md; \
	fi
endef

# Автоматически разрешить конфликты слияния шаблона
# Принцип: upstream версии файлов шаблона (Makefile, makefiles/*, .devcontainer/*)
#         current версии остальных файлов проекта
# Использование: @$(call auto-resolve-template-conflicts)
define auto-resolve-template-conflicts
	CONFLICTS=$$(git diff --name-only --diff-filter=U 2>/dev/null); \
	if [ -n "$$CONFLICTS" ]; then \
		echo "$$CONFLICTS" | while read conflict_file; do \
			case "$$conflict_file" in \
				.template-version|Makefile|makefiles/*|.devcontainer/*) \
					git checkout --theirs "$$conflict_file" >/dev/null 2>&1; \
					git add "$$conflict_file" >/dev/null 2>&1; \
					;; \
				.gitignore|.editorconfig) \
					git checkout --theirs "$$conflict_file" >/dev/null 2>&1; \
					git add "$$conflict_file" >/dev/null 2>&1; \
					;; \
				modules/*|src/*|public/*|tests/*) \
					git checkout --ours "$$conflict_file" >/dev/null 2>&1; \
					git add "$$conflict_file" >/dev/null 2>&1; \
					;; \
				README.md) \
					if [ -f ".template-version" ]; then \
						git checkout --ours "$$conflict_file" >/dev/null 2>&1; \
						git add "$$conflict_file" >/dev/null 2>&1; \
					else \
						git checkout --theirs "$$conflict_file" >/dev/null 2>&1; \
						git add "$$conflict_file" >/dev/null 2>&1; \
					fi \
					;; \
			esac; \
		done; \
		REMAINING=$$(git diff --name-only --diff-filter=U 2>/dev/null | wc -l); \
		if [ $$REMAINING -eq 0 ]; then \
			$(call log-success,Конфликты разрешены автоматически); \
		else \
			$(call log-warning,Осталось конфликтов для ручного разрешения: $$REMAINING); \
		fi; \
	fi
endef

# Создать README.md проекта (интерактивно)
# Использование: @$(call create-project-readme)
define create-project-readme
	printf "\n"; \
	$(call ask-confirm-default-yes,Создать README.md проекта?) || { \
		$(call log-info,README.md не создан (можно создать позже)); \
		exit 0; \
	}; \
	if [ -f "README.project.md" ]; then \
		cp README.project.md README.md; \
		$(call log-success,README.md создан из шаблона); \
	else \
		echo "# My Project" > README.md; \
		echo "" >> README.md; \
		echo "Проект создан из [DevContainer Workspace](https://github.com/nizovtsevnv/devcontainer-workspace)" >> README.md; \
		$(call log-success,README.md создан); \
	fi
endef
