# ===================================
# Переиспользуемые функции
# ===================================

# Функции логирования с использованием gum (если доступен) или printf
# Использование: $(call log-info,message)

define log-info
	if command -v gum >/dev/null 2>&1; then \
		gum style --foreground 36 "ℹ INFO: $(1)"; \
	else \
		printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) %s\n" "$(1)"; \
	fi
endef

define log-success
	if command -v gum >/dev/null 2>&1; then \
		gum style --foreground 2 "✓ OK: $(1)"; \
	else \
		printf "$(COLOR_SUCCESS)✓ OK:$(COLOR_RESET) %s\n" "$(1)"; \
	fi
endef

define log-warning
	if command -v gum >/dev/null 2>&1; then \
		gum style --foreground 214 "⚠ WARNING: $(1)"; \
	else \
		printf "$(COLOR_WARNING)⚠ WARNING:$(COLOR_RESET) %s\n" "$(1)"; \
	fi
endef

define log-error
	if command -v gum >/dev/null 2>&1; then \
		gum style --foreground 196 "✗ ERROR: $(1)" >&2; \
	else \
		printf "$(COLOR_ERROR)✗ ERROR:$(COLOR_RESET) %s\n" "$(1)" >&2; \
	fi
endef

define log-section
	if command -v gum >/dev/null 2>&1; then \
		gum style --bold --foreground 135 "▶ $(1)"; \
	else \
		printf "$(COLOR_SECTION)▶ %s$(COLOR_RESET)\n" "$(1)"; \
	fi
endef

# Определить версию шаблона (без префикса v)
# В неинициализированном шаблоне: из git тега
# В инициализированном проекте: из .template-version
# Использование: $(call get-template-version)
define get-template-version
	$(shell \
		if [ -f .template-version ]; then \
			cat .template-version 2>/dev/null | sed 's/^v//' || echo "unknown"; \
		else \
			git describe --tags --exact-match HEAD 2>/dev/null | sed 's/^v//' || \
			git describe --tags 2>/dev/null | sed 's/^v//' || \
			echo "unknown"; \
		fi \
	)
endef

# Проверка обязательной переменной
# Использование: $(call require-var,VAR_NAME)
define require-var
	if [ -z "$($(1))" ]; then \
		if command -v gum >/dev/null 2>&1; then \
			gum style --foreground 196 "✗ ERROR: Переменная $(1) не определена" >&2; \
		else \
			printf "$(COLOR_ERROR)✗ ERROR:$(COLOR_RESET) %s\n" "Переменная $(1) не определена" >&2; \
		fi; \
		exit 1; \
	fi
endef

# Запрос подтверждения с использованием gum (дефолт: NO)
# Использование: $(call ask-confirm,message)
define ask-confirm
	if command -v gum >/dev/null 2>&1; then \
		if ! gum confirm "$(1)?" --negative; then \
			gum style --foreground 36 "ℹ INFO: Отменено"; \
			exit 0; \
		fi; \
	else \
		printf "$(COLOR_WARNING)$(1)? [yes/NO]:$(COLOR_RESET) "; \
		read answer; \
		if [ "$$answer" != "yes" ] && [ "$$answer" != "y" ] && [ "$$answer" != "Y" ]; then \
			printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) %s\n" "Отменено"; \
			exit 0; \
		fi; \
	fi
endef

# Запрос подтверждения с использованием gum (дефолт: YES)
# Использование: $(call ask-confirm-default-yes,message)
define ask-confirm-default-yes
	if command -v gum >/dev/null 2>&1; then \
		if ! gum confirm "$(1)?" --default --negative; then \
			gum style --foreground 36 "ℹ INFO: Отменено"; \
			exit 0; \
		fi; \
	else \
		printf "$(COLOR_WARNING)$(1)? [YES/no]:$(COLOR_RESET) "; \
		read answer; \
		if [ "$$answer" = "no" ] || [ "$$answer" = "n" ] || [ "$$answer" = "N" ]; then \
			printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) %s\n" "Отменено"; \
			exit 0; \
		fi; \
	fi
endef

# Проверка существования команды
# Использование: $(call check-command,command-name)
define check-command
	command -v $(1) >/dev/null 2>&1 || \
		(if command -v gum >/dev/null 2>&1; then \
			gum style --foreground 196 "✗ ERROR: Команда '$(1)' не найдена" >&2; \
		else \
			printf "$(COLOR_ERROR)✗ ERROR:$(COLOR_RESET) %s\n" "Команда '$(1)' не найдена" >&2; \
		fi; exit 1)
endef

# Запуск контейнера если не запущен
# Использование: @$(call ensure-container-running)
define ensure-container-running
	if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		: ; \
	elif $(CONTAINER_RUNTIME) ps --format "{{.Names}}" 2>/dev/null | grep -q "^devcontainer-workspace-dev$$"; then \
		: ; \
	else \
		$(MAKE) up; \
	fi
endef

# Вывод команд в табличном формате (для help)
# Использование: $(call print-commands-table,pattern)
# Пример: $(call print-commands-table,"^## (init|up|down):")
define print-commands-table
	grep -hE $(1) $(MAKEFILE_LIST) | \
		sed 's/^## //' | \
		sort | \
		awk 'BEGIN {FS = ": "}; {printf "  $(COLOR_SUCCESS)make %-16s$(COLOR_RESET) %s\n", $$1, $$2}'
endef

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

# Создать README.md проекта (интерактивно)
# Использование: @$(call create-project-readme)
define create-project-readme
	printf "\n"; \
	if command -v gum >/dev/null 2>&1; then \
		if gum confirm "Создать README.md проекта?" --default; then \
			if [ -f "README.project.md" ]; then \
				cp README.project.md README.md; \
				gum style --foreground 2 "  ✓ README.md создан из шаблона"; \
			else \
				echo "# My Project" > README.md; \
				echo "" >> README.md; \
				echo "Проект создан из [DevContainer Workspace](https://github.com/nizovtsevnv/devcontainer-workspace)" >> README.md; \
				gum style --foreground 2 "  ✓ README.md создан"; \
			fi; \
		else \
			gum style --foreground 36 "  ℹ README.md не создан (можно создать позже)"; \
		fi; \
	else \
		printf "$(COLOR_INFO)Создать README.md проекта? [Y/n]:$(COLOR_RESET) "; \
		read CREATE_README; \
		if [ "$$CREATE_README" != "n" ] && [ "$$CREATE_README" != "N" ]; then \
			if [ -f "README.project.md" ]; then \
				cp README.project.md README.md; \
				printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) README.md создан из шаблона\n"; \
			else \
				echo "# My Project" > README.md; \
				echo "" >> README.md; \
				echo "Проект создан из [DevContainer Workspace](https://github.com/nizovtsevnv/devcontainer-workspace)" >> README.md; \
				printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) README.md создан\n"; \
			fi; \
		else \
			printf "  $(COLOR_INFO)ℹ$(COLOR_RESET) README.md не создан (можно создать позже)\n"; \
		fi; \
	fi
endef

# Проверить наличие uncommitted изменений
# Использование: @$(call require-clean-working-tree)
define require-clean-working-tree
	if ! git diff-index --quiet HEAD -- 2>/dev/null; then \
		$(call log-error,Есть незакоммиченные изменения!); \
		$(call log-info,Закоммитьте или stash их перед обновлением); \
		git status --short; \
		exit 1; \
	fi
endef

# Остановить контейнер если запущен
# Использование: @$(call stop-container-if-running)
define stop-container-if-running
	if $(CONTAINER_RUNTIME) ps --format "{{.Names}}" 2>/dev/null | grep -q "^$(CONTAINER_NAME)$$"; then \
		$(call log-info,Остановка контейнера перед обновлением...); \
		$(MAKE) down; \
	fi
endef

# Обновить Docker образ и пересоздать контейнер
# Использование: @$(call update-container-image)
define update-container-image
	printf "\n"; \
	if command -v gum >/dev/null 2>&1; then \
		gum style --foreground 36 "ℹ INFO: Обновление Docker образа и пересоздание контейнера..."; \
	else \
		printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) %s\n" "Обновление Docker образа и пересоздание контейнера..."; \
	fi; \
	$(CONTAINER_RUNTIME) pull $(CONTAINER_IMAGE) 2>&1 | grep -v "Trying to pull\|Writing manifest" || true; \
	$(MAKE) up >/dev/null 2>&1 || true; \
	if command -v gum >/dev/null 2>&1; then \
		gum style --foreground 2 "  ✓ Контейнер обновлен"; \
	else \
		printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Контейнер обновлен\n"; \
	fi
endef
