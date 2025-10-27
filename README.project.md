# My Project

> Краткое описание проекта

## 🚀 Быстрый старт

### Требования

- Docker или Podman
- Make
- Git

### Запуск среды разработки

```bash
# Запустить DevContainer
make up

# Открыть интерактивный shell
make sh

# Или открыть в VSCode
code .
# Dev Containers: Reopen in Container
```

## 📦 Структура проекта

```
.
├── modules/          # Модули проекта (субмодули)
├── .devcontainer/    # Конфигурация DevContainer
├── makefiles/        # Makefile система
└── config/           # Конфигурационные файлы
```

## 🛠 Разработка

Проект использует [DevContainer Workspace](https://github.com/nizovtsevnv/devcontainer-workspace) - универсальную среду разработки с Node.js, PHP, Python и Rust.

### Основные команды

```bash
# Управление средой
make help             # Показать все доступные команды
make up               # Запустить DevContainer
make down             # Остановить DevContainer
make sh               # Интерактивный shell
make exec 'команда'   # Выполнить команду в контейнере

# Версии инструментов
make version          # Показать версии Node.js, PHP, Python, Rust
```

### Работа с модулями

```bash
# Список модулей
make help

# Команды модуля
make <модуль> <менеджер> <команда>

# Примеры
make myapp bun install      # Установить зависимости Node.js
make api composer install   # Установить зависимости PHP
make ml uv run main.py      # Запустить Python скрипт
```

## 🔄 Обновление DevEnv

Проект может получать обновления среды разработки из upstream шаблона:

```bash
# Проверить доступные обновления
make devenv version

# Применить обновления
make devenv update
```

## 📝 Лицензия

[Укажите лицензию проекта]

## 👥 Авторы

[Укажите авторов]
