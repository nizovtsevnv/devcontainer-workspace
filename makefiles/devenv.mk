# ===================================
# Управление шаблоном DevContainer Workspace
# ===================================

.PHONY: devenv

# Файл с метаданными шаблона
TEMPLATE_VERSION_FILE := .template-version

# Загрузить переменные из .template-version
-include $(TEMPLATE_VERSION_FILE)

# ===================================
# Вспомогательные функции
# ===================================

# Прочитать переменную из .template-version
# $(1) - имя переменной
define read-template-var
$(shell grep "^$(1)=" $(TEMPLATE_VERSION_FILE) 2>/dev/null | cut -d'=' -f2-)
endef

# Обновить переменную в .template-version
# $(1) - имя переменной, $(2) - новое значение
define update-template-var
@sed -i 's|^$(1)=.*|$(1)=$(2)|g' $(TEMPLATE_VERSION_FILE)
endef

# Проверка: это режим разработки шаблона?
define check-template-dev-mode
$(shell ORIGIN_URL=$$(git remote get-url origin 2>/dev/null || echo ""); \
if echo "$$ORIGIN_URL" | grep -q "nizovtsevnv/devcontainer-workspace"; then \
	echo "true"; \
else \
	echo "false"; \
fi)
endef

# Проверка: инициализирован ли проект
define check-initialized
@if [ ! -f "$(TEMPLATE_VERSION_FILE)" ]; then \
	$(call log-error,Файл $(TEMPLATE_VERSION_FILE) не найден!); \
	$(call log-info,Возможно это не проект созданный из шаблона?); \
	exit 1; \
fi; \
INIT_DATE="$(call read-template-var,TEMPLATE_INITIALIZED)"; \
if [ -z "$$INIT_DATE" ]; then \
	$(call log-warning,Проект ещё не инициализирован из шаблона); \
	$(call log-info,Выполните: make devenv init); \
	exit 1; \
fi
endef

# Проверка: есть ли remote 'template'
define ensure-template-remote
@if ! git remote get-url template >/dev/null 2>&1; then \
	REMOTE_URL="$(call read-template-var,TEMPLATE_REMOTE)"; \
	if [ -z "$$REMOTE_URL" ]; then \
		$(call log-error,TEMPLATE_REMOTE не определён в $(TEMPLATE_VERSION_FILE)); \
		exit 1; \
	fi; \
	$(call log-info,Добавление remote 'template': $$REMOTE_URL); \
	git remote add template "$$REMOTE_URL"; \
fi
endef

# ===================================
# Диспетчер подкоманд devenv
# ===================================

# Получить подкоманду (первый аргумент после devenv)
DEVENV_CMD := $(word 2,$(MAKECMDGOALS))

## devenv: Команды управления шаблоном (init, version, update)
devenv:
	@if [ -z "$(DEVENV_CMD)" ]; then \
		$(call log-error,Укажите подкоманду: init, version, update); \
		$(call log-info,Примеры:); \
		printf "  make devenv init      - инициализация проекта из шаблона\n"; \
		printf "  make devenv version   - показать версию шаблона\n"; \
		printf "  make devenv update    - обновить из upstream\n"; \
		exit 1; \
	elif [ "$(DEVENV_CMD)" = "init" ]; then \
		$(MAKE) devenv-init-internal; \
		exit 0; \
	elif [ "$(DEVENV_CMD)" = "version" ]; then \
		$(MAKE) devenv-version-internal; \
		exit 0; \
	elif [ "$(DEVENV_CMD)" = "update" ]; then \
		$(MAKE) devenv-update-internal; \
		exit 0; \
	else \
		$(call log-error,Неизвестная подкоманда: $(DEVENV_CMD)); \
		$(call log-info,Доступны: init, version, update); \
		exit 1; \
	fi

# Роутинг version: может быть как `make version`, так и `make devenv version`
.PHONY: version
version:
	@if [ "$(word 1,$(MAKECMDGOALS))" = "devenv" ]; then \
		exit 0; \
	else \
		$(MAKE) -f $(firstword $(MAKEFILE_LIST)) core-version; \
	fi

# Stub targets для подавления ошибок Make при вызове `make devenv init/update`
.PHONY: init update
init update:
	@:

# ===================================
# Команда: devenv init
# ===================================

.PHONY: devenv-init-internal

devenv-init-internal:
	@$(call log-section,Инициализация проекта из шаблона)

	@# Проверка: режим разработки шаблона?
	@IS_DEV_MODE="$(call check-template-dev-mode)"; \
	if [ "$$IS_DEV_MODE" = "true" ]; then \
		$(call log-error,Инициализация невозможна в режиме разработки шаблона); \
		exit 1; \
	fi

	@# Проверка: уже инициализирован?
	@if [ -f "$(TEMPLATE_VERSION_FILE)" ]; then \
		INIT_DATE="$(call read-template-var,TEMPLATE_INITIALIZED)"; \
		if [ -n "$$INIT_DATE" ]; then \
			$(call log-error,Проект уже инициализирован ($$INIT_DATE)); \
			$(call log-info,Для обновления используйте: make devenv update); \
			exit 1; \
		fi; \
	fi

	@# Удаление файлов шаблона
	@if [ -f ".templateignore" ]; then \
		$(call log-info,Удаление файлов шаблона...); \
		while IFS= read -r line || [ -n "$$line" ]; do \
			[ -z "$$line" ] && continue; \
			[ "$${line:0:1}" = "#" ] && continue; \
			if [ -e "$$line" ]; then \
				printf "  $(COLOR_WARNING)✗$(COLOR_RESET) $$line\n"; \
				rm -rf "$$line"; \
			fi; \
		done < .templateignore; \
	fi

	@# Переименование remote
	@$(call log-info,Настройка Git remotes...)
	@if git remote get-url origin >/dev/null 2>&1; then \
		git remote rename origin template 2>/dev/null || true; \
		printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) origin → template\n"; \
	fi

	@# Интерактивный выбор нового origin
	@printf "\n$(COLOR_INFO)URL нового origin? [Enter для skip]:$(COLOR_RESET) "; \
	read NEW_ORIGIN; \
	if [ -n "$$NEW_ORIGIN" ]; then \
		git remote add origin "$$NEW_ORIGIN"; \
		printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Добавлен origin: $$NEW_ORIGIN\n"; \
	else \
		printf "  $(COLOR_WARNING)⊘$(COLOR_RESET) origin не настроен\n"; \
	fi

	@# Создание README проекта
	@printf "\n$(COLOR_INFO)Создать README.md проекта? [Y/n]:$(COLOR_RESET) "; \
	read CREATE_README; \
	if [ "$$CREATE_README" != "n" ] && [ "$$CREATE_README" != "N" ]; then \
		if [ -f "README.project.md" ]; then \
			cp README.project.md README.md; \
			printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) README.md создан из шаблона\n"; \
		else \
			echo "# My Project" > README.md; \
			echo "" >> README.md; \
			echo "Проект создан из [DevContainer Workspace](https://github.com/nizovtsevnv/devcontainer-workspace)" >> README.md; \
			printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) README.md создан\n"; \
		fi; \
	fi

	@# Обновление .gitignore для проекта
	@$(call log-info,Обновление .gitignore...)
	@if grep -q "^modules/\*/" .gitignore 2>/dev/null; then \
		sed -i '/^# Modules (template development)/,/^modules\/\*\//d' .gitignore; \
		printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Правило modules/*/ удалено из .gitignore\n"; \
	else \
		printf "  $(COLOR_WARNING)⊘$(COLOR_RESET) Правило modules/*/ не найдено в .gitignore\n"; \
	fi

	@# Обновление TEMPLATE_INITIALIZED
	@$(call log-info,Обновление метаданных...)
	@INIT_DATE=$$(date +%Y-%m-%d); \
	$(call update-template-var,TEMPLATE_INITIALIZED,$$INIT_DATE); \
	printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) TEMPLATE_INITIALIZED=$$INIT_DATE\n"

	@# Коммит изменений
	@printf "\n$(COLOR_INFO)Закоммитить изменения? [Y/n]:$(COLOR_RESET) "; \
	read DO_COMMIT; \
	if [ "$$DO_COMMIT" != "n" ] && [ "$$DO_COMMIT" != "N" ]; then \
		git add $(TEMPLATE_VERSION_FILE) README.md 2>/dev/null || true; \
		git commit -m "chore: initialize project from devcontainer-workspace template" 2>/dev/null || true; \
		printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Изменения закоммичены\n"; \
	fi

	@printf "\n$(COLOR_SUCCESS)✓ Проект успешно инициализирован!$(COLOR_RESET)\n"
	@printf "\n$(COLOR_INFO)Следующие шаги:$(COLOR_RESET)\n"
	@printf "  1. Настройте README.md\n"
	@printf "  2. Добавьте модули в modules/\n"
	@printf "  3. Запустите: make up\n"

# ===================================
# Команда: devenv version
# ===================================

.PHONY: devenv-version-internal

devenv-version-internal:
	@$(call log-section,Текущий статус шаблона разработки)

	@# Проверить наличие .template-version
	@if [ ! -f "$(TEMPLATE_VERSION_FILE)" ]; then \
		$(call log-error,Файл $(TEMPLATE_VERSION_FILE) не найден!); \
		$(call log-info,Возможно это не проект созданный из шаблона?); \
		exit 1; \
	fi

	@# Прочитать метаданные
	@CURRENT_VERSION="$(call read-template-var,TEMPLATE_VERSION)"; \
	INIT_DATE="$(call read-template-var,TEMPLATE_INITIALIZED)"; \
	\
	printf "  Версия:        $$CURRENT_VERSION\n"; \
	if [ -n "$$INIT_DATE" ]; then \
		printf "  Инициализация: $$INIT_DATE\n"; \
	else \
		printf "  Инициализация: $(COLOR_WARNING)не выполнена (выполнится автоматически при make up)$(COLOR_RESET)\n"; \
	fi

	@# Проверить актуальную версию
	@$(call ensure-template-remote)
	@printf "\n$(COLOR_INFO)Проверка обновлений...$(COLOR_RESET)\n"
	@if ! git fetch template --tags >/dev/null 2>&1; then \
		$(call log-error,Не удалось fetch из template remote); \
		exit 1; \
	fi

	@# Получить последний tag
	@LATEST_TAG=$$(git ls-remote --tags template 2>/dev/null | grep -v '\^{}' | awk '{print $$2}' | sed 's|refs/tags/||' | sort -V | tail -1); \
	CURRENT_VERSION="$(call read-template-var,TEMPLATE_VERSION)"; \
	\
	if [ -z "$$LATEST_TAG" ]; then \
		$(call log-warning,Теги не найдены в upstream); \
		printf "\n  Используйте: make devenv update для обновления до main\n"; \
	elif [ "$$LATEST_TAG" = "$$CURRENT_VERSION" ]; then \
		printf "  $(COLOR_SUCCESS)✓ У вас актуальная версия$(COLOR_RESET)\n"; \
	else \
		printf "  $(COLOR_WARNING)Доступна новая версия: $$LATEST_TAG$(COLOR_RESET)\n"; \
		printf "\n$(COLOR_INFO)Changelog:$(COLOR_RESET)\n"; \
		git log --oneline --decorate "$$CURRENT_VERSION..template/main" 2>/dev/null || \
			printf "  (недоступно, используйте: git fetch template)\n"; \
		printf "\n  Обновить: $(COLOR_SUCCESS)make devenv update$(COLOR_RESET)\n"; \
	fi

# ===================================
# Команда: devenv update
# ===================================

.PHONY: devenv-update-internal

devenv-update-internal:
	@$(call log-section,Обновление из upstream)

	@# Проверить наличие .template-version
	@if [ ! -f "$(TEMPLATE_VERSION_FILE)" ]; then \
		$(call log-error,Файл $(TEMPLATE_VERSION_FILE) не найден!); \
		$(call log-info,Возможно это не проект созданный из шаблона?); \
		exit 1; \
	fi

	@$(call ensure-template-remote)

	@# Проверка: есть uncommitted changes
	@if ! git diff-index --quiet HEAD -- 2>/dev/null; then \
		$(call log-error,Есть незакоммиченные изменения!); \
		$(call log-info,Закоммитьте или stash их перед обновлением); \
		git status --short; \
		exit 1; \
	fi

	@# Fetch обновлений
	@$(call log-info,Получение обновлений из template...)
	@git fetch template --tags

	@# Показать доступные версии
	@CURRENT_VERSION="$(call read-template-var,TEMPLATE_VERSION)"; \
	printf "\n$(COLOR_INFO)Доступные версии:$(COLOR_RESET)\n"; \
	git tag --list | sort -V | tail -5 | while read tag; do \
		if [ "$$tag" = "$$CURRENT_VERSION" ]; then \
			printf "  • $$tag $(COLOR_SUCCESS)(current)$(COLOR_RESET)\n"; \
		else \
			printf "  • $$tag\n"; \
		fi; \
	done; \
	printf "  • main $(COLOR_INFO)(latest)$(COLOR_RESET)\n"

	@# Интерактивный выбор версии
	@printf "\n$(COLOR_INFO)Выберите версию [main]:$(COLOR_RESET) "; \
	read TARGET_VERSION; \
	TARGET_VERSION=$${TARGET_VERSION:-main}; \
	\
	printf "\n$(COLOR_INFO)Changelog ($$CURRENT_VERSION..template/$$TARGET_VERSION):$(COLOR_RESET)\n"; \
	git log --oneline --decorate "$$CURRENT_VERSION..template/$$TARGET_VERSION" 2>/dev/null || { \
		$(call log-warning,Changelog недоступен); \
	}; \
	\
	printf "\n$(COLOR_WARNING)Применить обновления? [y/N]:$(COLOR_RESET) "; \
	read CONFIRM; \
	if [ "$$CONFIRM" != "y" ] && [ "$$CONFIRM" != "Y" ]; then \
		$(call log-info,Обновление отменено); \
		exit 0; \
	fi; \
	\
	$(call log-info,Выполнение merge...); \
	if git merge --no-commit --no-ff "template/$$TARGET_VERSION" 2>&1; then \
		printf "  $(COLOR_SUCCESS)✓ Merge выполнен успешно$(COLOR_RESET)\n"; \
		\
		if [ "$$TARGET_VERSION" != "main" ]; then \
			NEW_VERSION="$$TARGET_VERSION"; \
		else \
			NEW_VERSION=$$(git describe --tags template/main 2>/dev/null || echo "main"); \
		fi; \
		\
		$(call update-template-var,TEMPLATE_VERSION,$$NEW_VERSION); \
		git add $(TEMPLATE_VERSION_FILE); \
		git commit -m "chore: update devenv template to $$NEW_VERSION" || true; \
		\
		printf "\n$(COLOR_SUCCESS)✓ Обновление завершено!$(COLOR_RESET)\n"; \
		printf "  Новая версия: $$NEW_VERSION\n"; \
	else \
		printf "\n$(COLOR_ERROR)✗ Конфликты при merge!$(COLOR_RESET)\n"; \
		printf "\n$(COLOR_INFO)Файлы с конфликтами:$(COLOR_RESET)\n"; \
		git diff --name-only --diff-filter=U | while read file; do \
			printf "  $(COLOR_WARNING)⚠$(COLOR_RESET)  $$file\n"; \
		done; \
		printf "\n$(COLOR_INFO)Разрешите конфликты и выполните:$(COLOR_RESET)\n"; \
		printf "  git add <файлы>\n"; \
		printf "  git commit\n"; \
		exit 1; \
	fi
