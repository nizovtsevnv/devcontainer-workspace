# ===================================
# Создание новых модулей проекта
# ===================================

# Переменные
MODULE_TARGET ?= modules
MODULE_STACK ?=
MODULE_TYPE ?=
MODULE_NAME ?=

# Главная команда (запуск с хоста или изнутри контейнера)
.PHONY: module
module:
	@$(call ensure-devenv-ready)
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		$(MAKE) module-interactive MODULE_STACK="$(MODULE_STACK)" MODULE_TYPE="$(MODULE_TYPE)" MODULE_NAME="$(MODULE_NAME)" MODULE_TARGET="$(MODULE_TARGET)"; \
	else \
		$(MAKE) exec-interactive "make module-interactive MODULE_STACK='$(MODULE_STACK)' MODULE_TYPE='$(MODULE_TYPE)' MODULE_NAME='$(MODULE_NAME)' MODULE_TARGET='$(MODULE_TARGET)'"; \
	fi

# Интерактивная команда (только для запуска внутри контейнера)
.PHONY: module-interactive
module-interactive:
	@$(call log-info,Создание нового модуля:)

	@# Выбор стека если не указан
	@if [ -z "$(MODULE_STACK)" ]; then \
		DISPLAY=$$(gum choose --header "Выберите стек:" "Node.js" "PHP" "Python" "Rust"); \
		case "$$DISPLAY" in \
			"Node.js") STACK="nodejs" ;; \
			"PHP") STACK="php" ;; \
			"Python") STACK="python" ;; \
			"Rust") STACK="rust" ;; \
		esac; \
	else \
		STACK="$(MODULE_STACK)"; \
	fi; \
	$(MAKE) module-select-type-$$STACK

# ===================================
# Выбор типа проекта для каждого стека
# ===================================

.PHONY: module-select-type-nodejs
module-select-type-nodejs:
	@if [ -z "$(MODULE_TYPE)" ]; then \
		SEL=$$(gum choose --header "Выберите тип Node.js проекта:" "Bun (TypeScript)" "npm (TypeScript)" "pnpm (TypeScript)" "yarn (TypeScript)" "Next.js (TypeScript + Tailwind)" "Expo (TypeScript)" "SvelteKit (TypeScript)"); \
		case "$$SEL" in \
			"Bun"*) TYPE="bun" ;; "npm"*) TYPE="npm" ;; "pnpm"*) TYPE="pnpm" ;; "yarn"*) TYPE="yarn" ;; "Next.js"*) TYPE="nextjs" ;; "Expo"*) TYPE="expo" ;; "SvelteKit"*) TYPE="svelte" ;; \
		esac; \
	else \
		TYPE="$(MODULE_TYPE)"; \
	fi; \
	$(MAKE) module-request-name STACK=nodejs TYPE=$$TYPE

.PHONY: module-select-type-php
module-select-type-php:
	@if [ -z "$(MODULE_TYPE)" ]; then \
		SEL=$$(gum choose --header "Выберите тип PHP проекта:" "Composer library" "Composer project" "Laravel"); \
		case "$$SEL" in \
			"Composer library") TYPE="composer-lib" ;; "Composer project") TYPE="composer-project" ;; "Laravel") TYPE="laravel" ;; \
		esac; \
	else \
		TYPE="$(MODULE_TYPE)"; \
	fi; \
	$(MAKE) module-request-name STACK=php TYPE=$$TYPE

.PHONY: module-select-type-python
module-select-type-python:
	@if [ -z "$(MODULE_TYPE)" ]; then \
		SEL=$$(gum choose --header "Выберите тип Python проекта:" "UV (быстрый, рекомендуется)" "Poetry"); \
		case "$$SEL" in \
			"UV"*) TYPE="uv" ;; \
			"Poetry") TYPE="poetry" ;; \
		esac; \
	else \
		TYPE="$(MODULE_TYPE)"; \
	fi; \
	\
	$(MAKE) module-request-name STACK=python TYPE=$$TYPE

.PHONY: module-select-type-rust
module-select-type-rust:
	@if [ -z "$(MODULE_TYPE)" ]; then \
		SEL=$$(gum choose --header "Выберите тип Rust проекта:" "Binary (приложение)" "Library (библиотека)" "Dioxus (веб-приложение)"); \
		case "$$SEL" in \
			"Binary"*) TYPE="bin" ;; \
			"Library"*) TYPE="lib" ;; \
			"Dioxus"*) TYPE="dioxus" ;; \
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
		NAME=$$(gum input --prompt "Введите имя модуля: " --placeholder "example-module"); \
		if [ -z "$$NAME" ]; then \
			printf "$(COLOR_ERROR)✗ %s$(COLOR_RESET)\n" "Имя не может быть пустым" >&2; \
			exit 1; \
		fi; \
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
		printf "$(COLOR_ERROR)✗ %s$(COLOR_RESET)\n" "Имя может содержать только буквы цифры дефис и underscore" >&2; \
		exit 1; \
	fi

	@# Проверка что модуль не существует
	@if [ -d "$(MODULE_TARGET)/$(NAME)" ]; then \
		printf "$(COLOR_ERROR)✗ %s$(COLOR_RESET)\n" "Модуль $(NAME) уже существует в $(MODULE_TARGET)/" >&2; \
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
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание Bun проекта: $(NAME)' -- sh -c 'cd $(MODULE_TARGET) && bun init -y $(NAME)'" >/dev/null 2>&1
	@# Добавить scripts для тестов
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		cd $(MODULE_TARGET)/$(NAME) && npm pkg set scripts.test="echo 'nodejs test passed'" && npm pkg set scripts.build="echo 'nodejs build passed'"; \
	else \
		$(CONTAINER_RUNTIME) exec -w $(CONTAINER_WORKDIR) $(CONTAINER_NAME) bash -c "cd $(MODULE_TARGET)/$(NAME) && npm pkg set scripts.test=\"echo 'nodejs test passed'\" && npm pkg set scripts.build=\"echo 'nodejs build passed'\""; \
	fi
	@$(call log-success,Bun проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-npm
module-create-nodejs-npm:
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание npm проекта: $(NAME)' -- sh -c 'mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && npm init -y && npm pkg set type=module'" >/dev/null 2>&1
	@$(call log-success,npm проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-pnpm
module-create-nodejs-pnpm:
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание pnpm проекта: $(NAME)' -- sh -c 'mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && pnpm init'" >/dev/null 2>&1
	@$(call log-success,pnpm проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-yarn
module-create-nodejs-yarn:
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание yarn проекта: $(NAME)' -- sh -c 'mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && yarn init -y'" >/dev/null 2>&1
	@$(call log-success,yarn проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-nextjs
module-create-nodejs-nextjs:
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание Next.js проекта: $(NAME)' -- sh -c 'cd $(MODULE_TARGET) && bunx create-next-app@latest $(NAME) --typescript --tailwind --app --no-src-dir --import-alias @/* --turbopack --skip-install'" >/dev/null 2>&1
	@$(call log-success,Next.js проект создан: $(MODULE_TARGET)/$(NAME))
	@$(call log-info,Установка зависимостей...)
	@$(MAKE) exec "cd $(MODULE_TARGET)/$(NAME) && bun install"
	@$(call log-success,Зависимости установлены)

.PHONY: module-create-nodejs-expo
module-create-nodejs-expo:
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание Expo проекта: $(NAME)' -- sh -c 'cd $(MODULE_TARGET) && bunx create-expo-app@latest $(NAME) --template blank-typescript'" >/dev/null 2>&1
	@$(call log-success,Expo проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-svelte
module-create-nodejs-svelte:
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание SvelteKit проекта: $(NAME)' -- sh -c 'cd $(MODULE_TARGET) && bunx sv create $(NAME) --template minimal --types ts --no-add-ons --no-install'" >/dev/null 2>&1
	@$(call log-success,SvelteKit проект создан: $(MODULE_TARGET)/$(NAME))
	@$(call log-info,Установка зависимостей...)
	@$(MAKE) exec "cd $(MODULE_TARGET)/$(NAME) && bun install"
	@$(call log-success,Зависимости установлены)

# ===================================
# Генераторы для PHP
# ===================================

.PHONY: module-create-php-composer-lib
module-create-php-composer-lib:
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание Composer library: $(NAME)' -- sh -c 'mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && composer init --name=vendor/$(NAME) --type=library --no-interaction'" >/dev/null 2>&1
	@# Добавить test script
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		cd $(MODULE_TARGET)/$(NAME) && composer config scripts.test "echo 'php test passed'"; \
	else \
		$(CONTAINER_RUNTIME) exec -w $(CONTAINER_WORKDIR) $(CONTAINER_NAME) bash -c "cd $(MODULE_TARGET)/$(NAME) && composer config scripts.test \"echo 'php test passed'\""; \
	fi
	@$(call log-success,Composer library создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-php-composer-project
module-create-php-composer-project:
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание Composer project: $(NAME)' -- sh -c 'mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && composer init --name=vendor/$(NAME) --type=project --no-interaction'" >/dev/null 2>&1
	@$(call log-success,Composer project создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-php-laravel
module-create-php-laravel:
	@# Проверка установки Laravel installer
	@if ! $(MAKE) exec "command -v laravel"; then \
		$(call log-info,Установка Laravel installer...); \
		$(MAKE) exec "composer global require laravel/installer"; \
	fi
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание Laravel проекта: $(NAME)' -- sh -c 'cd $(MODULE_TARGET) && laravel new $(NAME) --no-interaction'" >/dev/null 2>&1
	@$(call log-success,Laravel проект создан: $(MODULE_TARGET)/$(NAME))

# ===================================
# Генераторы для Python
# ===================================

.PHONY: module-create-python-uv
module-create-python-uv:
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание UV проекта: $(NAME)' -- sh -c 'cd $(MODULE_TARGET) && uv init $(NAME)'" >/dev/null 2>&1
	@$(call log-success,UV проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-python-poetry
module-create-python-poetry:
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание Poetry проекта: $(NAME)' -- sh -c 'cd $(MODULE_TARGET) && poetry new $(NAME)'" >/dev/null 2>&1
	@# Создать test_main.py
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		printf 'def test_main():\n    print("python test passed")\n    assert True\n' > $(MODULE_TARGET)/$(NAME)/tests/test_main.py; \
	else \
		$(CONTAINER_RUNTIME) exec -w $(CONTAINER_WORKDIR) $(CONTAINER_NAME) bash -c "printf 'def test_main():\n    print(\"python test passed\")\n    assert True\n' > $(MODULE_TARGET)/$(NAME)/tests/test_main.py"; \
	fi
	@$(call log-success,Poetry проект создан: $(MODULE_TARGET)/$(NAME))

# ===================================
# Генераторы для Rust
# ===================================

.PHONY: module-create-rust-bin
module-create-rust-bin:
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание Cargo binary: $(NAME)' -- sh -c 'cd $(MODULE_TARGET) && cargo new $(NAME)'" >/dev/null 2>&1
	@$(call log-success,Cargo binary создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-rust-lib
module-create-rust-lib:
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание Cargo library: $(NAME)' -- sh -c 'cd $(MODULE_TARGET) && cargo new $(NAME) --lib'" >/dev/null 2>&1
	@$(call log-success,Cargo library создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-rust-dioxus
module-create-rust-dioxus:
	@# Проверка установки dioxus-cli
	@if ! $(MAKE) exec "command -v dx"; then \
		$(call log-info,Установка Dioxus CLI...); \
		$(MAKE) exec "cargo install dioxus-cli"; \
	fi
	@$(MAKE) exec "gum spin --spinner dot --title 'Создание Dioxus проекта: $(NAME)' -- sh -c 'cd $(MODULE_TARGET) && dx new $(NAME) --platform web'" >/dev/null 2>&1
	@$(call log-success,Dioxus проект создан: $(MODULE_TARGET)/$(NAME))
