# ===================================
# Базовые команды управления средой
# ===================================

.PHONY: up down sh exec exec-interactive

## up: Запуск DevContainer
up:
	@$(call run-script,makefiles/scripts/container-up.sh)

## down: Остановка DevContainer
down:
	@$(call run-script,makefiles/scripts/container-down.sh)

## sh: Интерактивный shell в DevContainer
sh:
	@$(call run-script,makefiles/scripts/container-sh.sh)

## exec: Выполнение команды в DevContainer
## Использование:
##   make exec 'команда с && и другими операторами'
##   CMD='команда' make exec
exec:
	@CMD_VALUE='$(CMD)'; \
	if [ -z "$$CMD_VALUE" ]; then \
		CMD_VALUE="$(filter-out exec,$(MAKECMDGOALS))"; \
	fi; \
	export CMD="$$CMD_VALUE"; \
	$(call run-script,makefiles/scripts/container-exec.sh)

## exec-interactive: Выполнение интерактивной команды в DevContainer (с TTY)
## Использование:
##   make exec-interactive 'команда'
##   CMD='команда' make exec-interactive
exec-interactive:
	@CMD_VALUE='$(CMD)'; \
	if [ -z "$$CMD_VALUE" ]; then \
		CMD_VALUE="$(filter-out exec-interactive,$(MAKECMDGOALS))"; \
	fi; \
	export CMD="$$CMD_VALUE"; \
	$(call run-script,makefiles/scripts/container-exec.sh,-it)

## version: Вывод версий инструментов DevContainer и модулей
.PHONY: version
version:
	@export CMD="sh makefiles/scripts/version.sh"; \
	$(call run-script,makefiles/scripts/container-exec.sh)

# Подавление ошибок для аргументов после exec
%:
	@:
