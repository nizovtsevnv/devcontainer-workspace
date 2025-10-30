# ===================================
# Автоопределение технологий модулей
# ===================================

# ===================================
# Функции определения технологий
# ===================================

# Определить технологии в модуле по наличию маркерных файлов
# Параметр: $(1) - путь к модулю
# Возвращает: список технологий (nodejs php python rust makefile gitlab github)
define detect-module-tech
$(strip \
	$(if $(wildcard $(1)/package.json),nodejs) \
	$(if $(wildcard $(1)/composer.json),php) \
	$(if $(or $(wildcard $(1)/pyproject.toml),$(wildcard $(1)/requirements.txt),$(wildcard $(1)/setup.py)),python) \
	$(if $(wildcard $(1)/Cargo.toml),rust) \
	$(if $(wildcard $(1)/Makefile),makefile) \
	$(if $(wildcard $(1)/.gitlab-ci.yml),gitlab) \
	$(if $(wildcard $(1)/.github/workflows),github) \
)
endef

# ===================================
# Функции определения пакетных менеджеров Node.js
# ===================================

# Определить Node.js пакетный менеджер по lock файлам
# Параметр: $(1) - путь к модулю
# Приоритет: bun.lockb > pnpm-lock.yaml > yarn.lock > package-lock.json > bun (default)
# Возвращает: bun | pnpm | yarn | npm
define detect-nodejs-manager
$(strip \
	$(if $(wildcard $(1)/bun.lockb),bun,\
	$(if $(wildcard $(1)/pnpm-lock.yaml),pnpm,\
	$(if $(wildcard $(1)/yarn.lock),yarn,\
	$(if $(wildcard $(1)/package-lock.json),npm,\
	bun)))) \
)
endef

# ===================================
# Функции определения пакетных менеджеров Python
# ===================================

# Определить Python пакетный менеджер по lock файлам
# Параметр: $(1) - путь к модулю
# Приоритет: uv.lock > poetry.lock > Pipfile > requirements.txt > uv (default)
# Возвращает: uv | poetry | pipenv | pip
define detect-python-manager
$(strip \
	$(if $(wildcard $(1)/uv.lock),uv,\
	$(if $(wildcard $(1)/poetry.lock),poetry,\
	$(if $(wildcard $(1)/Pipfile),pipenv,\
	$(if $(wildcard $(1)/requirements.txt),pip,\
	uv)))) \
)
endef

# ===================================
# Функции определения пакетных менеджеров PHP
# ===================================

# PHP всегда использует composer
# Параметр: $(1) - путь к модулю
# Возвращает: composer
define detect-php-manager
composer
endef

# ===================================
# Функции определения пакетных менеджеров Rust
# ===================================

# Rust всегда использует cargo
# Параметр: $(1) - путь к модулю
# Возвращает: cargo
define detect-rust-manager
cargo
endef

# ===================================
# Вспомогательные функции
# ===================================

# Получить primary пакетный менеджер для технологии
# Параметр: $(1) - путь к модулю, $(2) - технология (nodejs|python|php|rust)
# Возвращает: имя пакетного менеджера
define get-primary-manager
$(strip \
	$(if $(filter nodejs,$(2)),$(call detect-nodejs-manager,$(1))) \
	$(if $(filter python,$(2)),$(call detect-python-manager,$(1))) \
	$(if $(filter php,$(2)),$(call detect-php-manager,$(1))) \
	$(if $(filter rust,$(2)),$(call detect-rust-manager,$(1))) \
)
endef

# Получить все доступные пакетные менеджеры для технологии
# Параметр: $(1) - путь к модулю, $(2) - технология (nodejs|python|php|rust)
# Возвращает: список пакетных менеджеров
define get-all-managers
$(strip \
	$(if $(filter nodejs,$(2)),$(call get-nodejs-managers,$(1))) \
	$(if $(filter python,$(2)),$(call get-python-managers,$(1))) \
	$(if $(filter php,$(2)),$(call get-php-managers,$(1))) \
	$(if $(filter rust,$(2)),$(call get-rust-managers,$(1))) \
)
endef

# ===================================
# Функции получения информации о модулях
# ===================================

# Получить только версию модуля (без типа)
# Параметр: $(1) - путь к модулю
# Возвращает: строку вида "1.0.0" или пустую строку
# Использование: version=$$($(call get-module-version,$(MODULE_PATH)))
define get-module-version
	module_path="$(1)"; \
	version=""; \
	\
	if [ -f "$$module_path/package.json" ]; then \
		version=$$(grep -m1 '"version"' "$$module_path/package.json" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo ""); \
	elif [ -f "$$module_path/composer.json" ]; then \
		version=$$(grep -m1 '"version"' "$$module_path/composer.json" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo ""); \
	elif [ -f "$$module_path/pyproject.toml" ]; then \
		version=$$(grep -m1 '^version[[:space:]]*=' "$$module_path/pyproject.toml" | sed 's/.*version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/' || echo ""); \
	elif [ -f "$$module_path/Cargo.toml" ]; then \
		version=$$(grep -m1 '^version[[:space:]]*=' "$$module_path/Cargo.toml" | sed 's/.*version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/' || echo ""); \
	fi; \
	\
	echo "$$version"
endef

# Получить информацию о версиях модуля (композиция файловой проверки + get-module-version)
# Параметр: $(1) - путь к модулю
# Возвращает: строку вида "Node.js-модуль 1.0.0, Rust-модуль 0.1.0"
# Использование: tech_info=$$($(call get-module-info,$(MODULE_PATH)))
define get-module-info
	module_path="$(1)"; \
	version=$$($(call get-module-version,$(1))); \
	tech_info=""; \
	\
	if [ -f "$$module_path/package.json" ]; then \
		[ -n "$$tech_info" ] && tech_info="$$tech_info, "; \
		if [ -n "$$version" ]; then \
			tech_info="$$tech_info""Node.js-модуль $$version"; \
		else \
			tech_info="$$tech_info""Node.js-модуль"; \
		fi; \
	fi; \
	\
	if [ -f "$$module_path/composer.json" ]; then \
		[ -n "$$tech_info" ] && tech_info="$$tech_info, "; \
		if [ -n "$$version" ]; then \
			tech_info="$$tech_info""PHP-модуль $$version"; \
		else \
			tech_info="$$tech_info""PHP-модуль"; \
		fi; \
	fi; \
	\
	if [ -f "$$module_path/pyproject.toml" ] || [ -f "$$module_path/requirements.txt" ] || [ -f "$$module_path/setup.py" ]; then \
		[ -n "$$tech_info" ] && tech_info="$$tech_info, "; \
		if [ -n "$$version" ]; then \
			tech_info="$$tech_info""Python-модуль $$version"; \
		else \
			tech_info="$$tech_info""Python-модуль"; \
		fi; \
	fi; \
	\
	if [ -f "$$module_path/Cargo.toml" ]; then \
		[ -n "$$tech_info" ] && tech_info="$$tech_info, "; \
		if [ -n "$$version" ]; then \
			tech_info="$$tech_info""Rust-модуль $$version"; \
		else \
			tech_info="$$tech_info""Rust-модуль"; \
		fi; \
	fi; \
	\
	echo "$$tech_info"
endef
