#!/bin/bash
set -e

# Entrypoint для автоматической настройки прав доступа
# Изменяет GID пользователя чтобы совпадал с GID /workspace на хосте

WORKSPACE_DIR="/workspace"
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

# Получить владельца /workspace
if [ -d "$WORKSPACE_DIR" ]; then
    WORKSPACE_UID=$(stat -c '%u' "$WORKSPACE_DIR" 2>/dev/null || echo "$CURRENT_UID")
    WORKSPACE_GID=$(stat -c '%g' "$WORKSPACE_DIR" 2>/dev/null || echo "$CURRENT_GID")

    # Если GID пользователя не совпадает с GID /workspace
    # Не пытаемся изменить GID на 0 (root) - это запрещено и не нужно
    if [ "$CURRENT_GID" != "$WORKSPACE_GID" ] && [ "$WORKSPACE_GID" != "0" ]; then
        echo "⚙️  Настройка GID пользователя: ${CURRENT_GID} → ${WORKSPACE_GID}"

        # Изменить GID пользователя и перезапустить с правильной группой
        if command -v sudo >/dev/null 2>&1 && [ "$CURRENT_UID" != "0" ]; then
            # Создать/обновить группу с нужным GID
            GROUPNAME="workspace_gid_${WORKSPACE_GID}"
            if ! getent group "$WORKSPACE_GID" >/dev/null 2>&1; then
                sudo groupadd -f -g "$WORKSPACE_GID" "$GROUPNAME" 2>/dev/null || true
            fi

            # Изменить основную группу пользователя
            sudo usermod -g "$WORKSPACE_GID" "$(whoami)" 2>/dev/null || true

            # Перезапустить команду с новой группой
            exec sudo -u "$(whoami)" -g "$WORKSPACE_GID" -- "$@"
        fi
    fi

    # Если UID не совпадает, попробовать изменить владельца
    if [ "$CURRENT_UID" != "$WORKSPACE_UID" ] && [ "$WORKSPACE_UID" = "0" ]; then
        echo "⚙️  Изменение владельца /workspace: root → $(whoami)"
        sudo chown -R "${CURRENT_UID}:${WORKSPACE_GID}" "$WORKSPACE_DIR" 2>/dev/null || true
    fi
fi

# Запустить переданную команду
exec "$@"
