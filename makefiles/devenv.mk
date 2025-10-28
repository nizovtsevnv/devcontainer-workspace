# ===================================
# Управление шаблоном DevContainer Workspace
# ===================================

.PHONY: devenv

# ===================================
# Вспомогательные функции
# ===================================


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
	@printf "$(COLOR_SECTION)▶ Инициализация проекта$(COLOR_RESET)\n"; \
	\
	if git remote get-url template >/dev/null 2>&1; then \
		$(call log-error,Проект уже инициализирован); \
		$(call log-info,Remote 'template' уже существует); \
		exit 1; \
	fi; \
	\
	printf "Шаблон будет переведён в режим проекта, это действие необратимо, продолжить? [y/N]: "; \
	read answer; \
	if [ "$$answer" != "y" ] && [ "$$answer" != "Y" ]; then \
		printf "$(COLOR_INFO)ℹ INFO:$(COLOR_RESET) Отменено\n"; \
		exit 1; \
	fi

	@# Проверка версии и автоматический checkout на последний тег
	@CURRENT_VERSION=$$(git describe --tags --exact-match HEAD 2>/dev/null); \
	if [ -z "$$CURRENT_VERSION" ]; then \
		$(call log-warning,HEAD не на tagged коммите); \
		LATEST_TAG=$$(git tag --list | sort -V | tail -1); \
		if [ -z "$$LATEST_TAG" ]; then \
			$(call log-error,Теги не найдены в репозитории); \
			$(call log-info,Убедитесь что вы клонировали репозиторий с тегами); \
			exit 1; \
		fi; \
		printf "  $(COLOR_INFO)ℹ$(COLOR_RESET) Автоматическое переключение на: $$LATEST_TAG\n"; \
		git checkout -q "$$LATEST_TAG"; \
		CURRENT_VERSION="$$LATEST_TAG"; \
	else \
		printf "  $(COLOR_INFO)ℹ$(COLOR_RESET) Текущая версия: $$CURRENT_VERSION\n"; \
	fi; \
	echo "$$CURRENT_VERSION" > .template-version; \
	printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Версия шаблона: $$CURRENT_VERSION\n"

	@# Удаление файлов шаблона
	@$(call log-info,Удаление файлов шаблона...)
	@for file in .github/ README.md README.project.md; do \
		if [ -e "$$file" ]; then \
			printf "  $(COLOR_WARNING)✗$(COLOR_RESET) $$file\n"; \
			rm -rf "$$file"; \
		fi; \
	done

	@# Пересоздание Git репозитория
	@$(call log-info,Инициализация Git репозитория...)
	@TEMPLATE_URL=$$(git remote get-url origin 2>/dev/null); \
	if [ -z "$$TEMPLATE_URL" ]; then \
		$(call log-error,Не удалось определить URL шаблона из origin); \
		$(call log-info,Убедитесь что вы клонировали шаблон через git clone); \
		exit 1; \
	fi; \
	printf "  $(COLOR_INFO)ℹ$(COLOR_RESET) Сохранён URL шаблона: $$TEMPLATE_URL\n"; \
	\
	rm -rf .git; \
	printf "  $(COLOR_WARNING)✗$(COLOR_RESET) Удалена история шаблона (.git/)\n"; \
	\
	git init -q; \
	printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Создан новый репозиторий\n"; \
	\
	git remote add template "$$TEMPLATE_URL"; \
	printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Добавлен remote 'template'\n"; \
	\
	git fetch template --tags >/dev/null 2>&1; \
	printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Получены теги из template\n"

	@# Интерактивный выбор нового origin
	@printf "\n$(COLOR_INFO)URL нового origin? [Enter для skip]:$(COLOR_RESET) "; \
	read NEW_ORIGIN; \
	if [ -n "$$NEW_ORIGIN" ]; then \
		git remote add origin "$$NEW_ORIGIN"; \
		printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Добавлен remote 'origin': $$NEW_ORIGIN\n"; \
	else \
		printf "  $(COLOR_INFO)ℹ$(COLOR_RESET) Remote 'origin' не настроен (можно добавить позже)\n"; \
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

	@# Initial commit
	@printf "\n$(COLOR_INFO)Создать initial commit? [Y/n]:$(COLOR_RESET) "; \
	read DO_COMMIT; \
	if [ "$$DO_COMMIT" != "n" ] && [ "$$DO_COMMIT" != "N" ]; then \
		git add . 2>/dev/null || true; \
		git commit -m "chore: initialize project from devcontainer-workspace template" 2>/dev/null || true; \
		printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) Initial commit создан\n"; \
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

	@# Определить текущую версию и статус
	@if git remote get-url template >/dev/null 2>&1; then \
		TEMPLATE_VERSION=$$(cat .template-version 2>/dev/null || echo "unknown"); \
		printf "  Версия шаблона:  $$TEMPLATE_VERSION\n"; \
		printf "  Статус:          $(COLOR_SUCCESS)инициализирован$(COLOR_RESET)\n"; \
	else \
		CURRENT_VERSION=$$(git describe --tags --exact-match HEAD 2>/dev/null || echo "unknown"); \
		printf "  Версия:          $$CURRENT_VERSION\n"; \
		printf "  Статус:          $(COLOR_WARNING)не инициализирован (выполните: make devenv init)$(COLOR_RESET)\n"; \
		printf "\n$(COLOR_INFO)Для проверки обновлений требуется инициализация$(COLOR_RESET)\n"; \
		exit 0; \
	fi

	@# Проверить актуальную версию
	@printf "\n$(COLOR_INFO)Проверка обновлений...$(COLOR_RESET)\n"
	@if ! git fetch template --tags >/dev/null 2>&1; then \
		$(call log-error,Не удалось fetch из template remote); \
		exit 1; \
	fi

	@# Получить последний tag и сравнить с текущей версией
	@LATEST_TAG=$$(git ls-remote --tags template 2>/dev/null | grep -v '\^{}' | awk '{print $$2}' | sed 's|refs/tags/||' | sort -V | tail -1); \
	TEMPLATE_VERSION=$$(cat .template-version 2>/dev/null || echo "unknown"); \
	\
	if [ -z "$$LATEST_TAG" ]; then \
		$(call log-warning,Теги не найдены в upstream); \
		printf "\n  Используйте: make devenv update для обновления до main\n"; \
	elif [ "$$TEMPLATE_VERSION" = "unknown" ]; then \
		printf "  $(COLOR_WARNING)Текущая версия неизвестна$(COLOR_RESET)\n"; \
		printf "  $(COLOR_INFO)Последняя версия template: $$LATEST_TAG$(COLOR_RESET)\n"; \
		printf "\n  Обновить: $(COLOR_SUCCESS)make devenv update$(COLOR_RESET)\n"; \
	elif [ "$$LATEST_TAG" = "$$TEMPLATE_VERSION" ]; then \
		printf "  $(COLOR_SUCCESS)✓ У вас актуальная версия$(COLOR_RESET)\n"; \
	else \
		printf "  $(COLOR_WARNING)Доступна новая версия: $$LATEST_TAG$(COLOR_RESET)\n"; \
		printf "\n$(COLOR_INFO)Changelog:$(COLOR_RESET)\n"; \
		git log --oneline --decorate "$$TEMPLATE_VERSION..template/main" 2>/dev/null || \
			printf "  (недоступно, используйте: git fetch template)\n"; \
		printf "\n  Обновить: $(COLOR_SUCCESS)make devenv update$(COLOR_RESET)\n"; \
	fi

# ===================================
# Команда: devenv update
# ===================================

.PHONY: devenv-update-internal

devenv-update-internal:
	@$(call log-section,Обновление из upstream)

	@# Проверить наличие remote 'template'
	@if ! git remote get-url template >/dev/null 2>&1; then \
		$(call log-error,Remote 'template' не найден); \
		$(call log-info,Добавьте его вручную: git remote add template <URL>); \
		exit 1; \
	fi

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

	@# Определить текущую и последнюю версии
	@CURRENT_VERSION=$$(cat .template-version 2>/dev/null || echo "unknown"); \
	LATEST_VERSION=$$(git tag --list | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | sort -V | tail -1); \
	printf "\nТекущая версия:  $$CURRENT_VERSION\n"; \
	printf "Последняя версия: $$LATEST_VERSION\n"

	@# Интерактивный выбор версии
	@LATEST_VERSION=$$(git tag --list | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | sort -V | tail -1); \
	CURRENT_VERSION=$$(cat .template-version 2>/dev/null || echo "unknown"); \
	printf "\n$(COLOR_INFO)Changelog ($$CURRENT_VERSION..$$LATEST_VERSION):$(COLOR_RESET)\n"; \
	git log --oneline --decorate "$$CURRENT_VERSION..$$LATEST_VERSION" 2>/dev/null || { \
		$(call log-warning,Changelog недоступен); \
	}; \
	\
	printf "\n$(COLOR_INFO)Выберите версию [$$LATEST_VERSION]:$(COLOR_RESET) "; \
	read TARGET_VERSION; \
	TARGET_VERSION=$${TARGET_VERSION:-$$LATEST_VERSION}; \
	\
	$(call log-info,Выполнение merge...); \
	if [ "$$TARGET_VERSION" = "main" ]; then \
		MERGE_REF="template/main"; \
	else \
		MERGE_REF="$$TARGET_VERSION"; \
	fi; \
	git merge --allow-unrelated-histories --no-commit --no-ff "$$MERGE_REF" 2>&1; \
	MERGE_STATUS=$$?; \
	\
	if [ $$MERGE_STATUS -eq 0 ]; then \
		printf "  $(COLOR_SUCCESS)✓ Merge выполнен успешно$(COLOR_RESET)\n"; \
	else \
		printf "  $(COLOR_INFO)ℹ$(COLOR_RESET) Обнаружены конфликты, автоматическое разрешение...\n"; \
	fi; \
	\
	CONFLICTS=$$(git diff --name-only --diff-filter=U 2>/dev/null); \
	if [ -n "$$CONFLICTS" ]; then \
		echo "$$CONFLICTS" | while read conflict_file; do \
			case "$$conflict_file" in \
				.template-version|Makefile|makefiles/*|.devcontainer/*) \
					git checkout --theirs "$$conflict_file" 2>/dev/null; \
					git add "$$conflict_file" 2>/dev/null; \
					printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) $$conflict_file (версия шаблона)\n"; \
					;; \
				doc/devenv/*) \
					git checkout --theirs "$$conflict_file" 2>/dev/null; \
					git add "$$conflict_file" 2>/dev/null; \
					printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) $$conflict_file (версия шаблона)\n"; \
					;; \
				README.project.md|.github/*) \
					git rm -f "$$conflict_file" 2>/dev/null || true; \
					printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) $$conflict_file (удалён)\n"; \
					;; \
				.gitignore|README.md|.editorconfig|doc/*|config/*) \
					git checkout --ours "$$conflict_file" 2>/dev/null; \
					git add "$$conflict_file" 2>/dev/null; \
					printf "  $(COLOR_SUCCESS)✓$(COLOR_RESET) $$conflict_file (версия проекта)\n"; \
					;; \
				*) \
					printf "  $(COLOR_WARNING)⚠$(COLOR_RESET)  $$conflict_file (требует ручного разрешения)\n"; \
					;; \
			esac; \
		done; \
		\
		UNRESOLVED=$$(git diff --name-only --diff-filter=U 2>/dev/null); \
		if [ -n "$$UNRESOLVED" ]; then \
			printf "\n$(COLOR_ERROR)✗ Нерешённые конфликты:$(COLOR_RESET)\n"; \
			echo "$$UNRESOLVED" | while read file; do \
				printf "  $(COLOR_WARNING)⚠$(COLOR_RESET)  $$file\n"; \
			done; \
			printf "\n$(COLOR_INFO)Разрешите конфликты и выполните:$(COLOR_RESET)\n"; \
			printf "  git add <файлы>\n"; \
			printf "  git commit\n"; \
			exit 1; \
		fi; \
	fi; \
	\
	if [ "$$TARGET_VERSION" != "main" ]; then \
		NEW_VERSION="$$TARGET_VERSION"; \
	else \
		NEW_VERSION=$$(git describe --tags template/main 2>/dev/null || echo "main"); \
	fi; \
	\
	echo "$$NEW_VERSION" > .template-version; \
	git add .template-version; \
	git commit -m "chore: update devenv template to $$NEW_VERSION" || true; \
	\
	printf "\n$(COLOR_SUCCESS)✓ Обновление завершено!$(COLOR_RESET)\n"; \
	printf "  Новая версия: $$NEW_VERSION\n"
