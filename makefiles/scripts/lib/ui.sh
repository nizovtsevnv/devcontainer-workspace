#!/bin/sh
# ===================================
# UI библиотека для DevContainer Workspace
# ===================================
# Объединяет все UI функции: логирование, спиннер, интерактив
# Использование: . lib/ui.sh

# ===================================
# Цвета (импортируются из окружения)
# ===================================
COLOR_SUCCESS="${COLOR_SUCCESS:-\033[0;32m}"
COLOR_ERROR="${COLOR_ERROR:-\033[0;31m}"
COLOR_INFO="${COLOR_INFO:-\033[0;36m}"
COLOR_WARNING="${COLOR_WARNING:-\033[0;33m}"
COLOR_SECTION="${COLOR_SECTION:-\033[1;35m}"
COLOR_DIM="${COLOR_DIM:-\033[2m}"
COLOR_RESET="${COLOR_RESET:-\033[0m}"

# ===================================
# Функции логирования
# ===================================

log_info() {
	printf "${COLOR_INFO}ℹ${COLOR_RESET} %s\n" "$1"
}

log_success() {
	printf "${COLOR_SUCCESS}✓${COLOR_RESET} %s\n" "$1"
}

log_warning() {
	printf "${COLOR_WARNING}⚠${COLOR_RESET} %s\n" "$1"
}

log_error() {
	printf "${COLOR_ERROR}✗${COLOR_RESET} %s\n" "$1" >&2
}

log_section() {
	printf "${COLOR_SECTION}▶ %s${COLOR_RESET}\n" "$1"
}

# ===================================
# Вывод таблиц
# ===================================

# Вывод таблицы с фиксированной шириной первой колонки
# Параметр: $1 - ширина первой колонки
# Использование: printf '%s\n' "key1<COL>value1<ROW>key2<COL>value2" | print_table 16
# Разделитель строк - <ROW>, разделитель колонок - <COL>
print_table() {
	col_width=$1
	while IFS= read -r line; do
		# Разбиваем строки по <ROW>
		echo "$line"
	done | sed 's/<ROW>/\n/g' | while read -r row_data; do
		# Пропускаем пустые строки
		[ -z "$row_data" ] && continue

		# Разбиваем колонки по <COL> используя POSIX-совместимый подход
		key=$(echo "$row_data" | sed 's/<COL>.*//')
		value=$(echo "$row_data" | sed 's/^[^<]*<COL>//')

		# Убираем оставшиеся маркеры из value
		value=$(echo "$value" | sed 's/<ROW>//g')

		key_len=$(echo -n "$key" | wc -m)
		padding=$((col_width - key_len))
		[ $padding -lt 0 ] && padding=0

		printf "  ${COLOR_SUCCESS}%s%*s${COLOR_RESET} %s\n" "$key" $padding "" "$value"
	done
}

# ===================================
# Спиннер
# ===================================

# Показать спиннер во время выполнения команды
# Параметры: $1 - сообщение, остальные - команда с аргументами
# Возвращает: exit code команды
# Использование: show_spinner "Загрузка" git clone https://example.com/repo
show_spinner() {
	title="$1"
	shift

	tmpfile=$(mktemp)
	trap "rm -f $tmpfile" EXIT INT TERM

	"$@" > "$tmpfile" 2>&1 &
	pid=$!

	sp='◐◓◑◒'
	i=0
	while ps -p $pid > /dev/null 2>&1; do
		idx=$((i % 4))
		char=$(printf '%s' "$sp" | awk -v i=$((idx+1)) '{print substr($0,i,1)}')
		printf "\r$char $title..." >&2
		i=$((i + 1))
		sleep 0.15
	done

	wait $pid
	exit_code=$?

	if [ $exit_code -eq 0 ]; then
		printf "\r${COLOR_SUCCESS}✓${COLOR_RESET} $title   \n" >&2
	else
		printf "\r${COLOR_ERROR}✗${COLOR_RESET} $title   \n" >&2
		cat "$tmpfile" >&2
	fi

	rm -f "$tmpfile"
	return $exit_code
}

# ===================================
# Интерактивное меню
# ===================================

# Интерактивное меню со стрелками
# Использование: choice=$(select_menu "option1" "option2" "option3")
# Возвращает: выбранную опцию через stdout, exit code 0 при успехе, 1 при отмене (ESC)
select_menu() {
	# Вспомогательные функции для работы с терминалом
	_cursor_blink_off() { printf "\033[?25l" >/dev/tty; }
	_cursor_blink_on() { printf "\033[?25h" >/dev/tty; }
	_cursor_up() { printf "\033[%dA\r" "$1" >/dev/tty; }
	_print_option() { printf "  %s\033[K\r\n" "$1" >/dev/tty; }
	_print_selected() { printf "${COLOR_SUCCESS}▶${COLOR_RESET} %s\033[K\r\n" "$1" >/dev/tty; }

	# Сохраняем текущее состояние stdin/stderr
	exec 3<&0 4>&2

	# Открываем /dev/tty для ввода и вывода
	exec < /dev/tty
	exec 2> /dev/tty

	# Опции из параметров
	num_options=$#
	selected=0

	# Сохраняем старые настройки терминала
	old_stty=$(stty -g </dev/tty)
	trap "stty $old_stty </dev/tty; _cursor_blink_on; exec 0<&3 2>&4; exec 3<&- 4>&-" INT TERM EXIT

	# Настройки терминала для сырого ввода
	_cursor_blink_off
	stty raw -echo min 1 time 0 </dev/tty

	# Рисуем начальное меню
	idx=0
	for opt in "$@"; do
		if [ $idx -eq $selected ]; then
			_print_selected "$opt"
		else
			_print_option "$opt"
		fi
		idx=$((idx + 1))
	done

	# Выводим подсказку серым цветом
	printf "\033[90m  используйте ↑↓ и Enter, ESC для отмены\033[0m" >/dev/tty

	# Главный цикл
	while true; do
		# Читаем один байт из /dev/tty
		key=$(dd bs=1 count=1 </dev/tty 2>/dev/null)

		# Проверяем на ESC последовательность
		if [ "$key" = "$(printf '\033')" ]; then
			# Читаем следующий байт без блокировки (с минимальным timeout)
			old_stty_temp=$(stty -g </dev/tty)
			stty raw -echo min 0 time 1 </dev/tty
			key2=$(dd bs=1 count=1 </dev/tty 2>/dev/null || true)
			stty "$old_stty_temp" </dev/tty

			if [ -z "$key2" ]; then
				# Просто ESC нажат без последующих символов - выход с кодом 1 (отмена)
				printf "\r\033[K" >/dev/tty
				stty "$old_stty" </dev/tty
				_cursor_blink_on
				exec 0<&3 2>&4
				exec 3<&- 4>&-
				return 1
			elif [ "$key2" = "[" ]; then
				# Читаем код стрелки
				key=$(dd bs=1 count=1 </dev/tty 2>/dev/null)
				case "$key" in
					"A")  # Стрелка вверх
						selected=$((selected - 1))
						[ $selected -lt 0 ] && selected=$((num_options - 1))

						# Очищаем текущую строку (подсказка) и возвращаемся к началу меню
						printf "\r\033[K" >/dev/tty
						_cursor_up $num_options
						idx=0
						for opt in "$@"; do
							if [ $idx -eq $selected ]; then
								_print_selected "$opt"
							else
								_print_option "$opt"
							fi
							idx=$((idx + 1))
						done
						printf "\033[90m  используйте ↑↓ и Enter, ESC для отмены\033[0m" >/dev/tty
						;;
					"B")  # Стрелка вниз
						selected=$((selected + 1))
						[ $selected -ge $num_options ] && selected=0

						# Очищаем текущую строку (подсказка) и возвращаемся к началу меню
						printf "\r\033[K" >/dev/tty
						_cursor_up $num_options
						idx=0
						for opt in "$@"; do
							if [ $idx -eq $selected ]; then
								_print_selected "$opt"
							else
								_print_option "$opt"
							fi
							idx=$((idx + 1))
						done
						printf "\033[90m  используйте ↑↓ и Enter, ESC для отмены\033[0m" >/dev/tty
						;;
				esac
			fi
		elif [ "$key" = "$(printf '\n')" ] || [ "$key" = "$(printf '\r')" ]; then
			# Enter нажат - очищаем подсказку и выходим
			printf "\r\033[K" >/dev/tty
			break
		elif [ "$key" = "$(printf '\003')" ]; then
			# Ctrl+C нажат - очищаем подсказку и выход с кодом 130
			printf "\r\033[K" >/dev/tty
			stty "$old_stty" </dev/tty
			_cursor_blink_on
			exec 0<&3 2>&4
			exec 3<&- 4>&-
			exit 130
		fi
	done

	# Восстанавливаем терминал
	stty "$old_stty" </dev/tty
	_cursor_blink_on

	# Восстанавливаем stdin/stderr
	exec 0<&3 2>&4
	exec 3<&- 4>&-

	# Возвращаем выбранную опцию в stdout
	eval "selected_option=\${$((selected + 1))}"
	echo "$selected_option"
	return 0
}

# ===================================
# Интерактивные функции
# ===================================

# Запрос подтверждения через меню выбора
# Параметр: $1 - вопрос
# Возвращает: 0 если "Да", 1 если "Нет" или ESC
# Использование: if ask_yes_no "Продолжить?"; then ...
ask_yes_no() {
	printf "${COLOR_WARNING}? ${COLOR_RESET}%s\n" "$1" >&2
	choice=$(select_menu "Да" "Нет") || {
		log_info "Отменено"
		return 1
	}
	[ "$choice" = "Да" ]
}

# Запросить текстовый ввод от пользователя
# Параметры: $1 - placeholder, $2 - prompt text
# Возвращает: введенный текст
# Использование: name=$(ask_input "my-module" "Введите имя")
ask_input() {
	printf "${COLOR_INFO}➜ ${COLOR_RESET}%s ${COLOR_WARNING}[%s]${COLOR_RESET}: " "$2" "$1" >&2
	read -r input_value </dev/tty
	printf "%s" "$input_value"
}

# Запросить текстовый ввод с дефолтным значением
# Параметры: $1 - default value, $2 - prompt text
# Возвращает: введенный текст или default
# Использование: url=$(ask_input_with_default "https://github.com/user/repo" "Введите URL")
ask_input_with_default() {
	printf "${COLOR_INFO}➜ ${COLOR_RESET}%s ${COLOR_DIM}[%s]${COLOR_RESET}: " "$2" "$1" >&2
	read -r input_value </dev/tty
	if [ -z "$input_value" ]; then
		echo "$1"
	else
		echo "$input_value"
	fi
}
