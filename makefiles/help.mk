# ===================================
# Система справки
# ===================================

.PHONY: help

## help: Показать эту справку
help:
	@printf "$(COLOR_SECTION)DevContainer Workspace$(COLOR_RESET)\n\n"

	@# Секция: Среда разработки
	@printf "$(COLOR_INFO)Среда разработки:$(COLOR_RESET)\n"
	@$(call print-commands-table,"^## (up|down|sh|exec|version):")
	@# Добавить devenv команды вручную с правильным описанием
	@printf "  $(COLOR_SUCCESS)make devenv init      $(COLOR_RESET)Удаление артефактов шаблона (выполняется автоматически)\n"
	@printf "  $(COLOR_SUCCESS)make devenv version   $(COLOR_RESET)Текущая и актуальная версия шаблона\n"
	@printf "  $(COLOR_SUCCESS)make devenv update    $(COLOR_RESET)Обновить из upstream шаблона\n"

	@# Секция: Модули проекта
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
			\
			printf "  $(COLOR_SUCCESS)make %-17s$(COLOR_RESET)" "$$module"; \
			if [ -n "$$tech" ]; then \
				printf "["; \
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
	else \
		printf "  В каталоге modules/ ничего нет\n"; \
	fi
	@printf "\n"
