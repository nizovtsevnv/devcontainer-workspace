# ===================================
# Переиспользуемые функции
# ===================================

# Функции логирования с использованием gum (если доступен) или printf
# Использование: $(call log-info,message)

define log-info
	printf "$(COLOR_INFO)ℹ %s$(COLOR_RESET)\n" "$(1)"
endef

define log-success
	printf "$(COLOR_SUCCESS)✓ %s$(COLOR_RESET)\n" "$(1)"
endef

define log-warning
	printf "$(COLOR_WARNING)⚠ %s$(COLOR_RESET)\n" "$(1)"
endef

define log-error
	printf "$(COLOR_ERROR)✗ %s$(COLOR_RESET)\n" "$(1)" >&2
endef

define log-section
	printf "$(COLOR_SECTION)▶ %s$(COLOR_RESET)\n" "$(1)"
endef

# Вывод таблицы с фиксированной шириной первой колонки
# Параметр: $(1) - ширина первой колонки (обязательный)
# Использование:
#   - В Make: printf '%s\n' "key1<COL>value1<ROW>key2<COL>value2" | { $(call print-table,16); }
#   - В Shell: printf '%s\n' "$$data" | { $(call print-table,16); }
# Разделитель строк - <ROW>, разделитель колонок - <COL>
define print-table
	{ \
		data=$$(cat); \
		col_width=$(1); \
		echo "$$data" | sed 's/<ROW>/\n/g; s/<COL>/\x1F/g' | while IFS=$$'\x1F' read -r key value; do \
			key_len=$$(echo -n "$$key" | wc -m); \
			padding=$$(( col_width - key_len )); \
			if [ $$padding -lt 0 ]; then padding=0; fi; \
			printf "  $(COLOR_SUCCESS)%s%*s$(COLOR_RESET) %s\n" "$$key" $$padding "" "$$value"; \
		done; \
	}
endef

# Умный запуск контейнерной среды (с gum spin если доступен на хосте)
# Использование: @$(call ensure-devenv-ready)
define ensure-devenv-ready
	if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		: ; \
	elif $(CONTAINER_RUNTIME) ps --format "{{.Names}}" 2>/dev/null | grep -q "^$(CONTAINER_NAME)$$"; then \
		: ; \
	else \
		$(call log-spinner,Запуск контейнера ($(CONTAINER_NAME)),$(MAKE) --no-print-directory up-silent); \
	fi
endef

# Показать спиннер во время выполнения команды
# Логика выбора gum:
#   - Для git команд (начинаются с 'git '):
#     1. Если gum доступен на хосте - используем его
#     2. Иначе - fallback на статический спиннер
#   - Для остальных команд:
#     1. Если gum доступен на хосте - используем его
#     2. Если нет, но контейнер запущен - используем gum из контейнера
#     3. Иначе - fallback на статический спиннер
# Использование: @$(call log-spinner,message,command)
define log-spinner
	{ \
	case "$(2)" in \
		git\ *) \
			if command -v gum >/dev/null 2>&1; then \
				gum spin --spinner dot --title "$(1)" -- sh -c '$(2)'; \
			else \
				printf "⠙ $(1)...\n"; \
				sh -c '$(2)'; \
			fi \
			;; \
		*) \
			if command -v gum >/dev/null 2>&1; then \
				gum spin --spinner dot --title "$(1)" -- sh -c '$(2)'; \
			elif $(CONTAINER_RUNTIME) ps --format "{{.Names}}" 2>/dev/null | grep -q "^$(CONTAINER_NAME)$$"; then \
				$(CONTAINER_RUNTIME) exec $(CONTAINER_NAME) gum spin --spinner dot --title "$(1)" -- sh -c '$(2)'; \
			else \
				printf "⠙ $(1)...\n"; \
				sh -c '$(2)'; \
			fi \
			;; \
	esac; \
	}
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

# ===================================
# Функции работы с версиями и тегами
# ===================================

# Получить последний семантический тег (vX.Y.Z)
# Использование: LATEST_TAG=$(call get-latest-semantic-tag)
define get-latest-semantic-tag
$(shell git tag --list | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | sort -V | tail -1)
endef

# Получить все семантические теги (vX.Y.Z)
# Использование: ALL_TAGS=$(call get-all-semantic-tags)
define get-all-semantic-tags
$(shell git tag --list | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | sort -V)
endef

# Форматировать список версий для вывода (убрать v, через запятую)
# Параметр: $(1) - список тегов
# Использование: FORMATTED=$(call format-versions-list,$(TAGS))
define format-versions-list
$(shell echo "$(1)" | sed 's/^v//g' | tr '\n' ',' | sed 's/,$$//')
endef

# Сохранить версию шаблона в .template-version и добавить в git
# Параметр: $(1) - версия (без префикса v)
# Использование: @$(call save-template-version,1.0.0)
define save-template-version
	echo "$(1)" > .template-version; \
	git add .template-version
endef

# Показать changelog между двумя версиями
# Параметр: $(1) - from version (с или без v), $(2) - to ref (tag/branch)
# Использование: @$(call show-changelog,v1.0.0,origin/main)
define show-changelog
	FROM_VER="$(1)"; \
	if ! echo "$$FROM_VER" | grep -q '^v'; then \
		FROM_VER="v$$FROM_VER"; \
	fi; \
	git log --oneline --decorate "$$FROM_VER..$(2)" 2>/dev/null || \
		printf "  (changelog недоступен)\n"
endef

# Удалить артефакты шаблона (README.project.md, .github/)
# Использование: @$(call remove-template-artifacts)
define remove-template-artifacts
	if [ -d ".github" ]; then \
		rm -rf .github; \
		$(call log-info,Удалены GitHub workflows шаблона); \
	fi; \
	if [ -f "README.project.md" ]; then \
		rm -f README.project.md; \
		$(call log-info,Удален README.project.md шаблона); \
	fi
endef

# Автоматически разрешить конфликты слияния шаблона
# Принцип: upstream версии файлов шаблона (Makefile, makefiles/*, .devcontainer/*)
#         current версии остальных файлов проекта
# Использование: @$(call auto-resolve-template-conflicts)
define auto-resolve-template-conflicts
	CONFLICTS=$$(git diff --name-only --diff-filter=U 2>/dev/null); \
	if [ -n "$$CONFLICTS" ]; then \
		$(call log-info,Автоматическое разрешение конфликтов...); \
		RESOLVED=0; \
		UNRESOLVED=0; \
		echo "$$CONFLICTS" | while read conflict_file; do \
			case "$$conflict_file" in \
				.template-version|Makefile|makefiles/*|.devcontainer/*) \
					if git checkout --theirs "$$conflict_file" 2>/dev/null; then \
						git add "$$conflict_file" 2>/dev/null; \
						RESOLVED=$$((RESOLVED + 1)); \
						$(call log-success,Разрешен: $$conflict_file [upstream]); \
					fi \
					;; \
				.gitignore|.editorconfig) \
					if git checkout --theirs "$$conflict_file" 2>/dev/null; then \
						git add "$$conflict_file" 2>/dev/null; \
						RESOLVED=$$((RESOLVED + 1)); \
						$(call log-success,Разрешен: $$conflict_file [upstream]); \
					fi \
					;; \
				modules/*|src/*|public/*|tests/*) \
					if git checkout --ours "$$conflict_file" 2>/dev/null; then \
						git add "$$conflict_file" 2>/dev/null; \
						RESOLVED=$$((RESOLVED + 1)); \
						$(call log-success,Разрешен: $$conflict_file [current]); \
					fi \
					;; \
				README.md) \
					if [ -f ".template-version" ]; then \
						if git checkout --ours "$$conflict_file" 2>/dev/null; then \
							git add "$$conflict_file" 2>/dev/null; \
							RESOLVED=$$((RESOLVED + 1)); \
							$(call log-success,Разрешен: $$conflict_file [current]); \
						fi; \
					else \
						if git checkout --theirs "$$conflict_file" 2>/dev/null; then \
							git add "$$conflict_file" 2>/dev/null; \
							RESOLVED=$$((RESOLVED + 1)); \
							$(call log-success,Разрешен: $$conflict_file [upstream]); \
						fi; \
					fi \
					;; \
				*) \
					UNRESOLVED=$$((UNRESOLVED + 1)); \
					$(call log-warning,Требует ручного разрешения: $$conflict_file); \
					;; \
			esac; \
		done; \
		REMAINING=$$(git diff --name-only --diff-filter=U 2>/dev/null | wc -l); \
		if [ $$REMAINING -eq 0 ]; then \
			$(call log-success,Все конфликты разрешены автоматически); \
		else \
			$(call log-warning,Осталось конфликтов для ручного разрешения: $$REMAINING); \
		fi; \
	fi
endef

# ===================================
# Функции интерактивного ввода (Charm CLI)
# ===================================

# Запросить текстовый ввод от пользователя
# Параметр: $(1) - placeholder, $(2) - prompt text
# Возвращает: введенный текст
# Использование: NAME=$$($(call ask-input,my-module,Введите имя))
define ask-input
	if command -v gum >/dev/null 2>&1; then \
		gum input --placeholder "$(1)" --prompt "$(2) "; \
	else \
		printf "$(COLOR_INFO)$(2):$(COLOR_RESET) "; \
		read answer; \
		echo "$$answer"; \
	fi
endef

# Запросить текстовый ввод с дефолтным значением
# Параметр: $(1) - default value, $(2) - prompt text
# Возвращает: введенный текст или default
# Использование: URL=$$($(call ask-input-with-default,https://github.com/user/repo,Введите URL))
define ask-input-with-default
	if command -v gum >/dev/null 2>&1; then \
		gum input --value "$(1)" --prompt "$(2) "; \
	else \
		printf "$(COLOR_INFO)$(2) [$(1)]:$(COLOR_RESET) "; \
		read answer; \
		if [ -z "$$answer" ]; then \
			echo "$(1)"; \
		else \
			echo "$$answer"; \
		fi; \
	fi
endef

# Выбор из списка опций (меню)
# Параметр: $(1) - header text, $(2..N) - options (space-separated)
# Возвращает: выбранную опцию
# Использование: CHOICE=$$($(call ask-choose,Выберите стек,nodejs php python rust))
define ask-choose
	HEADER="$(1)"; \
	shift; \
	OPTIONS="$$@"; \
	if command -v gum >/dev/null 2>&1; then \
		echo "$$OPTIONS" | tr ' ' '\n' | gum choose --header "$$HEADER"; \
	else \
		printf "$(COLOR_INFO)$$HEADER:$(COLOR_RESET)\n"; \
		i=1; \
		for opt in $$OPTIONS; do \
			printf "  $$i) $$opt\n"; \
			i=$$((i + 1)); \
		done; \
		printf "\n$(COLOR_INFO)Ваш выбор:$(COLOR_RESET) "; \
		read choice_num; \
		echo "$$OPTIONS" | tr ' ' '\n' | sed -n "$${choice_num}p"; \
	fi
endef

# Фильтрация списка с поиском
# Параметр: $(1) - header text, $(2) - items (newline-separated or space-separated)
# Возвращает: выбранный элемент
# Использование: VERSION=$$($(call ask-filter,Выберите версию,$(VERSIONS)))
define ask-filter
	HEADER="$(1)"; \
	ITEMS="$(2)"; \
	if command -v gum >/dev/null 2>&1; then \
		echo "$$ITEMS" | tr ' ' '\n' | gum filter --header "$$HEADER" --placeholder "Поиск..."; \
	else \
		printf "$(COLOR_INFO)$$HEADER:$(COLOR_RESET)\n"; \
		echo "$$ITEMS" | tr ' ' '\n' | nl -w2 -s') '; \
		printf "\n$(COLOR_INFO)Ваш выбор (номер):$(COLOR_RESET) "; \
		read choice_num; \
		echo "$$ITEMS" | tr ' ' '\n' | sed -n "$${choice_num}p"; \
	fi
endef


# Вывод команд в табличном формате (для help)
# Использование: $(call print-commands-table,pattern)
# Пример: $(call print-commands-table,"^## (init|up|down):")
define print-commands-table
	grep -hE $(1) $(MAKEFILE_LIST) | \
		sed 's/^## //' | \
		sort | \
		awk 'BEGIN {FS = ": "; first=1}; {if (first) first=0; else printf "<ROW>"; printf "make %s<COL>%s", $$1, $$2}' | \
		{ $(call print-table,16); }
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
		$(CONTAINER_RUNTIME) stop $(CONTAINER_NAME) >/dev/null 2>&1; \
		$(CONTAINER_RUNTIME) rm $(CONTAINER_NAME) >/dev/null 2>&1; \
	fi
endef

# Обновить Docker образ и пересоздать контейнер
# Использование: @$(call update-container-image)
define update-container-image
	printf "\n"; \
	$(call log-spinner,Обновление Docker образа и пересоздание контейнера,sh -c '$(CONTAINER_RUNTIME) pull $(CONTAINER_IMAGE) >/dev/null 2>&1 && $(MAKE) --no-print-directory up-silent'); \
	$(call log-success,Контейнер обновлен)
endef
