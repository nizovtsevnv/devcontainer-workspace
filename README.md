# DevContainer Workspace Template

Шаблон рабочего пространства для разработки проектов с воспроизводимой средой разработки (Node.js + PHP + Python + Rust).

## 🚀 Быстрый старт

### 1. Создать проект из шаблона

```bash
# Клонировать шаблон
git clone https://github.com/nizovtsevnv/devcontainer-workspace.git my-project
cd my-project

# Запустить среду разработки
make up
# При первом запуске автоматически выполнится инициализация проекта:
# → Удаление файлов шаблона (.github/, README.md)
# → Переименование remote origin → template
# → Настройка нового origin (опционально)
# → Создание README.md проекта
# → Коммит изменений (опционально)
```

**Готово!** Среда разработки запущена и проект инициализирован.

### 2. Альтернативный способ: VS Code DevContainer

```bash
# Клонировать и открыть в VS Code
git clone https://github.com/nizovtsevnv/devcontainer-workspace.git my-project
cd my-project
code .
```

В VS Code:
1. Нажмите `F1` или `Ctrl+Shift+P`
2. Выберите `Dev Containers: Reopen in Container`
3. Дождитесь скачивания образа (~1-2 минуты)

При первом открытии в контейнере автоматически выполнится инициализация проекта.

### 4. Добавить субмодули проекта

```bash
# Добавить субмодуль (сервис, приложение, библиотеку)
git submodule add git@github.com:user/service-name.git modules/service-name

# Инициализировать субмодули
git submodule update --init --recursive
```

### 5. Разработка

Используйте воспроизводимую среду для:
- Разработки кода в субмодулях
- Написания документации в `doc/` и `README.md`
- Автоматизации через `make`

### 6. Публикация проекта

```bash
# Настроить удаленный репозиторий для вашего проекта
git remote add origin git@github.com:your-org/your-project.git

# Отправить в ваш репозиторий
git push -u origin main
```

---

## 📦 Что включено

### Технологические стеки
- **Node.js 22** - npm, yarn, pnpm, bun, TypeScript, ESLint, Prettier, nodemon, pm2
- **PHP 8.3** - Composer, php-cs-fixer, phpcs, phpstan (инструменты качества кода)
- **Python 3.11** - pip, poetry, pipenv, uv, black, flake8, pylint, pytest, mypy
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
├── .github/workflows/      # GitHub Actions
├── config/                 # Конфигурации стандартов качества
├── doc/                    # Документация проекта
├── makefiles/              # Модули системы автоматизации
├── modules/                # Git субмодули (ваши компоненты)
└── Makefile                # Главный makefile
```

---

## 📚 Документация

- [doc/devenv/makefile.md](doc/devenv/makefile.md) - Система автоматизации Makefile
- [doc/devenv/devcontainer.md](doc/devenv/devcontainer.md) - Руководство по работе с DevContainer
- [doc/devenv/file-tree.md](doc/devenv/file-tree.md) - Описание файловой структуры

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

### ⚠️ Важно для пользователей Podman

VS Code DevContainers при работе с Podman могут создавать файлы с неправильными правами доступа из-за особенностей user namespace mapping в rootless режиме.

**Рекомендация:** Если вы используете Podman, применяйте команды `make up/down/sh/exec` вместо "Reopen in Container" в VS Code. Эти команды корректно настраивают маппинг UID/GID.

```bash
# Вместо "Reopen in Container" используйте:
make up      # Запуск контейнера с правильными настройками
make sh      # Интерактивная оболочка
```

Подробнее: [doc/devenv/devcontainer.md](doc/devenv/devcontainer.md)

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

### Обновление шаблона DevContainer Workspace

Проекты, созданные через `make devenv init`, могут получать обновления из upstream шаблона:

```bash
# Проверить доступные обновления
make devenv version
# Показывает:
# → Текущую версию шаблона
# → Дату инициализации проекта
# → Доступные обновления и changelog

# Применить обновления из шаблона
make devenv update
# Интерактивный процесс:
# → Выбор версии для обновления (tag или main)
# → Просмотр changelog
# → Подтверждение обновления
# → Автоматический merge с обработкой конфликтов
```

### Обновление Docker образа

Когда выходят обновления образа среды разработки:

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

Больше решений: [doc/devenv/devcontainer.md](doc/devenv/devcontainer.md)

---

## 📋 Примеры использования

### Система автоматизации Make

Шаблон включает простую систему автоматизации:

```bash
# Команды шаблона
make devenv init           # Ручная инициализация (если нужно)
make devenv update         # Обновить версию шаблона
make devenv version        # Текущая и актуальная версия шаблона

# Управление средой разработки
make up                    # Запуск DevContainer (с авто-инициализацией)
make down                  # Остановка
make sh                    # Интерактивный shell
make exec '<команда>'      # Выполнение команды в контейнере
make version               # Версии инструментов

# Команды модулей
make <модуль>              # Справка по модулю

# Справка
make help                  # Все команды
```

Подробная документация: [doc/devenv/makefile.md](doc/devenv/makefile.md)

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
- [Docker образ среды разработки](https://github.com/nizovtsevnv/devcontainer-workspace/pkgs/container/devcontainer-workspace)
- [VS Code DevContainers](https://code.visualstudio.com/docs/devcontainers/containers)
- [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
