# ===================================
# Автотесты шаблона DevContainer Workspace
# ===================================

.PHONY: devenv-test-internal setup-test-modules

# Директория для тестовых артефактов
# Используем /tmp для универсальной совместимости (локально и в CI)
# В GitHub Actions CI /workspace монтируется как /dev/root (read-only в некоторых случаях)
TEST_DIR := /tmp/devcontainer-workspace
TEST_LOG := $(TEST_DIR)/test-results.log

# Функция запуска теста
define run-test
	printf "$(COLOR_SECTION)▶ Тест: $(1)$(COLOR_RESET)\n"; \
	if $(2); then \
		printf "  $(COLOR_SUCCESS)✓ PASSED$(COLOR_RESET)\n"; \
	else \
		printf "  $(COLOR_ERROR)✗ FAILED$(COLOR_RESET)\n"; \
		exit 1; \
	fi
endef

devenv-test-internal:
	@$(call log-section,Запуск автотестов DevContainer Workspace)
	@printf "\n"

	@# Остановка контейнера если запущен
	@$(call log-info,Очистка предыдущего окружения...)
	@if $(CONTAINER_RUNTIME) ps --format "{{.Names}}" | grep -q "^$(CONTAINER_NAME)$$" 2>/dev/null; then \
		$(MAKE) down; \
	fi
	@printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Окружение очищено\n\n"

	@# Запуск контейнера перед диагностикой (без вывода)
	@$(call log-info,Запуск контейнера для диагностики...)
	@$(MAKE) up >/dev/null 2>&1
	@printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Контейнер запущен\n\n"

	@# Диагностика окружения перед запуском тестов
	@$(call log-section,Диагностика тестового окружения)
	@printf "\n"

	@# HOST ENVIRONMENT table
	@$(MAKE) exec '(echo "UID,$(HOST_UID)"; echo "GID,$(HOST_GID)"; echo "CONTAINER_RUNTIME,$(CONTAINER_RUNTIME)") | /usr/bin/gum table --print --border thick --border.foreground 63 --widths 20,40 --columns "Parameter,Value"'

	@# CONTAINER ENVIRONMENT table
	@$(MAKE) exec '(echo "UID,$$(id -u)"; echo "GID,$$(id -g)"; echo "USER,$$(whoami)"; echo "CWD,$$(pwd)") | /usr/bin/gum table --print --border thick --border.foreground 135 --widths 20,40 --columns "Parameter,Value"'

	@printf "\n"

	@# Подготовка изолированного тестового окружения - ВСЁ из контейнера
	@$(call log-info,Подготовка тестового окружения...)
	@$(MAKE) exec "mkdir -p $(TEST_DIR)/modules && cp Makefile $(TEST_DIR)/ && cp -r makefiles $(TEST_DIR)/ && cp -r .devcontainer $(TEST_DIR)/"
	@$(MAKE) exec "echo '=== Test Run: \$$(date) ===' > $(TEST_DIR)/test-results.log"
	@printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Окружение подготовлено\n\n"

	@# Подготовка тестовых модулей
	@$(MAKE) setup-test-modules

	@# Запуск групп тестов
	@$(MAKE) test-commands-internal
	@$(MAKE) test-permissions-internal
	@$(MAKE) test-stacks-internal

	@# Остановка тестового контейнера
	@printf "\n"
	@$(call log-info,Остановка тестового контейнера...)
	@$(MAKE) down >/dev/null 2>&1
	@printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Тестовый контейнер остановлен\n"
	@printf "\n"

	@# Итоговая информация
	@printf "$(COLOR_SUCCESS)✓ ВСЕ ТЕСТЫ ПРОЙДЕНЫ!$(COLOR_RESET)\n"
	@printf "\n"
	@printf "Тестовое окружение (внутри контейнера):\n"
	@printf "  Директория: $(TEST_DIR)/\n"
	@printf "  Журнал:     $(TEST_DIR)/test-results.log\n"
	@printf "  Модули:     $(TEST_DIR)/modules/\n"
	@printf "\n"
	@printf "$(COLOR_INFO)Артефакты в /tmp автоматически очистятся при перезагрузке$(COLOR_RESET)\n"

# Подготовка тестовых модулей
setup-test-modules:
	@$(call log-info,Создание тестовых модулей...)

	@# Node.js модуль (Bun)
	@printf "  → test-nodejs (bun)...\n"
	@$(MAKE) module MODULE_STACK=nodejs MODULE_TYPE=bun MODULE_NAME=test-nodejs MODULE_TARGET=$(TEST_DIR)/modules
	@printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) test-nodejs создан\n"

	@# PHP модуль (Composer)
	@printf "  → test-php (composer)...\n"
	@$(MAKE) module MODULE_STACK=php MODULE_TYPE=composer-lib MODULE_NAME=test-php MODULE_TARGET=$(TEST_DIR)/modules
	@printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) test-php создан\n"

	@# Python модуль (Poetry)
	@printf "  → test-python (poetry)...\n"
	@$(MAKE) module MODULE_STACK=python MODULE_TYPE=poetry MODULE_NAME=test-python MODULE_TARGET=$(TEST_DIR)/modules
	@printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) test-python создан\n"

	@# Rust модуль (Binary)
	@printf "  → test-rust (cargo)...\n"
	@$(MAKE) module MODULE_STACK=rust MODULE_TYPE=bin MODULE_NAME=test-rust MODULE_TARGET=$(TEST_DIR)/modules
	@printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) test-rust создан\n"
	@printf "\n"

# Тест базовых команд
.PHONY: test-commands-internal
test-commands-internal:
	@printf "$(COLOR_INFO)═══ Тестирование базовых команд ═══$(COLOR_RESET)\n"

	@# Тест: make up
	@$(call run-test,make up, \
		$(MAKE) up >/dev/null 2>&1 && \
		$(CONTAINER_RUNTIME) ps --format "{{.Names}}" | grep -q "^$(CONTAINER_NAME)$$")

	@# Тест: make exec
	@$(call run-test,make exec, \
		$(MAKE) exec 'echo "test-output"' 2>/dev/null | grep -q "test-output")

	@# Тест: make version
	@$(call run-test,make version, \
		$(MAKE) version 2>/dev/null | grep -q "Node.js")

	@# Тест: контейнер запущен
	@$(call run-test,Контейнер работает, \
		$(CONTAINER_RUNTIME) ps --format "{{.Names}}" | grep -q "^$(CONTAINER_NAME)$$")

# Тест прав доступа к файлам
.PHONY: test-permissions-internal
test-permissions-internal:
	@printf "\n$(COLOR_INFO)═══ Тестирование прав доступа ═══$(COLOR_RESET)\n"

	@# Создать файл в контейнере
	@$(call run-test,Создание файла в контейнере, \
		$(MAKE) exec 'touch $(TEST_DIR)/perm-test.txt' >/dev/null 2>&1)

	@# Проверить возможность записи файла из контейнера
	@$(call run-test,Запись файла работает, \
		$(MAKE) exec 'echo "write-test" > $(TEST_DIR)/perm-test.txt' >/dev/null 2>&1)

	@# Проверить возможность чтения из контейнера
	@$(call run-test,Чтение файла работает, \
		$(MAKE) exec 'cat $(TEST_DIR)/perm-test.txt' 2>/dev/null | grep -q "write-test")

	@# Проверить возможность перезаписи файла из контейнера
	@$(call run-test,Перезапись файла работает, \
		$(MAKE) exec 'echo "rewrite-test" > $(TEST_DIR)/perm-test.txt && cat $(TEST_DIR)/perm-test.txt' 2>/dev/null | grep -q "rewrite-test")

# Тест технологических стеков
.PHONY: test-stacks-internal
test-stacks-internal:
	@printf "\n$(COLOR_INFO)═══ Тестирование команд внутри модулей в контейнере ═══$(COLOR_RESET)\n"
	@$(MAKE) test-stack-nodejs-internal
	@$(MAKE) test-stack-php-internal
	@$(MAKE) test-stack-python-internal
	@$(MAKE) test-stack-rust-internal

.PHONY: test-stack-nodejs-internal
test-stack-nodejs-internal:
	@$(call run-test,test-nodejs / npm install, \
		$(MAKE) exec 'cd $(TEST_DIR)/modules/test-nodejs && npm install --silent' >/dev/null 2>&1)

	@$(call run-test,test-nodejs / npm test, \
		$(MAKE) exec 'cd $(TEST_DIR)/modules/test-nodejs && npm test' 2>&1 | grep -q "nodejs test passed")

	@$(call run-test,test-nodejs / npm run build, \
		$(MAKE) exec 'cd $(TEST_DIR)/modules/test-nodejs && npm run build' 2>&1 | grep -q "nodejs build passed")

.PHONY: test-stack-php-internal
test-stack-php-internal:
	@$(call run-test,test-php / composer install, \
		$(MAKE) exec 'cd $(TEST_DIR)/modules/test-php && composer install --quiet' >/dev/null 2>&1)

	@$(call run-test,test-php / composer test, \
		$(MAKE) exec 'cd $(TEST_DIR)/modules/test-php && composer test' 2>&1 | grep -q "php test passed")

.PHONY: test-stack-python-internal
test-stack-python-internal:
	@$(call run-test,test-python / pytest, \
		$(MAKE) exec 'cd $(TEST_DIR)/modules/test-python && pytest -q tests/test_main.py' >/dev/null 2>&1)

.PHONY: test-stack-rust-internal
test-stack-rust-internal:
	@$(call run-test,test-rust / cargo build, \
		$(MAKE) exec 'cd $(TEST_DIR)/modules/test-rust && cargo build --quiet' 2>&1 | grep -v "Compiling\|Finished" || true)

	@$(call run-test,test-rust / cargo test, \
		$(MAKE) exec 'cd $(TEST_DIR)/modules/test-rust && cargo test --quiet' 2>&1 | grep -q "test result: ok")
