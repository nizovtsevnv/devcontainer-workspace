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
	$(call log-info,Тест: $(1):); \
	if $(2); then \
  	    $(call log-success,Тест успешно пройден); \
	else \
		$(call log-error,ОШИБКА! Тест провален); \
		exit 1; \
	fi
endef

devenv-test-internal:
	@$(call log-section,Подготовка тестового окружения)

	@# Остановка контейнера если запущен
	@$(MAKE) down
	@$(call log-success,Окружение очищено)
	@printf "\n"

	@# Запуск контейнера перед диагностикой (без вывода)
	@$(call log-spinner,Запуск контейнера для диагностики,$(MAKE) up >/dev/null 2>&1)
	@$(call log-success,Контейнер запущен)
	@printf "\n"

	@# CONTAINER ENVIRONMENT
	@$(call log-info,Контейнерная среда:)
	@$(CONTAINER_RUNTIME) exec -w $(CONTAINER_WORKDIR) $(CONTAINER_NAME) bash -c 'U=$$(id -u); G=$$(id -g); USR=$$(whoami); D=$$(pwd); printf "UID|%s;GID|%s;USER|%s;CWD|%s\n" "$$U" "$$G" "$$USR" "$$D"' | sed 's/|/<COL>/g; s/;/<ROW>/g' | { $(call print-table,18); }
	@printf "\n"

	@# HOST ENVIRONMENT
	@$(call log-info,Хост среда:)
	@printf "UID<COL>$(HOST_UID)<ROW>GID<COL>$(HOST_GID)<ROW>CONTAINER_RUNTIME<COL>$(CONTAINER_RUNTIME)\n" | { $(call print-table,18); }
	@printf "\n"

	@# Подготовка изолированного тестового окружения - ВСЁ из контейнера
	@printf "⠙ Подготовка изолированной копии шаблона для тестирования...\n"
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		rm -rf $(TEST_DIR) && mkdir -p $(TEST_DIR)/modules && cp Makefile $(TEST_DIR)/ && cp -r makefiles $(TEST_DIR)/ && cp -r .devcontainer $(TEST_DIR)/ >/dev/null 2>&1; \
		echo "=== Test Run: $$(date) ===" > $(TEST_DIR)/test-results.log; \
	else \
		$(CONTAINER_RUNTIME) exec -w $(CONTAINER_WORKDIR) $(CONTAINER_NAME) bash -c "rm -rf $(TEST_DIR) && mkdir -p $(TEST_DIR)/modules && cp Makefile $(TEST_DIR)/ && cp -r makefiles $(TEST_DIR)/ && cp -r .devcontainer $(TEST_DIR)/" >/dev/null 2>&1; \
		$(CONTAINER_RUNTIME) exec -w $(CONTAINER_WORKDIR) $(CONTAINER_NAME) bash -c "echo '=== Test Run: \$$(date) ===' > $(TEST_DIR)/test-results.log"; \
	fi
	@$(call log-success,Копия шаблона подготовлена)
	@printf "\n"

	@# Подготовка тестовых модулей
	@$(MAKE) setup-test-modules

	@# Запуск групп тестов
	@$(MAKE) test-commands-internal
	@$(MAKE) test-permissions-internal
	@$(MAKE) test-stacks-internal

	@# Остановка тестового контейнера
	@printf "\n"
	@$(call log-spinner,Остановка тестового контейнера,$(MAKE) down >/dev/null 2>&1)
	@$(call log-success,Тестовый контейнер остановлен)
	@printf "\n"

	@# Итоговая информация
	@$(call log-success,ВСЕ ТЕСТЫ ПРОЙДЕНЫ!)
	@printf "\n"
	@$(call log-info,Тестовое окружение (внутри контейнера):)
	@printf "Каталог<COL>$(TEST_DIR)/<ROW>Модули<COL>$(TEST_DIR)/modules/<ROW>Журнал<COL>$(TEST_DIR)/test-results.log\n" | { $(call print-table,16); }
	@printf "\n"
	@$(call log-info,Артефакты в /tmp автоматически очистятся при перезагрузке)

# Подготовка тестовых модулей
setup-test-modules:
	@$(call log-section,Создание модулей пакетными менеджерами)

	@# Node.js модуль (Bun)
	@$(MAKE) module MODULE_STACK=nodejs MODULE_TYPE=bun MODULE_NAME=test-nodejs MODULE_TARGET=$(TEST_DIR)/modules

	@# PHP модуль (Composer)
	@$(MAKE) module MODULE_STACK=php MODULE_TYPE=composer-lib MODULE_NAME=test-php MODULE_TARGET=$(TEST_DIR)/modules

	@# Python модуль (Poetry)
	@$(MAKE) module MODULE_STACK=python MODULE_TYPE=poetry MODULE_NAME=test-python MODULE_TARGET=$(TEST_DIR)/modules

	@# Rust модуль (Binary)
	@$(MAKE) module MODULE_STACK=rust MODULE_TYPE=bin MODULE_NAME=test-rust MODULE_TARGET=$(TEST_DIR)/modules
	@printf "\n"

# Тест базовых команд
.PHONY: test-commands-internal
test-commands-internal:
	@$(call log-section,Тестирование базовых команд)

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
	@printf "\n"
	@$(call log-section,Тестирование прав доступа)

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
	@printf "\n"
	@$(call log-section,Тестирование команд внутри модулей в контейнере)
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
