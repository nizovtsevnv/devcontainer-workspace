# ===================================
# Система справки
# ===================================

.PHONY: help

## help: Показать эту справку
help:
	@printf "$(COLOR_SECTION)DevContainer Workspace$(COLOR_RESET)\n\n"

	@# Секция: Среда разработки
	@$(call log-info,Среда разработки:)
	@{ \
		grep -hE "^## (down|exec|sh|up|version):" $(MAKEFILE_LIST) | \
			sed 's/^## //' | \
			sort | \
			awk 'BEGIN {FS = ": "; first=1}; {if (first) first=0; else printf "<ROW>"; printf "make %s<COL>%s", $$1, $$2}'; \
		printf "<ROW>"; \
		$(call check-project-init-status); \
		if [ "$$STATUS" = "не инициализирован" ]; then \
			printf "make devenv init<COL>Инициализация проекта из шаблона<ROW>"; \
			printf "make devenv test<COL>Запустить автотесты (только для разработки)<ROW>"; \
		fi; \
		printf "make devenv update<COL>Обновить версию шаблона<ROW>"; \
		printf "make devenv status<COL>Текущая и актуальная версия шаблона<ROW>"; \
		printf "make module<COL>Создать новый модуль (Node.js, PHP, Python, Rust)"; \
	} | { $(call print-table,20); }
	@printf "\n"

	@# Секция: Модули проекта
	@$(call log-info,Модули проекта:)
	@if [ -n "$(MODULE_NAMES)" ]; then \
		modules_data=""; \
		for module in $(MODULE_NAMES); do \
			module_path="$(MODULES_DIR)/$$module"; \
			tech_info=$$($(call get-module-info,$$module_path)); \
			[ -n "$$modules_data" ] && modules_data="$$modules_data<ROW>"; \
			modules_data="$$modules_data""make $$module<COL>$$tech_info"; \
		done; \
		printf '%s\n' "$$modules_data" | { $(call print-table,20); }; \
		printf "\n  Используйте: $(COLOR_INFO)make <модуль>$(COLOR_RESET) для просмотра доступных команд\n"; \
		printf "  Пример: $(COLOR_SUCCESS)make hello install$(COLOR_RESET), $(COLOR_SUCCESS)make hello test$(COLOR_RESET), $(COLOR_SUCCESS)make hello build$(COLOR_RESET)\n"; \
	else \
		printf "  В каталоге modules/ ничего нет. Создайте первый модуль командой: $(COLOR_SUCCESS)make module$(COLOR_RESET)\n"; \
	fi
	@printf "\n"
