# ===================================
# Команда: devenv status
# ===================================

.PHONY: devenv-status-internal

devenv-status-internal:
	@$(call log-info,Текущий статус шаблона разработки:)

	@# Определить текущую версию и статус
	@$(call check-project-init-status); \
	if [ "$$STATUS" = "инициализирован" ]; then \
		REMOTE="template"; \
	else \
		REMOTE="origin"; \
	fi; \
	\
	CURRENT_VERSION="$(call get-template-version)"; \
	if [ "$$STATUS" = "инициализирован" ]; then \
		printf '%s\n' "Версия шаблона<COL>$$CURRENT_VERSION<ROW>Статус<COL>инициализирован" | { $(call print-table,16); }; \
	else \
		printf '%s\n' "Версия шаблона<COL>$$CURRENT_VERSION<ROW>Статус<COL>неинициализирован (разработка шаблона)" | { $(call print-table,16); }; \
	fi; \
	\
	printf '\n'; \
	if ! $(call log-spinner,Проверка обновлений из $$REMOTE,git fetch $$REMOTE --tags >/dev/null 2>&1); then \
		$(call log-error,Не удалось fetch из $$REMOTE remote); \
		exit 1; \
	fi; \
	\
	LATEST_TAG=$$(git ls-remote --tags $$REMOTE 2>/dev/null | grep -v '\^{}' | awk '{print $$2}' | sed 's|refs/tags/||' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | sort -V | tail -1); \
	LATEST_TAG_CLEAN=$$(echo "$$LATEST_TAG" | sed 's/^v//'); \
	if [ -f .template-version ] || git describe --tags --exact-match HEAD >/dev/null 2>&1; then \
		VERSION_SUFFIX=""; \
	else \
		VERSION_SUFFIX=" (модифицированный)"; \
	fi; \
	\
	if [ -z "$$LATEST_TAG" ]; then \
		$(call log-warning,Теги не найдены в upstream); \
		printf "\n  Используйте: make devenv update для обновления\n"; \
	elif [ "$$CURRENT_VERSION" = "unknown" ]; then \
		$(call log-warning,Текущая версия неизвестна); \
		$(call log-info,Последняя версия: $$LATEST_TAG_CLEAN); \
		printf "\n  Обновить: "; \
		$(call log-success,make devenv update); \
		printf "\n"; \
	elif [ "$$LATEST_TAG_CLEAN" = "$$CURRENT_VERSION" ]; then \
		if [ -n "$$VERSION_SUFFIX" ]; then \
			$(call log-info,У вас актуальная версия$$VERSION_SUFFIX); \
		else \
			$(call log-success,У вас актуальная версия); \
		fi; \
	else \
		$(call log-warning,Доступна новая версия: $$LATEST_TAG_CLEAN); \
		printf "\n"; \
		$(call log-info,Changelog:); \
		$(call show-changelog,$$CURRENT_VERSION,$$REMOTE/main); \
		printf "\n  Обновить: "; \
		$(call log-success,make devenv update); \
		printf "\n"; \
	fi
