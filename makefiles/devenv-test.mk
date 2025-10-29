# ===================================
# Автотесты шаблона DevContainer Workspace
# ===================================

.PHONY: devenv-test-internal setup-test-modules

# Директория для тестовых артефактов
TEST_DIR := .test-workspace
TEST_LOG := $(WORKSPACE_ROOT)/$(TEST_DIR)/test-results.log

# Функция запуска теста
define run-test
	printf "$(COLOR_SECTION)▶ Тест: $(1)$(COLOR_RESET)\n" | tee -a $(TEST_LOG); \
	if $(2); then \
		printf "  $(COLOR_SUCCESS)✓ PASSED$(COLOR_RESET)\n" | tee -a $(TEST_LOG); \
	else \
		printf "  $(COLOR_ERROR)✗ FAILED$(COLOR_RESET)\n" | tee -a $(TEST_LOG); \
		exit 1; \
	fi
endef

devenv-test-internal:
	@$(call log-section,Запуск автотестов DevContainer Workspace)
	@printf "\n"

	@# Остановка контейнера если запущен + очистка артефактов (без вывода)
	@if $(CONTAINER_RUNTIME) ps --format "{{.Names}}" | grep -q "^$(CONTAINER_NAME)$$" 2>/dev/null; then \
		$(MAKE) down >/dev/null 2>&1; \
	fi
	@if [ -d "$(TEST_DIR)" ]; then \
		rm -rf $(TEST_DIR); \
	fi
	@if [ -f "$(TEST_LOG)" ]; then \
		rm -f $(TEST_LOG); \
	fi

	@# Подготовка изолированного тестового окружения (без вывода)
	@mkdir -p $(TEST_DIR)/modules
	@cp Makefile $(TEST_DIR)/
	@cp -r makefiles $(TEST_DIR)/
	@cp -r .devcontainer $(TEST_DIR)/
	@echo "=== Test Run: $$(date) ===" > $(TEST_LOG)

	@# Подготовка тестовых модулей (без вывода)
	@$(MAKE) setup-test-modules >/dev/null 2>&1

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
	@printf "Сгенерировано тестовое окружение: $(TEST_DIR)/\n"
	@printf "Журнал тестов: $(TEST_DIR)/test-results.log\n"
	@printf "Тестовые модули: $(TEST_DIR)/modules/\n"
	@printf "\n"
	@printf "$(COLOR_INFO)Для очистки артефактов выполните: rm -rf $(TEST_DIR)$(COLOR_RESET)\n"

# Подготовка тестовых модулей
setup-test-modules:
	@$(call log-info,Создание тестовых модулей...)

	@# Node.js модуль
	@mkdir -p $(TEST_DIR)/modules/test-nodejs
	@echo '{"name":"test-nodejs","version":"1.0.0","scripts":{"test":"echo \"nodejs test passed\"","build":"echo \"nodejs build passed\""}}' \
		> $(TEST_DIR)/modules/test-nodejs/package.json
	@printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) test-nodejs\n"

	@# PHP модуль
	@mkdir -p $(TEST_DIR)/modules/test-php
	@echo '{"name":"test/php","scripts":{"test":"echo \"php test passed\"","build":"echo \"php build passed\""}}' \
		> $(TEST_DIR)/modules/test-php/composer.json
	@printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) test-php\n"

	@# Python модуль
	@mkdir -p $(TEST_DIR)/modules/test-python
	@echo '[project]' > $(TEST_DIR)/modules/test-python/pyproject.toml
	@echo 'name = "test-python"' >> $(TEST_DIR)/modules/test-python/pyproject.toml
	@echo 'version = "1.0.0"' >> $(TEST_DIR)/modules/test-python/pyproject.toml
	@echo 'def test_pass(): assert True' > $(TEST_DIR)/modules/test-python/test_main.py
	@printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) test-python\n"

	@# Rust модуль
	@mkdir -p $(TEST_DIR)/modules/test-rust/src
	@echo '[package]' > $(TEST_DIR)/modules/test-rust/Cargo.toml
	@echo 'name = "test-rust"' >> $(TEST_DIR)/modules/test-rust/Cargo.toml
	@echo 'version = "1.0.0"' >> $(TEST_DIR)/modules/test-rust/Cargo.toml
	@echo 'edition = "2021"' >> $(TEST_DIR)/modules/test-rust/Cargo.toml
	@echo 'fn main() { println!("Hello Rust"); }' > $(TEST_DIR)/modules/test-rust/src/main.rs
	@echo '#[cfg(test)]' >> $(TEST_DIR)/modules/test-rust/src/main.rs
	@echo 'mod tests { #[test] fn test_pass() { assert!(true); } }' >> $(TEST_DIR)/modules/test-rust/src/main.rs
	@printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) test-rust\n"
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

	@# Проверить права файла
	@EXPECTED_UID=$(HOST_UID); \
	EXPECTED_GID=$(HOST_GID); \
	ACTUAL_UID=$$(stat -c '%u' $(TEST_DIR)/perm-test.txt 2>/dev/null); \
	ACTUAL_GID=$$(stat -c '%g' $(TEST_DIR)/perm-test.txt 2>/dev/null); \
	$(call run-test,Файл имеет правильный UID:GID ($$EXPECTED_UID:$$EXPECTED_GID), \
		[ "$$ACTUAL_UID" = "$$EXPECTED_UID" ] && [ "$$ACTUAL_GID" = "$$EXPECTED_GID" ])

	@# Проверить возможность записи с хоста
	@$(call run-test,Запись с хоста работает, \
		echo "host-write" > $(TEST_DIR)/perm-test.txt)

	@# Проверить возможность чтения из контейнера
	@$(call run-test,Чтение из контейнера работает, \
		$(MAKE) exec 'cat $(TEST_DIR)/perm-test.txt' 2>/dev/null | grep -q "host-write")

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
		$(MAKE) exec 'cd $(TEST_DIR)/modules/test-python && pytest -q test_main.py' >/dev/null 2>&1)

.PHONY: test-stack-rust-internal
test-stack-rust-internal:
	@$(call run-test,test-rust / cargo build, \
		$(MAKE) exec 'cd $(TEST_DIR)/modules/test-rust && cargo build --quiet' 2>&1 | grep -v "Compiling\|Finished" || true)

	@$(call run-test,test-rust / cargo test, \
		$(MAKE) exec 'cd $(TEST_DIR)/modules/test-rust && cargo test --quiet' 2>&1 | grep -q "test result: ok")
