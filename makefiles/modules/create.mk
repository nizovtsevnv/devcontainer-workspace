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
	@$(MAKE) module-interactive MODULE_STACK="$(MODULE_STACK)" MODULE_TYPE="$(MODULE_TYPE)" MODULE_NAME="$(MODULE_NAME)" MODULE_TARGET="$(MODULE_TARGET)"

# Интерактивная команда (только для запуска внутри контейнера)
.PHONY: module-interactive
module-interactive:
	@$(call log-section,Создание нового модуля)
	@printf "\n"

	@# Выбор стека если не указан
	@if [ -z "$(MODULE_STACK)" ]; then \
		$(call log-info,Шаг 1/3: Выберите стек технологий); \
		DISPLAY=$$(sh makefiles/scripts/select-menu.sh "Node.js" "PHP" "Python" "Rust") || exit 1; \
		case "$$DISPLAY" in \
			"Node.js") STACK="nodejs" ;; \
			"PHP") STACK="php" ;; \
			"Python") STACK="python" ;; \
			"Rust") STACK="rust" ;; \
		esac; \
		printf "\n"; \
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
		$(call log-info,Шаг 2/3: Выберите тип Node.js проекта); \
		SEL=$$(sh makefiles/scripts/select-menu.sh "Bun (TypeScript)" "npm (TypeScript)" "pnpm (TypeScript)" "yarn (TypeScript)" "Next.js (TypeScript + Tailwind)" "Expo (TypeScript)" "SvelteKit (TypeScript)") || exit 1; \
		case "$$SEL" in \
			"Bun"*) TYPE="bun" ;; "npm"*) TYPE="npm" ;; "pnpm"*) TYPE="pnpm" ;; "yarn"*) TYPE="yarn" ;; "Next.js"*) TYPE="nextjs" ;; "Expo"*) TYPE="expo" ;; "SvelteKit"*) TYPE="svelte" ;; \
		esac; \
		printf "\n"; \
	else \
		TYPE="$(MODULE_TYPE)"; \
	fi; \
	$(MAKE) module-request-name STACK=nodejs TYPE=$$TYPE

.PHONY: module-select-type-php
module-select-type-php:
	@if [ -z "$(MODULE_TYPE)" ]; then \
		$(call log-info,Шаг 2/3: Выберите тип PHP проекта); \
		SEL=$$(sh makefiles/scripts/select-menu.sh "Composer library" "Composer project" "Laravel") || exit 1; \
		case "$$SEL" in \
			"Composer library") TYPE="composer-lib" ;; "Composer project") TYPE="composer-project" ;; "Laravel") TYPE="laravel" ;; \
		esac; \
		printf "\n"; \
	else \
		TYPE="$(MODULE_TYPE)"; \
	fi; \
	$(MAKE) module-request-name STACK=php TYPE=$$TYPE

.PHONY: module-select-type-python
module-select-type-python:
	@if [ -z "$(MODULE_TYPE)" ]; then \
		$(call log-info,Шаг 2/3: Выберите тип Python проекта); \
		SEL=$$(sh makefiles/scripts/select-menu.sh "UV (быстрый, рекомендуется)" "Poetry") || exit 1; \
		case "$$SEL" in \
			"UV"*) TYPE="uv" ;; \
			"Poetry") TYPE="poetry" ;; \
		esac; \
		printf "\n"; \
	else \
		TYPE="$(MODULE_TYPE)"; \
	fi; \
	\
	$(MAKE) module-request-name STACK=python TYPE=$$TYPE

.PHONY: module-select-type-rust
module-select-type-rust:
	@if [ -z "$(MODULE_TYPE)" ]; then \
		$(call log-info,Шаг 2/3: Выберите тип Rust проекта); \
		SEL=$$(sh makefiles/scripts/select-menu.sh "Binary (приложение)" "Library (библиотека)" "Dioxus (веб-приложение)") || exit 1; \
		case "$$SEL" in \
			"Binary"*) TYPE="bin" ;; \
			"Library"*) TYPE="lib" ;; \
			"Dioxus"*) TYPE="dioxus" ;; \
		esac; \
		printf "\n"; \
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
		$(call log-info,Шаг 3/3: Введите имя модуля (буквы цифры дефис underscore)); \
		printf "\n"; \
		NAME=$$($(call ask-input,example-module,Имя модуля)); \
		if [ -z "$$NAME" ]; then \
			$(call log-error,Имя не может быть пустым); \
			exit 1; \
		fi; \
		printf "\n"; \
	else \
		NAME="$(MODULE_NAME)"; \
	fi; \
	\
	$(MAKE) module-validate-and-create STACK=$(STACK) TYPE=$(TYPE) NAME="$$NAME"

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
	@$(call log-spinner,Создание Bun проекта: $(NAME),$(MAKE) exec "sh -c 'cd $(MODULE_TARGET) && bun init -y $(NAME)'")
	@# Добавить scripts для тестов
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		cd $(MODULE_TARGET)/$(NAME) && npm pkg set scripts.test="echo 'nodejs test passed'" && npm pkg set scripts.build="echo 'nodejs build passed'"; \
	else \
		$(CONTAINER_RUNTIME) exec -w $(CONTAINER_WORKDIR) $(CONTAINER_NAME) bash -c "cd $(MODULE_TARGET)/$(NAME) && npm pkg set scripts.test=\"echo 'nodejs test passed'\" && npm pkg set scripts.build=\"echo 'nodejs build passed'\""; \
	fi
	@$(call log-success,Bun проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-npm
module-create-nodejs-npm:
	@$(call log-spinner,Создание npm проекта: $(NAME),$(MAKE) exec "sh -c 'mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && npm init -y && npm pkg set type=module'")
	@$(call log-success,npm проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-pnpm
module-create-nodejs-pnpm:
	@$(call log-spinner,Создание pnpm проекта: $(NAME),$(MAKE) exec "sh -c 'mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && pnpm init'")
	@$(call log-success,pnpm проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-yarn
module-create-nodejs-yarn:
	@$(call log-spinner,Создание yarn проекта: $(NAME),$(MAKE) exec "sh -c 'mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && yarn init -y'")
	@$(call log-success,yarn проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-nextjs
module-create-nodejs-nextjs:
	@$(call log-info,Создание Next.js проекта: $(NAME))
	@printf "\n"
	@$(MAKE) exec-interactive "sh -c 'cd $(MODULE_TARGET) && bunx create-next-app@latest $(NAME) --typescript --tailwind --app --no-src-dir --import-alias @/* --turbopack --skip-install'"
	@printf "\n"
	@$(call log-success,Next.js проект создан: $(MODULE_TARGET)/$(NAME))
	@$(call log-spinner,Установка зависимостей,$(MAKE) exec "cd $(MODULE_TARGET)/$(NAME) && bun install")
	@$(call log-success,Зависимости установлены)

.PHONY: module-create-nodejs-expo
module-create-nodejs-expo:
	@$(call log-spinner,Создание Expo проекта: $(NAME),$(MAKE) exec "sh -c 'cd $(MODULE_TARGET) && bunx create-expo-app@latest $(NAME) --template blank-typescript'")
	@$(call log-success,Expo проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-nodejs-svelte
module-create-nodejs-svelte:
	@$(call log-spinner,Создание SvelteKit проекта: $(NAME),$(MAKE) exec "sh -c 'cd $(MODULE_TARGET) && bunx sv create $(NAME) --template minimal --types ts --no-add-ons --no-install'")
	@$(call log-success,SvelteKit проект создан: $(MODULE_TARGET)/$(NAME))
	@$(call log-spinner,Установка зависимостей,$(MAKE) exec "cd $(MODULE_TARGET)/$(NAME) && bun install")
	@$(call log-success,Зависимости установлены)

# ===================================
# Генераторы для PHP
# ===================================

.PHONY: module-create-php-composer-lib
module-create-php-composer-lib:
	@$(call log-spinner,Создание Composer library: $(NAME),$(MAKE) exec "sh -c 'mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && composer init --name=vendor/$(NAME) --type=library --no-interaction'")
	@# Добавить test script
	@if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		cd $(MODULE_TARGET)/$(NAME) && composer config scripts.test "echo 'php test passed'"; \
	else \
		$(CONTAINER_RUNTIME) exec -w $(CONTAINER_WORKDIR) $(CONTAINER_NAME) bash -c "cd $(MODULE_TARGET)/$(NAME) && composer config scripts.test \"echo 'php test passed'\""; \
	fi
	@$(call log-success,Composer library создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-php-composer-project
module-create-php-composer-project:
	@$(call log-spinner,Создание Composer project: $(NAME),$(MAKE) exec "sh -c 'mkdir -p $(MODULE_TARGET)/$(NAME) && cd $(MODULE_TARGET)/$(NAME) && composer init --name=vendor/$(NAME) --type=project --no-interaction'")
	@$(call log-success,Composer project создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-php-laravel
module-create-php-laravel:
	@# Проверка установки Laravel installer
	@if ! $(MAKE) exec "command -v laravel"; then \
		$(call log-info,Установка Laravel installer...); \
		$(MAKE) exec "composer global require laravel/installer"; \
	fi
	@$(call log-spinner,Создание Laravel проекта: $(NAME),$(MAKE) exec "sh -c 'cd $(MODULE_TARGET) && laravel new $(NAME) --no-interaction'")
	@$(call log-success,Laravel проект создан: $(MODULE_TARGET)/$(NAME))

# ===================================
# Генераторы для Python
# ===================================

.PHONY: module-create-python-uv
module-create-python-uv:
	@$(call log-spinner,Создание UV проекта: $(NAME),$(MAKE) exec "sh -c 'cd $(MODULE_TARGET) && uv init $(NAME)'")
	@$(call log-success,UV проект создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-python-poetry
module-create-python-poetry:
	@$(call log-spinner,Создание Poetry проекта: $(NAME),$(MAKE) exec "sh -c 'cd $(MODULE_TARGET) && poetry new $(NAME)'")
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
	@$(call log-spinner,Создание Cargo binary: $(NAME),$(MAKE) exec "sh -c 'cd $(MODULE_TARGET) && cargo new $(NAME)'")
	@$(call log-success,Cargo binary создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-rust-lib
module-create-rust-lib:
	@$(call log-spinner,Создание Cargo library: $(NAME),$(MAKE) exec "sh -c 'cd $(MODULE_TARGET) && cargo new $(NAME) --lib'")
	@$(call log-success,Cargo library создан: $(MODULE_TARGET)/$(NAME))

.PHONY: module-create-rust-dioxus
module-create-rust-dioxus:
	@# Проверка установки dioxus-cli
	@if ! $(MAKE) exec "command -v dx"; then \
		$(call log-info,Установка Dioxus CLI...); \
		$(MAKE) exec "cargo install dioxus-cli"; \
	fi
	@$(call log-spinner,Создание Dioxus проекта: $(NAME),$(MAKE) exec "sh -c 'cd $(MODULE_TARGET) && dx new $(NAME) --platform web'")
	@$(call log-success,Dioxus проект создан: $(MODULE_TARGET)/$(NAME))
