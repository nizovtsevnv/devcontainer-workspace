# ===================================
# Управление шаблоном DevContainer Workspace
# ===================================

.PHONY: devenv

# ===================================
# Вспомогательные функции
# ===================================

# Функция вывода справки по devenv командам
define devenv-help
	$(call check-project-init-status); \
	help_data=""; \
	if [ "$$STATUS" = "не инициализирован" ]; then \
		help_data="make devenv init<COL>Инициализация проекта из шаблона<ROW>"; \
		help_data="$$help_data""make devenv test<COL>Запустить автотесты (только для разработки)<ROW>"; \
	fi; \
	help_data="$$help_data""make devenv status<COL>Текущий статус и версия шаблона<ROW>"; \
	help_data="$$help_data""make devenv update<COL>Обновить версию шаблона"; \
	printf '%s\n' "$$help_data" | { $(call print-table,20); }
endef

# ===================================
# Диспетчер подкоманд devenv
# ===================================

# Получить подкоманду (первый аргумент после devenv)
DEVENV_CMD := $(word 2,$(MAKECMDGOALS))

## devenv: Команды управления шаблоном (init, test, status, update)
devenv:
	@if [ -z "$(DEVENV_CMD)" ]; then \
		$(call log-info,Команды управления шаблоном проекта:); \
		$(call devenv-help); \
	elif [ "$(DEVENV_CMD)" = "init" ]; then \
		$(MAKE) devenv-init-internal; \
	elif [ "$(DEVENV_CMD)" = "test" ]; then \
		$(MAKE) devenv-test-internal; \
	elif [ "$(DEVENV_CMD)" = "status" ]; then \
		$(MAKE) devenv-status-internal; \
	elif [ "$(DEVENV_CMD)" = "update" ]; then \
		$(MAKE) devenv-update-internal; \
	else \
		$(call log-error,Неизвестная подкоманда: $(DEVENV_CMD)); \
		$(call log-info,Доступны: init, test, status, update); \
		exit 1; \
	fi

# Stub targets для подавления ошибок Make при вызове `make devenv init/test/status/update`
.PHONY: init test status update
init test status update:
	@:

# ===================================
# Подключение модулей команд
# ===================================

include makefiles/devenv/init.mk
include makefiles/devenv/status.mk
include makefiles/devenv/update.mk
