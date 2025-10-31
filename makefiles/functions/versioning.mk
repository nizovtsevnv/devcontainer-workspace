# ===================================
# Функции работы с версиями и git
# ===================================

# Определить версию шаблона (без префикса v)
# В неинициализированном шаблоне: из git тега
# В инициализированном проекте: из .template-version
# Использование: $(call get-template-version)
define get-template-version
$(shell \
	if [ -f .template-version ]; then \
		cat .template-version 2>/dev/null | sed 's/^v//' || echo "unknown"; \
	else \
		git describe --tags --exact-match HEAD 2>/dev/null | sed 's/^v//' || \
		git describe --tags 2>/dev/null | sed 's/^v//' || \
		echo "unknown"; \
	fi \
)
endef

# Получить последний семантический тег (vX.Y.Z)
# Использование: LATEST_TAG=$$($(call get-latest-semantic-tag))
define get-latest-semantic-tag
git tag --list | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | sort -V | tail -1
endef

# Получить все семантические теги (vX.Y.Z)
# Использование: ALL_TAGS=$(call get-all-semantic-tags)
define get-all-semantic-tags
$(shell git tag --list | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | sort -V)
endef

# Форматировать список версий для вывода (убрать v, через запятую)
# Параметр: $(1) - список тегов
# Использование: FORMATTED=$(call format-versions-list,$(TAGS))
define format-versions-list
$(shell echo "$(1)" | sed 's/^v//g' | tr '\n' ',' | sed 's/,$$//')
endef

# Сохранить версию шаблона в .template-version и добавить в git
# Параметр: $(1) - версия (без префикса v)
# Использование: @$(call save-template-version,1.0.0)
define save-template-version
	echo "$(1)" > .template-version; \
	git add .template-version
endef

# Показать changelog между двумя версиями
# Параметр: $(1) - from version (с или без v), $(2) - to ref (tag/branch)
# Использование: @$(call show-changelog,v1.0.0,origin/main)
define show-changelog
	FROM_VER="$(1)"; \
	if ! echo "$$FROM_VER" | grep -q '^v'; then \
		FROM_VER="v$$FROM_VER"; \
	fi; \
	git log --oneline --decorate "$$FROM_VER..$(2)" 2>/dev/null || \
		printf "  (changelog недоступен)\n"
endef

# Проверить наличие uncommitted изменений
# Использование: @$(call require-clean-working-tree)
define require-clean-working-tree
	if ! git diff-index --quiet HEAD -- 2>/dev/null; then \
		$(call log-error,Есть незакоммиченные изменения!); \
		$(call log-info,Закоммитьте или stash их перед обновлением); \
		git status --short; \
		exit 1; \
	fi
endef
