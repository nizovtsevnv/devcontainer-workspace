# ===================================
# Система справки
# ===================================

.PHONY: help

## help: Показать эту справку
help:
	@printf "$(COLOR_SECTION)DevContainer Workspace$(COLOR_RESET)\n\n"
	@printf "$(COLOR_INFO)Управление средой:$(COLOR_RESET)\n"
	@$(call print-commands-table,"^## (init|up|down|sh|exec|version):")
	@printf "\n$(COLOR_INFO)Модули проекта:$(COLOR_RESET)\n"
	@if [ -n "$(MODULE_NAMES)" ]; then \
		for module in $(MODULE_NAMES); do \
			module_path="$(MODULES_DIR)/$$module"; \
			tech=""; \
			[ -f "$$module_path/package.json" ] && tech="$$tech nodejs"; \
			[ -f "$$module_path/composer.json" ] && tech="$$tech php"; \
			[ -f "$$module_path/pyproject.toml" ] || [ -f "$$module_path/requirements.txt" ] || [ -f "$$module_path/setup.py" ] && tech="$$tech python"; \
			[ -f "$$module_path/Cargo.toml" ] && tech="$$tech rust"; \
			[ -f "$$module_path/Makefile" ] && tech="$$tech makefile"; \
			[ -f "$$module_path/.gitlab-ci.yml" ] && tech="$$tech gitlab"; \
			[ -d "$$module_path/.github/workflows" ] && tech="$$tech github"; \
			tech=$$(echo "$$tech" | xargs); \
			printf "  $(COLOR_SUCCESS)• $$module$(COLOR_RESET)"; \
			if [ -n "$$tech" ]; then \
				printf " ["; \
				first=1; \
				for t in $$tech; do \
					if [ $$first -eq 0 ]; then printf ", "; fi; \
					case $$t in \
						nodejs) printf "Node.js";; \
						php) printf "PHP";; \
						python) printf "Python";; \
						rust) printf "Rust";; \
						makefile) printf "Make";; \
						gitlab) printf "GitLab";; \
						github) printf "GitHub";; \
						*) printf "$$t";; \
					esac; \
					first=0; \
				done; \
				printf "]"; \
			fi; \
			printf "\n"; \
		done; \
		printf "\n  Команды модуля:\n"; \
		printf "    $(COLOR_SUCCESS)make <модуль>$(COLOR_RESET)                    Справка по модулю\n"; \
		printf "    $(COLOR_SUCCESS)make <модуль> <менеджер> <cmd>$(COLOR_RESET)  Команда пакетного менеджера\n"; \
		printf "    $(COLOR_SUCCESS)make <модуль> <makefile-cmd>$(COLOR_RESET)    Makefile команда (если есть)\n"; \
		printf "\n  Примеры:\n"; \
		printf "    $(COLOR_SUCCESS)make myapp bun install$(COLOR_RESET)    - установить зависимости через bun\n"; \
		printf "    $(COLOR_SUCCESS)make myapi composer test$(COLOR_RESET)  - запустить тесты через composer\n"; \
		printf "    $(COLOR_SUCCESS)make ml uv run main.py$(COLOR_RESET)    - запустить Python через uv\n"; \
	else \
		printf "  В каталоге modules/ ничего нет\n"; \
	fi
	@printf "\n"
