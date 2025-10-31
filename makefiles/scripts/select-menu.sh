#!/bin/sh
# Интерактивное меню со стрелками
# Использование: select-menu.sh "option1" "option2" "option3"
# Возвращает: выбранную опцию

# Открываем /dev/tty для ввода и вывода
exec < /dev/tty
exec 2> /dev/tty

cursor_blink_off() { printf "\033[?25l" >/dev/tty; }
cursor_blink_on() { printf "\033[?25h" >/dev/tty; }
cursor_up() { printf "\033[%dA\r" "$1" >/dev/tty; }

print_option() { printf "  %s\033[K\r\n" "$1" >/dev/tty; }
print_selected() { printf "\033[0;32m▶\033[0m %s\033[K\r\n" "$1" >/dev/tty; }

# Опции из параметров
num_options=$#
selected=0

# Сохраняем старые настройки терминала
old_stty=$(stty -g </dev/tty)
trap "stty $old_stty </dev/tty; cursor_blink_on; exit" INT TERM EXIT

# Настройки терминала для сырого ввода
cursor_blink_off
stty raw -echo min 1 time 0 </dev/tty

# Рисуем начальное меню
idx=0
for opt in "$@"; do
    if [ $idx -eq $selected ]; then
        print_selected "$opt"
    else
        print_option "$opt"
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
            # Очищаем подсказку
            printf "\r\033[K" >/dev/tty
            stty "$old_stty" </dev/tty
            cursor_blink_on
            exit 1
        elif [ "$key2" = "[" ]; then
            # Читаем код стрелки
            key=$(dd bs=1 count=1 </dev/tty 2>/dev/null)
            case "$key" in
                "A")  # Стрелка вверх
                    selected=$((selected - 1))
                    [ $selected -lt 0 ] && selected=$((num_options - 1))

                    # Очищаем текущую строку (подсказка) и возвращаемся к началу меню
                    printf "\r\033[K" >/dev/tty
                    cursor_up $num_options
                    idx=0
                    for opt in "$@"; do
                        if [ $idx -eq $selected ]; then
                            print_selected "$opt"
                        else
                            print_option "$opt"
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
                    cursor_up $num_options
                    idx=0
                    for opt in "$@"; do
                        if [ $idx -eq $selected ]; then
                            print_selected "$opt"
                        else
                            print_option "$opt"
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
        cursor_blink_on
        exit 130
    fi
done

# Восстанавливаем терминал
stty "$old_stty" </dev/tty
cursor_blink_on

# Возвращаем выбранную опцию в stdout
eval "selected_option=\${$((selected + 1))}"
echo "$selected_option"
