# Файловая структура рабочего пространства проекта

```
/
├── .editorconfig                 # Настройки форматирования кода для всех редакторов
├── .git/                         # Git repository
├── .gitignore                    # Базовые Git ignore правила
├── .gitmodules                   # Конфигурация git субмодулей
├── .github/                      # GitHub workflows (только в шаблоне, удаляется при инициализации)
│   └── workflows/
│       └── build-devcontainer.yml  # GitHub Actions: автосборка и публикация Docker образа
├── .devcontainer/
│   ├── devcontainer.json         # Конфигурация DevContainer для VS Code
│   ├── docker-compose.yml        # Docker Compose для headless режима
│   ├── Dockerfile                # Образ среды разработки (Debian, Node.js, PHP, Python, Rust)
│   └── entrypoint.sh             # Инициализация контейнера (UID/GID маппинг)
├── Makefile                      # Главный makefile с системой многоуровневых команд
├── README.md                     # Документация (шаблона или проекта)
├── README.project.md             # Шаблон README для нового проекта (удаляется при инициализации)
├── makefiles/                    # Модули системы автоматизации
│   ├── config.mk                 # Конфигурация, переменные, определение окружения
│   ├── functions.mk              # Переиспользуемые функции (логирование, утилиты)
│   ├── detect.mk                 # Автоопределение технологий и пакетных менеджеров
│   ├── core.mk                   # Базовые команды (up, down, sh, exec, version)
│   ├── modules.mk                # Динамические команды модулей
│   ├── devenv.mk                 # Управление шаблоном (init, version, update)
│   └── help.mk                   # Система справки
├── config/                       # Конфигурации единых стандартов качества
│   ├── php/                      # PHP стандарты (php-cs-fixer, phpcs, phpstan)
│   ├── javascript/               # JavaScript/TypeScript стандарты (eslint, prettier)
│   ├── python/                   # Python стандарты (black, flake8, pylint, mypy)
│   └── rust/                     # Rust стандарты (rustfmt, clippy)
├── doc/                          # Документация
│   ├── README.md                 # Описание структуры документации
│   └── devenv/                   # Документация workspace шаблона
│       ├── makefile.md           # Документация системы автоматизации
│       ├── devcontainer.md       # Руководство по работе с DevContainer
│       └── file-tree.md          # Этот файл
└── modules/                      # Git субмодули (компоненты проекта: сервисы, приложения, библиотеки)
    └── .gitkeep                  # Placeholder для защиты каталога от удаления из Git
```

## Примечания

- **Метаданные шаблона**: версия определяется из git tags (`git describe --tags`)
- **Статус инициализации**: определяется наличием git remote 'template'
- **Файлы удаляемые при `make devenv init`**: `.github/`, `README.md`, `README.project.md`
