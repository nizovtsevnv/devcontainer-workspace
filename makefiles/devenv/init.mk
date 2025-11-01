# ===================================
# Команда: devenv init
# ===================================

.PHONY: devenv-init-internal
.ONESHELL:

devenv-init-internal:
	@set -e
	@$(call log-section,Инициализация проекта)

	@# Проверка что проект ещё не инициализирован
	@$(call check-project-init-status)
	@if [ "$$STATUS" = "инициализирован" ]; then \
		$(call log-error,Проект уже инициализирован); \
		$(call log-info,Remote 'template' уже существует); \
		exit 1; \
	fi

	@# ===========================================
	@# СЕКЦИЯ 1: Подготовка Git репозитория
	@# ===========================================
	@printf "\n"
	@$(call log-section,Подготовка Git репозитория)

	@# 1.1. Определение версии шаблона
	@CURRENT_VERSION=$$(git describe --tags 2>/dev/null || echo "unknown")
	@if [ "$$CURRENT_VERSION" = "unknown" ]; then \
		$(call log-error,Не удалось определить версию шаблона); \
		$(call log-info,Убедитесь что вы клонировали репозиторий с тегами: git clone --tags); \
		exit 1; \
	fi
	@$(call log-info,Версия шаблона: $$CURRENT_VERSION)
	@CURRENT_VERSION_CLEAN=$$(echo "$$CURRENT_VERSION" | sed 's/^v//' | cut -d'-' -f1)

	@# 1.2. Сохранение TEMPLATE_URL
	@TEMPLATE_URL=$$(git remote get-url origin 2>/dev/null)
	@if [ -z "$$TEMPLATE_URL" ]; then \
		$(call log-error,Не удалось определить URL шаблона из origin); \
		$(call log-info,Убедитесь что вы клонировали шаблон через git clone); \
		exit 1; \
	fi
	@$(call log-info,URL шаблона: $$TEMPLATE_URL)

	@# 1.3. Выбор режима инициализации
	@printf "\n"
	@INIT_MODE=$$(sh makefiles/scripts/select-menu.sh "Новый репозиторий (локально)" "Удалённый репозиторий" "Отмена") || exit 0
	@if [ "$$INIT_MODE" = "Отмена" ]; then \
		exit 0; \
	fi
	@printf "\n"

	@# 1.4 или 1.5 в зависимости от режима
	@if [ "$$INIT_MODE" = "Новый репозиторий (локально)" ]; then \
		rm -rf .git; \
		git init -q; \
		$(call log-success,Создан новый Git репозиторий); \
		ORIGIN_CONFIGURED=false; \
	else \
		printf "\n"; \
		ORIGIN_URL=$$($(call ask-input-with-default,,URL удалённого репозитория)) || exit 0; \
		if [ -z "$$ORIGIN_URL" ]; then \
			exit 0; \
		fi; \
		$(call log-spinner,Проверка доступности репозитория,$(call check-remote-accessible,$$ORIGIN_URL)) || exit 0; \
		$(call log-spinner,Клонирование репозитория,TEMP_DIR=$$($(call clone-to-temp,$$ORIGIN_URL))); \
		if [ -z "$$TEMP_DIR" ] || [ ! -d "$$TEMP_DIR" ]; then \
			$(call log-error,Не удалось клонировать репозиторий); \
			exit 0; \
		fi; \
		COMMIT_COUNT=$$($(call count-commits,$$TEMP_DIR)); \
		if [ "$$COMMIT_COUNT" -gt 0 ]; then \
			$(call log-info,В удалённом репозитории найдено $$COMMIT_COUNT коммитов); \
			printf "\n"; \
			if ! $(call ask-yes-no,Продолжить инициализацию нового проекта? (история коммитов будет сохранена)); then \
				rm -rf "$$TEMP_DIR"; \
				exit 0; \
			fi; \
			printf "\n"; \
		fi; \
		rm -rf .git; \
		mv "$$TEMP_DIR/.git" ./; \
		rm -rf "$$TEMP_DIR"; \
		$(call log-success,История Git перенесена из удалённого репозитория); \
		ORIGIN_CONFIGURED=true; \
	fi

	@# 1.6. Настройка template remote
	@$(call log-spinner,Настройка git remote template,git remote add template "$$TEMPLATE_URL" 2>/dev/null || true; git fetch template --tags --force 2>&1)

	@# 1.7. Обновление .gitignore
	@if grep -q "^modules/\*/" .gitignore 2>/dev/null; then \
		sed -i '/^# Modules (template development)/,/^modules\/\*\//d' .gitignore; \
		$(call log-success,Правило modules/*/ удалено из .gitignore); \
	fi
	@if grep -q "^\.template-version$$" .gitignore 2>/dev/null; then \
		sed -i '/^\.template-version$$/d' .gitignore; \
		$(call log-success,.template-version удалён из .gitignore); \
	fi

	@# ===========================================
	@# СЕКЦИЯ 2: Подготовка файлов проекта
	@# ===========================================
	@printf "\n"
	@$(call log-section,Подготовка файлов проекта)

	@# 2.1. Создание README.md
	@if [ -f "README.project.md" ]; then \
		cp README.project.md README.md; \
		$(call log-success,README.md создан из шаблона); \
	else \
		echo "# My Project" > README.md; \
		echo "" >> README.md; \
		echo "Проект создан из [DevContainer Workspace](https://github.com/nizovtsevnv/devcontainer-workspace)" >> README.md; \
		$(call log-success,README.md создан); \
	fi

	@# 2.2. Сохранение .template-version
	@echo "$$CURRENT_VERSION_CLEAN" > .template-version
	@git add -f .template-version 2>/dev/null || true
	@$(call log-success,Сохранена версия шаблона: $$CURRENT_VERSION_CLEAN)

	@# 2.3. Удаление артефактов
	@$(call remove-template-artifacts)

	@# ===========================================
	@# СЕКЦИЯ 3: Завершение инициализации
	@# ===========================================
	@printf "\n"
	@$(call log-section,Завершение инициализации)

	@# 3.1. git add -A
	@git add -A 2>/dev/null || true
	@$(call log-success,Файлы добавлены в git staging область)

	@# 3.2. git commit
	@if [ "$$INIT_MODE" = "Новый репозиторий (локально)" ]; then \
		COMMIT_MSG="chore: initialize project from devcontainer-workspace template"; \
	else \
		COMMIT_MSG="chore: reinitialize project from devcontainer-workspace template"; \
	fi
	@git commit -q -m "$$COMMIT_MSG" 2>/dev/null || true
	@printf "$(COLOR_SUCCESS)✓ %s$(COLOR_RESET)\n" "Создан коммит \"$$COMMIT_MSG\""

	@# 3.3. git push (только если origin настроен)
	@if [ "$$ORIGIN_CONFIGURED" = "true" ]; then \
		printf "\n"; \
		if $(call ask-yes-no,Отправить изменения в удалённый репозиторий?); then \
			CURRENT_BRANCH=$$(git branch --show-current); \
			git push -u origin "$$CURRENT_BRANCH" 2>&1 || { \
				$(call log-warning,Не удалось отправить изменения); \
				$(call log-info,Используйте: git push -u origin $$CURRENT_BRANCH); \
			}; \
			$(call log-success,Изменения отправлены в удалённый репозиторий); \
		else \
			$(call log-info,Push пропущен - можно выполнить позже вручную); \
		fi; \
	fi

	@# Финальное сообщение
	@printf "\n"
	@$(call log-success,Проект успешно инициализирован!)
	@printf "\n"
	@$(call log-info,Следующие шаги:)
	@printf "  1. Настройте README.md\n"
	@printf "  2. Добавьте модули в modules/\n"
	@printf "  3. Запустите: make up\n"
