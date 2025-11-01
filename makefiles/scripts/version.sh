#!/bin/sh
# ===================================
# DevContainer Workspace - Вывод версий
# ===================================

# Определяем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Загружаем библиотеки
. "$SCRIPT_DIR/lib/ui.sh"
. "$SCRIPT_DIR/lib/git.sh"
. "$SCRIPT_DIR/lib/modules.sh"

# ===================================
# Версии инструментов в контейнере
# ===================================

log_info "Версии шаблона и образа:"

# Полная версия из .template-version или git
template_full=$(get_template_version)

# Базовая версия для Docker образа (редуцированная)
template_base=$(echo "$template_full" | sed 's/-[0-9]*-g.*//')

# Если версии разные, показываем обе
if [ "$template_full" != "$template_base" ]; then
	printf "  ${COLOR_SUCCESS}%-20s${COLOR_RESET} %s ${COLOR_DIM}(код из %s)${COLOR_RESET}\n" "Шаблон" "$template_base" "$template_full"
else
	printf "  ${COLOR_SUCCESS}%-20s${COLOR_RESET} %s\n" "Шаблон" "$template_full"
fi

printf "  ${COLOR_SUCCESS}%-20s${COLOR_RESET} %s\n" "Docker образ" "$CONTAINER_IMAGE"

printf "\n"
log_info "Версии инструментов в контейнере:"

docker_ver=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,$//' || echo "не установлен")
git_ver=$(git --version 2>/dev/null | awk '{print $3}' || echo "не установлен")
node_ver=$(node --version 2>/dev/null | sed 's/^v//' || echo "не установлен")
php_ver=$(php --version 2>/dev/null | head -n1 | awk '{print $2}' || echo "не установлен")
rust_ver=$(rustc --version 2>/dev/null | awk '{print $2}' || echo "не установлен")

printf "  ${COLOR_SUCCESS}%-20s${COLOR_RESET} %s\n" "Docker" "$docker_ver"
printf "  ${COLOR_SUCCESS}%-20s${COLOR_RESET} %s\n" "Git" "$git_ver"
printf "  ${COLOR_SUCCESS}%-20s${COLOR_RESET} %s\n" "Node.js" "$node_ver"
printf "  ${COLOR_SUCCESS}%-20s${COLOR_RESET} %s\n" "PHP" "$php_ver"
printf "  ${COLOR_SUCCESS}%-20s${COLOR_RESET} %s\n" "Rust" "$rust_ver"

# ===================================
# Модули проекта
# ===================================

MODULES_DIR="${MODULES_DIR:-modules}"

if [ -d "$MODULES_DIR" ] && [ "$(ls -A "$MODULES_DIR" 2>/dev/null)" ]; then
	printf "\n"
	log_info "Модули проекта:"

	for module_path in "$MODULES_DIR"/*; do
		[ -d "$module_path" ] || continue
		module=$(basename "$module_path")
		versions=$(get_module_versions_compact "$module_path")

		printf "  ${COLOR_SUCCESS}%-20s${COLOR_RESET} %s\n" "$module" "$versions"
	done | sort
fi
