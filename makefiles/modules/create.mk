# ===================================
# Создание новых модулей проекта
# ===================================

# Переменные
MODULE_TARGET ?= modules
MODULE_STACK ?=
MODULE_TYPE ?=
MODULE_NAME ?=

# Главная команда
.PHONY: module
module:
	@$(call ensure-container-running)
	@$(call log-section,Создание нового модуля)

	@# Выбор стека если не указан
	@if [ -z "$(MODULE_STACK)" ]; then \
		printf "\n$(COLOR_INFO)Выберите стек:$(COLOR_RESET)\n"; \
		printf "  1) Node.js\n"; \
		printf "  2) PHP\n"; \
		printf "  3) Python\n"; \
		printf "  4) Rust\n"; \
		printf "\n$(COLOR_INFO)Ваш выбор [1-4]:$(COLOR_RESET) "; \
		read choice; \
		case $$choice in \
			1) STACK="nodejs" ;; \
			2) STACK="php" ;; \
			3) STACK="python" ;; \
			4) STACK="rust" ;; \
			*) $(call log-error,Неверный выбор); exit 1 ;; \
		esac; \
	else \
		STACK="$(MODULE_STACK)"; \
	fi; \
	\
	$(MAKE) module-select-type-$$STACK

# ===================================
# Выбор типа проекта для каждого стека
# ===================================

.PHONY: module-select-type-nodejs
module-select-type-nodejs:
	@if [ -z "$(MODULE_TYPE)" ]; then \
		printf "\n$(COLOR_INFO)Выберите тип Node.js проекта:$(COLOR_RESET)\n"; \
		printf "  1) Bun (TypeScript)\n"; \
		printf "  2) npm (TypeScript)\n"; \
		printf "  3) pnpm (TypeScript)\n"; \
		printf "  4) yarn (TypeScript)\n"; \
		printf "  5) Next.js (TypeScript + Tailwind)\n"; \
		printf "  6) Expo (TypeScript)\n"; \
		printf "  7) SvelteKit (TypeScript)\n"; \
		printf "\n$(COLOR_INFO)Ваш выбор [1-7]:$(COLOR_RESET) "; \
		read choice; \
		case $$choice in \
			1) TYPE="bun" ;; \
			2) TYPE="npm" ;; \
			3) TYPE="pnpm" ;; \
			4) TYPE="yarn" ;; \
			5) TYPE="nextjs" ;; \
			6) TYPE="expo" ;; \
			7) TYPE="svelte" ;; \
			*) $(call log-error,Неверный выбор); exit 1 ;; \
		esac; \
	else \
		TYPE="$(MODULE_TYPE)"; \
	fi; \
	\
	$(MAKE) module-request-name STACK=nodejs TYPE=$$TYPE

.PHONY: module-select-type-php
module-select-type-php:
	@if [ -z "$(MODULE_TYPE)" ]; then \
		printf "\n$(COLOR_INFO)Выберите тип PHP проекта:$(COLOR_RESET)\n"; \
		printf "  1) Composer library\n"; \
		printf "  2) Composer project\n"; \
		printf "  3) Laravel\n"; \
		printf "\n$(COLOR_INFO)Ваш выбор [1-3]:$(COLOR_RESET) "; \
		read choice; \
		case $$choice in \
			1) TYPE="composer-lib" ;; \
			2) TYPE="composer-project" ;; \
			3) TYPE="laravel" ;; \
			*) $(call log-error,Неверный выбор); exit 1 ;; \
		esac; \
	else \
		TYPE="$(MODULE_TYPE)"; \
	fi; \
	\
	$(MAKE) module-request-name STACK=php TYPE=$$TYPE

.PHONY: module-select-type-python
module-select-type-python:
	@if [ -z "$(MODULE_TYPE)" ]; then \
		printf "\n$(COLOR_INFO)Выберите тип Python проекта:$(COLOR_RESET)\n"; \
		printf "  1) UV (быстрый, рекомендуется)\n"; \
		printf "  2) Poetry\n"; \
		printf "\n$(COLOR_INFO)Ваш выбор [1-2]:$(COLOR_RESET) "; \
		read choice; \
		case $$choice in \
			1) TYPE="uv" ;; \
			2) TYPE="poetry" ;; \
			*) $(call log-error,Неверный выбор); exit 1 ;; \
		esac; \
	else \
		TYPE="$(MODULE_TYPE)"; \
	fi; \
	\
	$(MAKE) module-request-name STACK=python TYPE=$$TYPE

.PHONY: module-select-type-rust
module-select-type-rust:
	@if [ -z "$(MODULE_TYPE)" ]; then \
		printf "\n$(COLOR_INFO)Выберите тип Rust проекта:$(COLOR_RESET)\n"; \
		printf "  1) Binary (приложение)\n"; \
		printf "  2) Library (библиотека)\n"; \
		printf "  3) Dioxus (веб-приложение)\n"; \
		printf "\n$(COLOR_INFO)Ваш выбор [1-3]:$(COLOR_RESET) "; \
		read choice; \
		case $$choice in \
			1) TYPE="bin" ;; \
			2) TYPE="lib" ;; \
			3) TYPE="dioxus" ;; \
			*) $(call log-error,Неверный выбор); exit 1 ;; \
		esac; \
	else \
		TYPE="$(MODULE_TYPE)"; \
	fi; \
	\
	$(MAKE) module-request-name STACK=rust TYPE=$$TYPE

# ===================================
# Запрос имени модуля
# ===================================

.PHONY: module-request-name
module-request-name:
	@if [ -z "$(MODULE_NAME)" ]; then \
		printf "\n$(COLOR_INFO)Введите имя модуля:$(COLOR_RESET) "; \
		read name; \
		if [ -z "$$name" ]; then \
			$(call log-error,Имя не может быть пустым); \
			exit 1; \
		fi; \
		NAME="$$name"; \
	else \
		NAME="$(MODULE_NAME)"; \
	fi; \
	\
	$(MAKE) module-validate-and-create STACK=$(STACK) TYPE=$(TYPE) NAME=$$NAME

# ===================================
# Валидация и создание
# ===================================

.PHONY: module-validate-and-create
module-validate-and-create:
	@# Валидация имени (только буквы, цифры, дефис, underscore)
	@if ! echo "$(NAME)" | grep -qE '^[a-zA-Z0-9_-]+$$'; then \
		$(call log-error,Имя может содержать только буквы цифры дефис и underscore); \
		exit 1; \
	fi

	@# Проверка что модуль не существует
	@if [ -d "$(MODULE_TARGET)/$(NAME)" ]; then \
		$(call log-error,Модуль $(NAME) уже существует в $(MODULE_TARGET)/); \
		exit 1; \
	fi

	@# Создание директории если не существует (выполняется в контейнере для корректных прав)
	@$(MAKE) exec "mkdir -p $(MODULE_TARGET)" >/dev/null 2>&1

	@# Вызов генератора
	@$(MAKE) module-create-$(STACK)-$(TYPE) NAME=$(NAME)

# ===================================
# Генераторы для Node.js
# ===================================

.PHONY: module-create-nodejs-bun
module-create-nodejs-bun:
	@$(call log-info,Создание Bun проекта: $(NAME)...)
	@$(MAKE) exec "cd $(MODULE_TARGET) && bun init -y $(NAME)"
	@# Добавить scripts для тестов
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		cd $(MODULE_TARGET)/$(NAME) && npm pkg set scripts.test="echo 'nodejs test passed'" && npm pkg set scripts.build="echo 'nodejs build passed'"; \
	else \
		$(CONTAINER_RUNTIME) exec $(CONTAINER_NAME) sh -c 'cd $(MODULE_TARGET)/$(NAME) && npm pkg set scripts.test="echo '"'"'nodejs test passed'"'"'" && npm pkg set scripts.build="echo '"'"'nodejs build passed'"'"'"'; \
	fi
	@$(call log-success,Bun проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-npm
module-create-nodejs-npm:
	@$(call log-info,Создание npm проекта: $(NAME)...)
	@$(MAKE) exec "mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && npm init -y && npm pkg set type=module"
	@$(call log-success,npm проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-pnpm
module-create-nodejs-pnpm:
	@$(call log-info,Создание pnpm проекта: $(NAME)...)
	@$(MAKE) exec "mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && pnpm init"
	@$(call log-success,pnpm проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-yarn
module-create-nodejs-yarn:
	@$(call log-info,Создание yarn проекта: $(NAME)...)
	@$(MAKE) exec "mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && yarn init -y"
	@$(call log-success,yarn проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-nextjs
module-create-nodejs-nextjs:
	@$(call log-info,Создание Next.js проекта: $(NAME)...)
	@$(MAKE) exec "cd $(MODULE_TARGET) && bunx create-next-app@latest $(NAME) --typescript --tailwind --app --no-src-dir --import-alias '@/*' --turbopack --skip-install"
	@$(call log-success,Next.js проект создан: $(MODULE_TARGET)/$(NAME))
	@$(call log-info,Установка зависимостей...)
	@$(MAKE) exec "cd $(MODULE_TARGET)/$(NAME) && bun install"
	@$(call log-success,Зависимости установлены)

.PHONY: module-create-nodejs-expo
module-create-nodejs-expo:
	@$(call log-info,Создание Expo проекта: $(NAME)...)
	@$(MAKE) exec "cd $(MODULE_TARGET) && bunx create-expo-app@latest $(NAME) --template blank-typescript"
	@$(call log-success,Expo проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-svelte
module-create-nodejs-svelte:
	@$(call log-info,Создание SvelteKit проекта: $(NAME)...)
	@$(MAKE) exec "cd $(MODULE_TARGET) && bunx sv create $(NAME) --template minimal --types ts --no-add-ons --no-install"
	@$(call log-success,SvelteKit проект создан: $(MODULE_TARGET)/$(NAME))
	@$(call log-info,Установка зависимостей...)
	@$(MAKE) exec "cd $(MODULE_TARGET)/$(NAME) && bun install"
	@$(call log-success,Зависимости установлены)

# ===================================
# Генераторы для PHP
# ===================================

.PHONY: module-create-php-composer-lib
module-create-php-composer-lib:
	@$(call log-info,Создание Composer library: $(NAME)...)
	@$(MAKE) exec "mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && composer init --name='vendor/$(NAME)' --type=library --no-interaction"
	@# Добавить test script
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		cd $(MODULE_TARGET)/$(NAME) && composer config scripts.test "echo 'php test passed'"; \
	else \
		$(CONTAINER_RUNTIME) exec $(CONTAINER_NAME) sh -c 'cd $(MODULE_TARGET)/$(NAME) && composer config scripts.test "echo '"'"'php test passed'"'"'"'; \
	fi
	@$(call log-success,Composer library создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-php-composer-project
module-create-php-composer-project:
	@$(call log-info,Создание Composer project: $(NAME)...)
	@$(MAKE) exec "mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && composer init --name='vendor/$(NAME)' --type=project --no-interaction"
	@$(call log-success,Composer project создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-php-laravel
module-create-php-laravel:
	@$(call log-info,Создание Laravel проекта: $(NAME)...)
	@# Проверка установки Laravel installer
	@if ! $(MAKE) exec "command -v laravel"; then \
		$(call log-info,Установка Laravel installer...); \
		$(MAKE) exec "composer global require laravel/installer"; \
	fi
	@$(MAKE) exec "cd $(MODULE_TARGET) && laravel new $(NAME) --no-interaction"
	@$(call log-success,Laravel проект создан: $(MODULE_TARGET)/$(NAME))

# ===================================
# Генераторы для Python
# ===================================

.PHONY: module-create-python-uv
module-create-python-uv:
	@$(call log-info,Создание UV проекта: $(NAME)...)
	@$(MAKE) exec "cd $(MODULE_TARGET) && uv init $(NAME)"
	@$(call log-success,UV проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-python-poetry
module-create-python-poetry:
	@$(call log-info,Создание Poetry проекта: $(NAME)...)
	@$(MAKE) exec "cd $(MODULE_TARGET) && poetry new $(NAME)"
	@# Создать test_main.py
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		printf 'def test_main():\n    print("python test passed")\n    assert True\n' > $(MODULE_TARGET)/$(NAME)/tests/test_main.py; \
	else \
		$(CONTAINER_RUNTIME) exec $(CONTAINER_NAME) sh -c 'printf "def test_main():\n    print(\"python test passed\")\n    assert True\n" > $(MODULE_TARGET)/$(NAME)/tests/test_main.py'; \
	fi
	@$(call log-success,Poetry проект создан: $(MODULE_TARGET)/$(NAME))

# ===================================
# Генераторы для Rust
# ===================================

.PHONY: module-create-rust-bin
module-create-rust-bin:
	@$(call log-info,Создание Cargo binary: $(NAME)...)
	@$(MAKE) exec "cd $(MODULE_TARGET) && cargo new $(NAME)"
	@$(call log-success,Cargo binary создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-rust-lib
module-create-rust-lib:
	@$(call log-info,Создание Cargo library: $(NAME)...)
	@$(MAKE) exec "cd $(MODULE_TARGET) && cargo new $(NAME) --lib"
	@$(call log-success,Cargo library создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-rust-dioxus
module-create-rust-dioxus:
	@$(call log-info,Создание Dioxus проекта: $(NAME)...)
	@# Проверка установки dioxus-cli
	@if ! $(MAKE) exec "command -v dx"; then \
		$(call log-info,Установка Dioxus CLI...); \
		$(MAKE) exec "cargo install dioxus-cli"; \
	fi
	@$(MAKE) exec "cd $(MODULE_TARGET) && dx new $(NAME) --platform web"
	@$(call log-success,Dioxus проект создан: $(MODULE_TARGET)/$(NAME))
