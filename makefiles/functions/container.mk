# ===================================
# Функции управления контейнером
# ===================================

# Умный запуск контейнерной среды (с gum spin если доступен на хосте)
# Использование: @$(call ensure-devenv-ready)
define ensure-devenv-ready
	if [ "$(IS_INSIDE_CONTAINER)" = "0" ]; then \
		: ; \
	elif $(CONTAINER_RUNTIME) ps --format "{{.Names}}" 2>/dev/null | grep -q "^$(CONTAINER_NAME)$$"; then \
		: ; \
	else \
		$(call log-spinner,Запуск контейнера ($(CONTAINER_NAME)),$(MAKE) --no-print-directory up-silent); \
	fi
endef

# Остановить контейнер если запущен
# Использование: @$(call stop-container-if-running)
define stop-container-if-running
	if $(CONTAINER_RUNTIME) ps --format "{{.Names}}" 2>/dev/null | grep -q "^$(CONTAINER_NAME)$$"; then \
		$(CONTAINER_RUNTIME) stop $(CONTAINER_NAME) >/dev/null 2>&1; \
		$(CONTAINER_RUNTIME) rm $(CONTAINER_NAME) >/dev/null 2>&1; \
	fi
endef

# Обновить Docker образ и пересоздать контейнер
# Использование: @$(call update-container-image)
define update-container-image
	printf "\n"; \
	$(call log-spinner,Обновление Docker образа и пересоздание контейнера,sh -c '$(CONTAINER_RUNTIME) pull $(CONTAINER_IMAGE) >/dev/null 2>&1 && $(MAKE) --no-print-directory up-silent'); \
	$(call log-success,Контейнер обновлен)
endef
