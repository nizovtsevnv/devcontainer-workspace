# ===================================
# UI функции и логирование
# ===================================

# Функции логирования
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
# Параметр: $(1) - сообщение, $(2) - команда
# Использование: @$(call log-spinner,message,command)
define log-spinner
	title="$(1)"; \
	tmpfile=$$(mktemp); \
	trap "rm -f $$tmpfile" EXIT INT TERM; \
	\
	$(2) > "$$tmpfile" 2>&1 & \
	pid=$$!; \
	\
	sp='◐◓◑◒'; \
	i=0; \
	while ps -p $$pid > /dev/null 2>&1; do \
		idx=$$((i % 4)); \
		char=$$(printf '%s' "$$sp" | awk -v i=$$((idx+1)) '{print substr($$0,i,1)}'); \
		printf "\r$$char $$title..." >&2; \
		i=$$((i + 1)); \
		sleep 0.15; \
	done; \
	\
	wait $$pid; \
	exit_code=$$?; \
	\
	if [ $$exit_code -eq 0 ]; then \
		printf "\r$(COLOR_SUCCESS)✓$(COLOR_RESET) $$title   \n" >&2; \
	else \
		printf "\r$(COLOR_ERROR)✗$(COLOR_RESET) $$title   \n" >&2; \
		cat "$$tmpfile" >&2; \
	fi; \
	\
	rm -f "$$tmpfile"; \
	exit $$exit_code
endef

# ===================================
# Функции валидации и проверок
# ===================================

# Проверка обязательной переменной
# Использование: $(call require-var,VAR_NAME)
define require-var
	if [ -z "$($(1))" ]; then \
		printf "$(COLOR_ERROR)✗ ERROR: Переменная $(1) не определена$(COLOR_RESET)\n" >&2; \
		exit 1; \
	fi
endef

# Проверка существования команды
# Использование: $(call check-command,command-name)
define check-command
	command -v $(1) >/dev/null 2>&1 || \
		(printf "$(COLOR_ERROR)✗ ERROR: Команда '$(1)' не найдена$(COLOR_RESET)\n" >&2; exit 1)
endef

# ===================================
# Интерактивные функции
# ===================================

# Запрос подтверждения через меню выбора
# Параметр: $(1) - вопрос
# Возвращает: true (0) если "Да", false (1) если "Нет" или ESC
# Использование: @$(call ask-yes-no,Продолжить?) || { log-info "Отменено"; exit 0; }
define ask-yes-no
	printf "$(COLOR_WARNING)? $(COLOR_RESET)%s\n" "$(1)" >&2; \
	CHOICE=$$(sh makefiles/scripts/select-menu.sh "Да" "Нет") || { \
		printf "$(COLOR_INFO)ℹ Отменено$(COLOR_RESET)\n" >&2; \
		false; \
	}; \
	if [ "$$CHOICE" = "Да" ]; then \
		true; \
	else \
		false; \
	fi
endef

# Запросить текстовый ввод от пользователя
# Параметр: $(1) - placeholder, $(2) - prompt text
# Возвращает: введенный текст
# Использование: NAME=$$($(call ask-input,my-module,Введите имя))
define ask-input
	printf "$(COLOR_INFO)➜ $(COLOR_RESET)%s $(COLOR_WARNING)[%s]$(COLOR_RESET): " "$(2)" "$(1)" >&2; \
	IFS= read -r input_value </dev/tty; \
	printf "%s" "$$input_value"
endef

# Запросить текстовый ввод с дефолтным значением
# Параметр: $(1) - default value, $(2) - prompt text
# Возвращает: введенный текст или default
# Использование: URL=$$($(call ask-input-with-default,https://github.com/user/repo,Введите URL))
define ask-input-with-default
	printf "$(COLOR_INFO)➜ $(COLOR_RESET)%s $(COLOR_SUCCESS)[default: %s]$(COLOR_RESET): " "$(2)" "$(1)" >&2; \
	read -r input_value </dev/tty; \
	if [ -z "$$input_value" ]; then \
		echo "$(1)"; \
	else \
		echo "$$input_value"; \
	fi
endef

# Выбор из списка опций (меню со стрелками)
# Параметр: $(1) - header text, $(2..N) - options (space-separated)
# Возвращает: выбранную опцию
# Использование: CHOICE=$$($(call ask-choose,Выберите стек,nodejs php python rust))
define ask-choose
	printf "$(COLOR_SECTION)▶ %s$(COLOR_RESET)\n" "$(1)"; \
	printf "$(COLOR_INFO)(используйте ↑↓ и Enter)$(COLOR_RESET)\n"; \
	shift; \
	sh makefiles/scripts/select-menu.sh "$$@"
endef

# Выбор одного элемента из переданного списка строк
# Параметр: $(1) - header text, $(2) - selected default, $(3) - options (newline or space separated)
# Возвращает: выбранную опцию
# Использование: VERSION=$$($(call ask-choose-single,Выберите версию,0.3.1,$$VERSION_OPTIONS))
define ask-choose-single
	printf "$(COLOR_SECTION)▶ %s$(COLOR_RESET)\n" "$(1)"; \
	printf "$(COLOR_INFO)(по умолчанию: $(2), используйте ↑↓ и Enter)$(COLOR_RESET)\n"; \
	options=$$(echo "$(3)" | tr ' ' '\n'); \
	sh makefiles/scripts/select-menu.sh $$options
endef

# Фильтрация списка с поиском
# Параметр: $(1) - header text, $(2) - items (newline-separated or space-separated)
# Возвращает: выбранный элемент
# Использование: VERSION=$$($(call ask-filter,Выберите версию,$(VERSIONS)))
# Примечание: упрощенная версия без поиска - использует ask-choose-single
define ask-filter
	$(call ask-choose-single,$(1),,$$(echo "$(2)" | tr ' ' '\n'))
endef

# Multiline текстовый ввод
# Параметр: $(1) - header text, $(2) - placeholder text
# Возвращает: введенный текст
# Использование: MESSAGE=$$($(call ask-write,Сообщение коммита,Опишите изменения...))
define ask-write
	printf "$(COLOR_SECTION)▶ %s$(COLOR_RESET)\n" "$(1)"; \
	printf "$(COLOR_INFO)[%s]$(COLOR_RESET)\n" "$(2)"; \
	printf "$(COLOR_WARNING)Введите текст (Ctrl+D для завершения):$(COLOR_RESET)\n"; \
	cat
endef
