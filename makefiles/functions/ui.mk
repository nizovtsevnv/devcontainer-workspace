# ===================================
# UI функции (gum-based) и логирование
# ===================================

# Функции логирования с использованием gum
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

# ===================================
# Функции валидации и проверок
# ===================================

# Проверка обязательной переменной
# Использование: $(call require-var,VAR_NAME)
define require-var
	if [ -z "$($(1))" ]; then \
		gum style --foreground 196 "✗ ERROR: Переменная $(1) не определена" >&2; \
		exit 1; \
	fi
endef

# Проверка существования команды
# Использование: $(call check-command,command-name)
define check-command
	command -v $(1) >/dev/null 2>&1 || \
		(gum style --foreground 196 "✗ ERROR: Команда '$(1)' не найдена" >&2; exit 1)
endef

# ===================================
# Интерактивные функции (gum)
# ===================================

# Запрос подтверждения с использованием gum (дефолт: NO)
# Использование: $(call ask-confirm,message)
define ask-confirm
	if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		if ! gum confirm "$(1)?" --negative; then \
			gum style --foreground 36 "ℹ INFO: Отменено"; \
			exit 0; \
		fi; \
	else \
		$(call ensure-devenv-ready); \
		if ! $(MAKE) exec-interactive "gum confirm '$(1)?' --negative"; then \
			printf "\033[0;36mℹ INFO: Отменено\033[0m\n"; \
			exit 0; \
		fi; \
	fi
endef

# Запрос подтверждения с использованием gum (дефолт: YES)
# Использование: $(call ask-confirm-default-yes,message)
define ask-confirm-default-yes
	if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		if ! gum confirm "$(1)?" --default --negative; then \
			gum style --foreground 36 "ℹ INFO: Отменено"; \
			exit 0; \
		fi; \
	else \
		$(call ensure-devenv-ready); \
		if ! $(MAKE) exec-interactive "gum confirm '$(1)?' --default --negative"; then \
			printf "\033[0;36mℹ INFO: Отменено\033[0m\n"; \
			exit 0; \
		fi; \
	fi
endef

# Запросить текстовый ввод от пользователя
# Параметр: $(1) - placeholder, $(2) - prompt text
# Возвращает: введенный текст
# Использование: NAME=$$($(call ask-input,my-module,Введите имя))
define ask-input
	gum input --placeholder "$(1)" --prompt "$(2) "
endef

# Запросить текстовый ввод с дефолтным значением
# Параметр: $(1) - default value, $(2) - prompt text
# Возвращает: введенный текст или default
# Использование: URL=$$($(call ask-input-with-default,https://github.com/user/repo,Введите URL))
define ask-input-with-default
	if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		gum input --value "$(1)" --prompt "$(2) "; \
	else \
		$(call ensure-devenv-ready); \
		$(MAKE) exec-interactive "gum input --value '$(1)' --prompt '$(2) '"; \
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
	echo "$$OPTIONS" | tr ' ' '\n' | gum choose --header "$$HEADER"
endef

# Выбор одного элемента из переданного списка строк
# Параметр: $(1) - header text, $(2) - selected default, $(3) - options (newline or space separated)
# Возвращает: выбранную опцию
# Использование: VERSION=$$($(call ask-choose-single,Выберите версию,0.3.1,$$VERSION_OPTIONS))
define ask-choose-single
	if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		echo "$(3)" | tr ' ' '\n' | gum choose --header "$(1)" --selected="$(2)"; \
	else \
		$(call ensure-devenv-ready); \
		echo "$(3)" | $(MAKE) exec-interactive "tr ' ' '\n' | gum choose --header '$(1)' --selected='$(2)'"; \
	fi
endef

# Фильтрация списка с поиском
# Параметр: $(1) - header text, $(2) - items (newline-separated or space-separated)
# Возвращает: выбранный элемент
# Использование: VERSION=$$($(call ask-filter,Выберите версию,$(VERSIONS)))
define ask-filter
	HEADER="$(1)"; \
	ITEMS="$(2)"; \
	echo "$$ITEMS" | tr ' ' '\n' | gum filter --header "$$HEADER" --placeholder "Поиск..."
endef

# Multiline текстовый ввод
# Параметр: $(1) - header text, $(2) - placeholder text
# Возвращает: введенный текст
# Использование: MESSAGE=$$($(call ask-write,Сообщение коммита,Опишите изменения...))
define ask-write
	if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		gum write --header "$(1)" --placeholder "$(2)"; \
	else \
		$(call ensure-devenv-ready); \
		$(MAKE) exec-interactive "gum write --header '$(1)' --placeholder '$(2)'"; \
	fi
endef
