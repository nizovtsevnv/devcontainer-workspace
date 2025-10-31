# ===================================
# Команда: devenv update
# ===================================

.PHONY: devenv-update-internal devenv-update-project devenv-update-template

devenv-update-internal:
	@$(call log-section,Обновление версии шаблона)

	@# Определить статус инициализации
	@$(call check-project-init-status); \
	if [ "$$STATUS" = "инициализирован" ]; then \
		$(MAKE) devenv-update-project; \
	else \
		$(MAKE) devenv-update-template; \
	fi

# Обновление инициализированного проекта (через merge с template)
devenv-update-project:
	@# Проверка: есть uncommitted changes
	@$(call require-clean-working-tree)

	@# Остановить контейнер если запущен (чтобы не работал на старой версии)
	@$(call stop-container-if-running)

	@# Fetch обновлений
	@git fetch template --tags --force >/dev/null 2>&1 || true

	@# Определить текущую и последнюю версии
	@CURRENT_VERSION=$(call get-template-version); \
	LATEST_VERSION=$$($(call get-latest-semantic-tag)); \
	LATEST_VERSION_CLEAN=$$(echo "$$LATEST_VERSION" | sed 's/^v//'); \
	$(call log-success,Режим: инициализированный проект); \
	printf "Текущая версия шаблона:    $$CURRENT_VERSION\n"; \
	printf "Последняя версия шаблона:  $$LATEST_VERSION_CLEAN\n"

	@# Интерактивный выбор версии
	@LATEST_VERSION=$$($(call get-latest-semantic-tag)); \
	LATEST_VERSION_CLEAN=$$(echo "$$LATEST_VERSION" | sed 's/^v//'); \
	CURRENT_VERSION=$(call get-template-version); \
	printf "\n"; \
	$(call log-info,Изменения \($$CURRENT_VERSION..$$LATEST_VERSION_CLEAN\):); \
	$(call show-changelog,$$CURRENT_VERSION,$$LATEST_VERSION); \
	printf "\n"; \
	\
	ALL_TAGS=$$($(call get-all-semantic-tags)); \
	VERSION_OPTIONS=$$(echo "$$ALL_TAGS" | sed 's/^v//g' | tac | tr '\n' ' '); \
	if command -v gum >/dev/null 2>&1; then \
		SELECTED=$$(echo "$$VERSION_OPTIONS" | tr ' ' '\n' | gum choose --header "Выберите версию для обновления:" --selected="$$LATEST_VERSION_CLEAN"); \
		TARGET_VERSION="$$SELECTED"; \
	else \
		TARGET_VERSION=$$($(call ask-input-with-default,$$LATEST_VERSION_CLEAN,Выберите версию)); \
	fi; \
	\
	HAS_PROJECT_GITHUB="no"; \
	if [ -d .github ]; then \
		HAS_PROJECT_GITHUB="yes"; \
	fi; \
	\
	if [ "$$TARGET_VERSION" = "main" ]; then \
		MERGE_REF="template/main"; \
	else \
		MERGE_REF="v$$TARGET_VERSION"; \
	fi; \
	git merge --allow-unrelated-histories --no-commit --no-ff "$$MERGE_REF" >/dev/null 2>&1; \
	MERGE_STATUS=$$?; \
	\
	$(call auto-resolve-template-conflicts); \
	\
	UNRESOLVED=$$(git diff --name-only --diff-filter=U 2>/dev/null); \
	if [ -n "$$UNRESOLVED" ]; then \
		printf "\n"; \
		$(call log-error,Нерешённые конфликты:); \
		echo "$$UNRESOLVED" | while read file; do \
			$(call log-warning,$$file); \
		done; \
		printf "\n"; \
		$(call log-info,Разрешите конфликты и выполните:); \
		printf "  git add <файлы>\n"; \
		printf "  git commit\n"; \
		exit 1; \
	fi; \
	\
	$(call remove-template-artifacts); \
	\
	if [ "$$TARGET_VERSION" != "main" ]; then \
		NEW_VERSION="$$TARGET_VERSION"; \
	else \
		NEW_VERSION=$$(git describe --tags template/main 2>/dev/null | sed 's/^v//' || echo "main"); \
	fi; \
	\
	$(call save-template-version,$$NEW_VERSION); \
	\
	printf "\n"; \
	$(call log-info,Изменения подготовлены к коммиту:); \
	git diff --cached --stat --color=always; \
	printf "\n"; \
	\
	if $(call ask-confirm,Создать коммит обновления шаблона); then \
		DEFAULT_MSG="chore: update devenv template to $$NEW_VERSION"; \
		if command -v gum >/dev/null 2>&1; then \
			COMMIT_MSG=$$(gum input --value "$$DEFAULT_MSG" --prompt "Сообщение коммита: " --width=80); \
		else \
			COMMIT_MSG=$$($(call ask-input-with-default,$$DEFAULT_MSG,Сообщение коммита)); \
		fi; \
		if [ -n "$$COMMIT_MSG" ]; then \
			git commit -m "$$COMMIT_MSG" >/dev/null 2>&1; \
			printf "\n"; \
			$(call log-success,Обновление завершено!); \
			printf "  Новая версия: $$NEW_VERSION\n"; \
			printf "  Коммит создан\n"; \
		else \
			$(call log-warning,Пустое сообщение\, коммит пропущен); \
			printf "  Изменения staged\, выполните 'git commit' вручную\n"; \
		fi; \
	else \
		printf "\n"; \
		$(call log-info,Обновление завершено без коммита); \
		printf "  Новая версия: $$NEW_VERSION\n"; \
		printf "  Изменения staged\, выполните 'git commit' когда будете готовы\n"; \
	fi

	@# Обновить Docker образ и пересоздать контейнер
	@$(call update-container-image)

# Обновление неинициализированного шаблона (простой pull)
devenv-update-template:
	@$(call log-info,Режим: неинициализированный шаблон)

	@# Проверка: есть uncommitted changes
	@$(call require-clean-working-tree)

	@# Остановить контейнер если запущен (чтобы не работал на старой версии)
	@$(call stop-container-if-running)

	@# Определить текущую ветку
	@CURRENT_BRANCH=$$(git branch --show-current); \
	$(call log-info,Обновление ветки: $$CURRENT_BRANCH)

	@# Pull изменений
	@if git pull 2>&1; then \
		$(call log-success,Изменения получены); \
	else \
		$(call log-error,Не удалось выполнить git pull); \
		exit 1; \
	fi

	@# Определить версию шаблона через git
	@TEMPLATE_VERSION=$$(git describe --tags 2>/dev/null | sed 's/^v//' || echo "unknown"); \
	printf "\n"; \
	$(call log-success,Обновление завершено!); \
	printf "  Версия шаблона: $$TEMPLATE_VERSION\n"

	@# Обновить Docker образ и пересоздать контейнер
	@$(call update-container-image)
