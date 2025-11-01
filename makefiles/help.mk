# ===================================
# Система справки
# ===================================

.PHONY: help

## help: Показать эту справку
help:
	@printf "$(COLOR_SECTION)DevContainer Workspace$(COLOR_RESET)\n\n"

	@# Секция: Среда разработки
	@printf "$(COLOR_INFO)ℹ$(COLOR_RESET) Среда разработки:\n"
	@{ \
		grep -hE "^## (down|exec|sh|up|version):" $(MAKEFILE_LIST) | \
			sed 's/^## //' | \
			sort | \
			awk 'BEGIN {FS = ": "}; {printf "  $(COLOR_SUCCESS)%-24s$(COLOR_RESET) %s\n", "make " $$1, $$2}'; \
		if [ ! -f "$(WORKSPACE_ROOT)/.template-version" ]; then \
			printf "  $(COLOR_SUCCESS)%-24s$(COLOR_RESET) %s\n" "make devenv init" "Инициализация проекта из шаблона"; \
		fi; \
		printf "  $(COLOR_SUCCESS)%-24s$(COLOR_RESET) %s\n" "make devenv test" "Запустить автотесты шаблона"; \
		printf "  $(COLOR_SUCCESS)%-24s$(COLOR_RESET) %s\n" "make devenv update" "Обновить версию шаблона"; \
		printf "  $(COLOR_SUCCESS)%-24s$(COLOR_RESET) %s\n" "make devenv status" "Текущая и актуальная версия шаблона"; \
		printf "  $(COLOR_SUCCESS)%-24s$(COLOR_RESET) %s\n" "make module" "Создать новый модуль (Node.js, PHP, Python, Rust)"; \
	}
	@printf "\n"

	@# Секция: Модули проекта
	@printf "$(COLOR_INFO)ℹ$(COLOR_RESET) Модули проекта:\n"
	@if [ -n "$(MODULE_NAMES)" ]; then \
		for module in $(MODULE_NAMES); do \
			module_path="$(MODULES_DIR)/$$module"; \
			tech_info=$$(sh makefiles/scripts/lib/modules.sh get-info "$$module_path"); \
			printf "  $(COLOR_SUCCESS)%-24s$(COLOR_RESET) %s\n" "make $$module" "$$tech_info"; \
		done; \
		printf "\n  Используйте: $(COLOR_INFO)make <модуль>$(COLOR_RESET) для просмотра доступных команд\n"; \
		printf "  Пример: $(COLOR_SUCCESS)make hello install$(COLOR_RESET), $(COLOR_SUCCESS)make hello test$(COLOR_RESET), $(COLOR_SUCCESS)make hello build$(COLOR_RESET)\n"; \
	else \
		printf "  В каталоге modules/ ничего нет. Создайте первый модуль командой: $(COLOR_SUCCESS)make module$(COLOR_RESET)\n"; \
	fi
	@printf "\n"
