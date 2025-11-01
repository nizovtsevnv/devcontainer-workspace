# ===================================
# Управление шаблоном DevContainer Workspace
# ===================================

.PHONY: devenv

# Получить подкоманду (первый аргумент после devenv)
DEVENV_CMD := $(word 2,$(MAKECMDGOALS))

## devenv: Команды управления шаблоном (init, test, status, update)
devenv:
	@if [ -z "$(DEVENV_CMD)" ]; then \
		printf "$(COLOR_INFO)ℹ$(COLOR_RESET) Команды управления шаблоном проекта:\n"; \
		printf "  $(COLOR_SUCCESS)%-24s$(COLOR_RESET) %s\n" "make devenv init" "Инициализация проекта из шаблона"; \
		printf "  $(COLOR_SUCCESS)%-24s$(COLOR_RESET) %s\n" "make devenv test" "Запустить автотесты (только для разработки)"; \
		printf "  $(COLOR_SUCCESS)%-24s$(COLOR_RESET) %s\n" "make devenv status" "Текущий статус и версия шаблона"; \
		printf "  $(COLOR_SUCCESS)%-24s$(COLOR_RESET) %s\n" "make devenv update" "Обновить версию шаблона"; \
	elif [ "$(DEVENV_CMD)" = "init" ]; then \
		$(call run-script,makefiles/scripts/devenv-init.sh) || exit $$?; \
	elif [ "$(DEVENV_CMD)" = "test" ]; then \
		$(call run-script,makefiles/scripts/devenv-test.sh) || exit $$?; \
	elif [ "$(DEVENV_CMD)" = "status" ]; then \
		$(call run-script,makefiles/scripts/devenv-status.sh) || exit $$?; \
	elif [ "$(DEVENV_CMD)" = "update" ]; then \
		$(call run-script,makefiles/scripts/devenv-update.sh) || exit $$?; \
	else \
		printf "$(COLOR_ERROR)✗$(COLOR_RESET) Неизвестная подкоманда: $(DEVENV_CMD)\n" >&2; \
		printf "$(COLOR_INFO)ℹ$(COLOR_RESET) Доступны: init, test, status, update\n"; \
		exit 1; \
	fi

# Stub targets для подавления ошибок Make при вызове `make devenv init/test/status/update`
.PHONY: init test status update
init test status update:
	@:

