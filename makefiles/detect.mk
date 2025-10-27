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

# Получить список всех доступных Node.js менеджеров в модуле
# Параметр: $(1) - путь к модулю
# Возвращает: список менеджеров с lock файлами + дефолтный
define get-nodejs-managers
$(strip \
	$(if $(wildcard $(1)/package-lock.json),npm) \
	$(if $(wildcard $(1)/yarn.lock),yarn) \
	$(if $(wildcard $(1)/pnpm-lock.yaml),pnpm) \
	$(if $(wildcard $(1)/bun.lockb),bun) \
	$(if $(and \
		$(if $(wildcard $(1)/package-lock.json),,1), \
		$(if $(wildcard $(1)/yarn.lock),,1), \
		$(if $(wildcard $(1)/pnpm-lock.yaml),,1), \
		$(if $(wildcard $(1)/bun.lockb),,1) \
	),bun) \
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

# Получить список всех доступных Python менеджеров в модуле
# Параметр: $(1) - путь к модулю
# Возвращает: список менеджеров с lock файлами + дефолтный
define get-python-managers
$(strip \
	$(if $(wildcard $(1)/requirements.txt),pip) \
	$(if $(wildcard $(1)/Pipfile),pipenv) \
	$(if $(wildcard $(1)/poetry.lock),poetry) \
	$(if $(wildcard $(1)/uv.lock),uv) \
	$(if $(and \
		$(if $(wildcard $(1)/requirements.txt),,1), \
		$(if $(wildcard $(1)/Pipfile),,1), \
		$(if $(wildcard $(1)/poetry.lock),,1), \
		$(if $(wildcard $(1)/uv.lock),,1) \
	),uv) \
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

# Получить список PHP менеджеров (всегда composer)
# Параметр: $(1) - путь к модулю
# Возвращает: composer
define get-php-managers
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

# Получить список Rust менеджеров (всегда cargo)
# Параметр: $(1) - путь к модулю
# Возвращает: cargo
define get-rust-managers
cargo
endef

# ===================================
# Вспомогательные функции
# ===================================

# Проверить, содержит ли список технологий указанную технологию
# Параметр: $(1) - список технологий, $(2) - искомая технология
# Возвращает: непустая строка если найдено
define has-tech
$(filter $(2),$(1))
endef

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
