# ===================================
# Команда: devenv init
# ===================================

.PHONY: devenv-init-internal

devenv-init-internal:
	@$(call log-section,Инициализация проекта)
	@$(call check-project-init-status); \
	if [ "$$STATUS" = "инициализирован" ]; then \
		$(call log-error,Проект уже инициализирован); \
		$(call log-info,Remote 'template' уже существует); \
		exit 1; \
	fi
	@$(call ask-yes-no,Шаблон будет переведён в режим проекта - это действие необратимо - продолжить?) || { \
		$(call log-info,Инициализация отменена); \
		exit 0; \
	}

	@# Определение версии шаблона
	@CURRENT_VERSION=$$(git describe --tags 2>/dev/null || echo "unknown"); \
	if [ "$$CURRENT_VERSION" = "unknown" ]; then \
		$(call log-error,Не удалось определить версию шаблона); \
		$(call log-info,Убедитесь что вы клонировали репозиторий с тегами: git clone --tags); \
		exit 1; \
	fi; \
	$(call log-info,Версия шаблона: $$CURRENT_VERSION); \
	CURRENT_VERSION_CLEAN=$$(echo "$$CURRENT_VERSION" | sed 's/^v//' | cut -d'-' -f1); \
	$(call save-template-version,$$CURRENT_VERSION_CLEAN); \
	$(call log-success,Сохранена версия: $$CURRENT_VERSION_CLEAN)

	@# Удаление файлов шаблона
	@$(call log-info,Удаление файлов шаблона...)
	@$(call remove-template-artifacts)

	@# Пересоздание Git репозитория
	@$(call log-info,Инициализация Git репозитория...)
	@TEMPLATE_URL=$$(git remote get-url origin 2>/dev/null); \
	if [ -z "$$TEMPLATE_URL" ]; then \
		$(call log-error,Не удалось определить URL шаблона из origin); \
		$(call log-info,Убедитесь что вы клонировали шаблон через git clone); \
		exit 1; \
	fi; \
	rm -rf .git; \
	$(call log-warning,Удалена история шаблона (.git/)); \
	\
	git init -q; \
	$(call log-success,Создан новый репозиторий); \
	\
	git remote add template "$$TEMPLATE_URL"; \
	$(call log-success,Установлен git remote 'template'\: $$TEMPLATE_URL); \
	\
	git fetch template --tags --force >/dev/null 2>&1 || true; \
	$(call log-success,Получены теги из template)

	@# Интерактивный выбор нового origin
	@printf "\n"; \
	$(call ask-yes-no,Указать удалённый Git URL?) || { \
		$(call log-info,Remote 'origin' не настроен \(можно добавить позже\)); \
		exit 0; \
	}; \
	NEW_ORIGIN=$$($(call ask-input-with-default,,URL удалённого репозитория)); \
	if [ -n "$$NEW_ORIGIN" ]; then \
		git remote add origin "$$NEW_ORIGIN"; \
		$(call log-success,Установлен git remote 'origin'\: $$NEW_ORIGIN); \
	else \
		$(call log-info,Remote 'origin' не настроен \(можно добавить позже\)); \
	fi

	@# Создание README проекта
	@$(call create-project-readme)

	@# Обновление .gitignore для проекта
	@$(call log-info,Обновление .gitignore...)
	@if grep -q "^modules/\*/" .gitignore 2>/dev/null; then \
		sed -i '/^# Modules (template development)/,/^modules\/\*\//d' .gitignore; \
		$(call log-success,Правило modules/*/ удалено из .gitignore); \
	else \
		$(call log-warning,Правило modules/*/ не найдено в .gitignore); \
	fi
	@if grep -q "^\.template-version$$" .gitignore 2>/dev/null; then \
		sed -i '/^\.template-version$$/d' .gitignore; \
		$(call log-success,.template-version удалён из .gitignore \(будет отслеживаться в проекте\)); \
	else \
		$(call log-warning,.template-version не найден в .gitignore); \
	fi

	@# Initial commit
	@printf "\n"; \
	$(call ask-yes-no,Создать initial commit?) || { \
		$(call log-info,Initial commit пропущен - можно создать вручную); \
		exit 0; \
	}
	@git add . 2>/dev/null || true
	@git commit -m "chore: initialize project from devcontainer-workspace template" 2>/dev/null || true
	@$(call log-success,Initial commit создан)

	@printf "\n"
	@$(call log-success,Проект успешно инициализирован!)
	@printf "\n"
	@$(call log-info,Следующие шаги:)
	@printf "  1. Настройте README.md\n"
	@printf "  2. Добавьте модули в modules/\n"
	@printf "  3. Запустите: make up\n"
