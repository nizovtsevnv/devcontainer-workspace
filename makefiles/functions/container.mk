# ===================================
# Функции управления контейнером
# ===================================

# Проверка и скачивание образа контейнера с показом прогресса
# Использование: @$(call ensure-image-available)
define ensure-image-available
	if ! $(CONTAINER_RUNTIME) images --format "{{.Repository}}:{{.Tag}}" | grep -q "^$(CONTAINER_IMAGE)$$"; then \
		$(call log-info,Скачивание образа $(CONTAINER_IMAGE)...); \
		printf "\n"; \
		if $(CONTAINER_RUNTIME) pull $(CONTAINER_IMAGE); then \
			printf "\n"; \
			$(call log-success,Образ готов); \
		else \
			printf "\n"; \
			$(call log-error,Не удалось скачать образ); \
			exit 1; \
		fi; \
	fi
endef

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
	$(call log-info,Обновление Docker образа...); \
	printf "\n"; \
	if $(CONTAINER_RUNTIME) pull $(CONTAINER_IMAGE); then \
		printf "\n"; \
		$(call log-spinner,Пересоздание контейнера,sh -c '$(call stop-container-if-running) && $(MAKE) --no-print-directory up-silent'); \
		$(call log-success,Контейнер обновлен); \
	else \
		printf "\n"; \
		$(call log-error,Не удалось обновить образ); \
		exit 1; \
	fi
endef
