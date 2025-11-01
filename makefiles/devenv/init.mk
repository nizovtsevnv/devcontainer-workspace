# ===================================
# Команда: devenv init
# ===================================

.PHONY: devenv-init-internal

devenv-init-internal:
	@export COLOR_SUCCESS="$(COLOR_SUCCESS)"; \
	export COLOR_ERROR="$(COLOR_ERROR)"; \
	export COLOR_INFO="$(COLOR_INFO)"; \
	export COLOR_WARNING="$(COLOR_WARNING)"; \
	export COLOR_SECTION="$(COLOR_SECTION)"; \
	export COLOR_RESET="$(COLOR_RESET)"; \
	export COLOR_DIM="$(COLOR_DIM)"; \
	export WORKSPACE_ROOT="$(WORKSPACE_ROOT)"; \
	sh makefiles/scripts/devenv-init.sh
