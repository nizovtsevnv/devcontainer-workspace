# DevContainer Workspace Template

Шаблон рабочего пространства для разработки проектов с воспроизводимой средой разработки (Node.js + PHP + Rust).

## 🚀 Быстрый старт

### 1. Скачать шаблон

```bash
# Клонировать шаблон
git clone https://github.com/nizovtsevnv/devcontainer-workspace.git my-project
cd my-project

# Удалить связь с шаблоном
rm -rf .git

# Инициализировать новый Git репозиторий для вашего проекта
git init
git add .
git commit -m "Initial commit from devcontainer-workspace template"
```

### 2. Открыть в DevContainer

```bash
# Открыть в VS Code
code .
```

В VS Code:
1. Нажмите `F1` или `Ctrl+Shift+P`
2. Выберите `Dev Containers: Reopen in Container`
3. Дождитесь скачивания образа (~1-2 минуты)

**Готово!** Вы находитесь в полностью настроенной среде разработки.

### 3. Добавить субмодули проекта

```bash
# Добавить субмодуль (сервис, приложение, библиотеку)
git submodule add git@github.com:user/service-name.git modules/service-name

# Инициализировать субмодули
git submodule update --init --recursive
```

### 4. Разработка

Используйте воспроизводимую среду для:
- Разработки кода в субмодулях
- Написания документации в `doc/` и `README.md`
- Автоматизации через `make` (добавьте `Makefile` и `makefiles/*.mk`)

### 5. Публикация проекта

```bash
# Настроить удаленный репозиторий для вашего проекта
git remote add origin git@github.com:your-org/your-project.git

# Отправить в ваш репозиторий
git push -u origin main
```

---

## 📦 Что включено

### Технологические стеки
- **Node.js 22** - npm, yarn, pnpm, typescript, eslint, prettier, vite, nestjs
- **PHP 8.3** - Composer, php-cs-fixer, phpcs, phpstan (инструменты качества кода)
- **Rust nightly** - cargo, rustfmt, clippy, rust-analyzer

### Системные утилиты
- Git, Make, Docker CLI, Docker Compose
- curl, wget, jq, yq
- tree, vim, nano, htop
- Сетевые утилиты (netcat, ping, dig, telnet)

### DevContainer возможности
- ✅ Совместимость с Docker и Podman
- ✅ Работает на Linux, macOS, Windows
- ✅ Пользователь `developer` с sudo
- ✅ Проброс Docker socket для работы с контейнерами
- ✅ Готовые настройки VS Code и расширения

---

## 📂 Структура проекта

```
my-project/
├── .devcontainer/          # DevContainer конфигурация
├── .github/workflows/      # GitHub Actions (опционально)
├── config/                 # Конфигурации стандартов качества
├── doc/                    # Документация проекта
├── modules/                # Git субмодули (ваши компоненты)
├── makefiles/              # Make автоматизация (создайте при необходимости)
└── Makefile                # Главный makefile (создайте при необходимости)
```

---

## 📚 Документация

- [doc/devcontainer.md](doc/devcontainer.md) - Руководство по работе с DevContainer
- [doc/file-tree.md](doc/file-tree.md) - Описание файловой структуры

---

## 🔧 Кастомизация

### Изменить версии инструментов

Если нужны другие версии Node.js, PHP или дополнительные пакеты:

1. Раскомментируйте `build` секцию в `.devcontainer/devcontainer.json`
2. Закомментируйте `image` строку
3. Отредактируйте `.devcontainer/Dockerfile`
4. Пересоберите: `F1` → `Dev Containers: Rebuild Container`

### Использовать конкретную версию образа

Вместо `latest` укажите конкретную версию в `.devcontainer/devcontainer.json`:

```json
{
  "image": "ghcr.io/nizovtsevnv/devcontainer-workspace:1.0.0"
}
```

---

## ⚙️ Системные требования

- **Docker** или **Podman** + Compose
- **Git** >= 2.40
- **Make** >= 4.0 (опционально, для автоматизации)
- **VS Code** + расширение [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- Минимум **4GB RAM** (рекомендуется 8GB)
- **10GB** свободного места на диске

---

## 🐳 Docker vs Podman

Шаблон работает с обоими container runtime:

**Docker (рекомендуется):**
```bash
# Linux
sudo apt-get install docker.io docker-compose

# macOS / Windows
# Установите Docker Desktop
```

**Podman (альтернатива):**
```bash
# Linux
sudo apt-get install podman podman-compose
systemctl --user enable --now podman.socket
```

Подробнее: [doc/devcontainer.md](doc/devcontainer.md)

---

## 💡 Типичный workflow разработчика

1. **Скачать шаблон** → клонировать репозиторий
2. **Открыть в DevContainer** → автоматически скачается готовый образ
3. **Добавить субмодули** → ваши сервисы, приложения, библиотеки
4. **Разработка** → код, документация, автоматизация
5. **Коммиты** → работа с Git как обычно
6. **Push** → отправить в ваш репозиторий проекта

---

## 🔄 Обновление среды

Когда выходят обновления шаблона:

```bash
# Скачать новую версию образа
docker pull ghcr.io/nizovtsevnv/devcontainer-workspace:latest

# Пересоздать контейнер
# В VS Code: F1 → Dev Containers: Rebuild Container
```

---

## 🐛 Устранение проблем

### Образ не скачивается

Образ публичный, но если возникают проблемы:

```bash
# Попробуйте вручную
docker pull ghcr.io/nizovtsevnv/devcontainer-workspace:latest

# Проверьте подключение к GitHub
curl -I https://ghcr.io
```

### Медленная работа

- Увеличьте память Docker/Podman (Settings → Resources)
- На Windows используйте WSL2
- Настройте исключения антивируса для Docker

### Нет прав на Docker socket

```bash
# Linux - добавить пользователя в группу docker
sudo usermod -aG docker $USER
# Перелогиньтесь

# Или используйте Podman
```

Больше решений: [doc/devcontainer.md](doc/devcontainer.md)

---

## 📋 Примеры использования

### Добавление Makefile автоматизации

Создайте `Makefile` в корне:

```makefile
.PHONY: help

help:
	@echo "Доступные команды:"
	@echo "  make install    - Установить зависимости всех субмодулей"
	@echo "  make test       - Запустить тесты"
	@echo "  make build      - Собрать все компоненты"

install:
	@git submodule foreach 'npm install || composer install || cargo build'

test:
	@git submodule foreach 'npm test || vendor/bin/phpunit || cargo test'
```

### Работа с субмодулями

```bash
# Обновить все субмодули до последних версий
git submodule update --remote --merge

# Проверить статус всех субмодулей
git submodule foreach 'git status'

# Переключить субмодуль на другую ветку
cd modules/my-service
git checkout develop
```

---

## 🤝 Вклад в шаблон

Если вы хотите улучшить сам шаблон:

1. Fork репозитория
2. Создайте feature branch
3. Внесите изменения
4. Создайте Pull Request

---

## 📄 Лицензия

Этот шаблон распространяется свободно. Используйте в своих проектах без ограничений.

---

## 🔗 Ссылки

- [Репозиторий шаблона](https://github.com/nizovtsevnv/devcontainer-workspace)
- [Docker образ](https://github.com/nizovtsevnv/devcontainer-workspace/pkgs/container/devcontainer-workspace)
- [VS Code DevContainers](https://code.visualstudio.com/docs/devcontainers/containers)
- [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules)

---

**Вопросы?** Создайте [Issue](https://github.com/nizovtsevnv/devcontainer-workspace/issues) в репозитории шаблона.
