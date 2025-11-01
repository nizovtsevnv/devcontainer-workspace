# DevContainer - Воспроизводимая среда разработки

Polyglot окружение разработки на основе **Debian 12 (Bookworm) LTS** со всеми необходимыми инструментами для работы с программными модулями проекта на разных технологических стеках.

## 🚀 Быстрый старт

### Открытие workspace в DevContainer

```bash
# Клонировать шаблонный репозиторий для начала работы над новым проектом
git clone --recurse-submodules git@github.com:nizovtsevnv/devcontainer-workspace.git
cd devcontainer-workspace

# Открыть в VS Code
code .
```

В VS Code:
1. Нажмите `F1` или `Ctrl+Shift+P`
2. Выберите `Dev Containers: Reopen in Container`
3. Дождитесь скачивания образа (~1-2 минуты при первом запуске)

### Проверка установленных инструментов

```bash
# После открытия в контейнере
node --version
npm --version
php --version
composer --version
rustc --version
cargo --version
git --version
make --version
docker --version
```

## 📦 Установленные компоненты

#### Node.js
- **Пакетные менеджеры:** npm, yarn, pnpm, bun
- **TypeScript:** typescript, ts-node
- **Инструменты качества:** eslint, prettier
- **Dev утилиты:** nodemon, pm2

#### PHP
- **Расширения:**
  - Основные: curl, mbstring, xml, zip
  - База данных: mysql, pgsql, sqlite3, redis
  - Прочие: bcmath, intl, gd, opcache, xdebug
- **Пакетный менеджер:** Composer
- **Инструменты:**
  - Тестирование: PHPUnit
  - Качество кода: PHP_CodeSniffer, PHPStan, PHP-CS-Fixer

#### Python
- **Пакетные менеджеры:** pip, poetry, pipenv, uv
- **Инструменты качества:** black, flake8, pylint, mypy
- **Тестирование:** pytest

#### Rust (nightly)
- **Компилятор:** rustc
- **Пакетный менеджер:** cargo
- **Компоненты:** rustfmt, clippy, rust-analyzer
- **Инструменты:** cargo-watch, cargo-edit, cargo-outdated

### Основные инструменты
- `git` - Система контроля версий
- `make` - Автоматизация сборки
- `build-essential` - Компиляторы (gcc, g++, etc)
- `curl`, `wget` - HTTP клиенты

### Docker
- `docker` - Docker CLI для работы с host Docker
- `docker-compose` - Оркестрация контейнеров

### Утилиты для работы с данными
- `jq` - Парсинг и обработка JSON
- `yq` - Парсинг и обработка YAML

### Файловые утилиты
- `tree` - Визуализация дерева каталогов
- `file` - Определение типа файла
- `zip`, `unzip` - Работа с архивами

### Редакторы
- `vim` - Текстовый редактор
- `nano` - Простой текстовый редактор

### Мониторинг
- `htop` - Интерактивный монитор процессов

### Сетевые утилиты
- `netcat` - Работа с TCP/UDP
- `ping` - Проверка доступности хостов
- `dig`, `nslookup` - DNS запросы
- `telnet` - Telnet клиент

## Работа с субмодулями

```bash
# Инициализация субмодулей
git submodule update --init --recursive

# Обновление субмодулей
git submodule update --remote --merge

# Статус субмодулей
git submodule foreach 'git status'
```

## Системные требования

### Container Runtime (один из вариантов)
- **Docker** + Docker Compose
- **Podman** + Podman Compose

### Прочие требования
- Git >= 2.40
- Make >= 4.0
- VS Code + расширение [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- Минимум 4GB RAM (рекомендуется 8GB)
- 10GB свободного места на диске

## Особенности при работе с Podman

**Podman** - это альтернатива Docker без демона, работающая в rootless режиме.

**Linux:**
```bash
# Включение Podman socket (эмуляция Docker API)
systemctl --user enable --now podman.socket

# Настроить переменную окружения указывающую на Podman socket для совместимости с Docker
export DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock
```

**macOS / Windows:**

В настройках включите Docker compatibility mode:
  - Settings → Connections → Enable Docker compatibility socket

### ⚠️ Проблема с правами файлов в VS Code DevContainers + Podman

При использовании VS Code DevContainers с Podman могут возникать проблемы с правами доступа к файлам, создаваемым внутри контейнера.

**Причина:**

Podman в rootless режиме использует user namespace mapping для изоляции:
- UID/GID хоста (например, 1000:100) маппятся в диапазон внутри контейнера
- По умолчанию UID 1000 на хосте → UID 0 (root) в контейнере
- VS Code DevContainers не учитывают эту особенность при создании контейнера
- Файлы, созданные в контейнере, получают неправильные права на хосте (например, 100999:100999 вместо 1000:100)

**Решение:**

Используйте команды `make up/down/sh/exec` вместо "Reopen in Container" в VS Code. Эти команды корректно настраивают user namespace mapping:

```bash
# Вместо VS Code "Reopen in Container":
make up      # Запуск контейнера с --userns=keep-id (Podman) или --user (Docker)
make sh      # Интерактивная оболочка в контейнере
make exec    # Выполнение команды в контейнере
make down    # Остановка контейнера

# Пример работы:
make up
make sh
# внутри контейнера: touch test.txt
# на хосте файл будет иметь правильные права: 1000:100
```

**Техническая деталь:**

Makefile автоматически использует правильные флаги для каждого container runtime:
- **Podman:** `--userns=keep-id` - сохраняет UID/GID между хостом и контейнером
- **Docker:** `--user $(id -u):$(id -g)` - явно задает UID/GID пользователя

Файл `docker-compose.yml` оставлен только для совместимости с VS Code, но команды `make` используют нативные docker/podman команды напрямую

## Устранение проблем

### Контейнер не собирается

```bash
# Очистка Docker кэша
docker system prune -a

# Пересборка без кэша
# В VS Code: F1 → Dev Containers: Rebuild Container (Without Cache)
```

### Медленная работа на macOS/Windows

Docker Desktop может работать медленно на macOS/Windows из-за виртуализации.

**Решения:**
- Увеличьте память для Docker Desktop (Settings → Resources)
- Используйте WSL2 на Windows
- Настройте исключения для антивируса

### Проблемы с правами доступа к файлам

```bash
# Проверьте UID на host машине
id -u

# Если не совпадает с 1000, обновите Dockerfile:
ARG CONTAINER_UID=<ваш UID>
```

### Docker socket недоступен

```bash
# Проверьте, что Docker socket примонтирован
ls -la /var/run/docker.sock

# Проверьте права доступа
docker ps
```

Если не работает:
- Убедитесь что Docker запущен на host
- Проверьте mount в `devcontainer.json`
- Пересоберите контейнер

## 📖 Дополнительная информация

- [VS Code DevContainers документация](https://code.visualstudio.com/docs/devcontainers/containers)
- [Debian официальный образ](https://hub.docker.com/_/debian)
- [DevContainers спецификация](https://containers.dev/)
