# Файловая структура рабочего пространства проекта

```
/
├── .editorconfig                 # Настройки форматирования кода для всех редакторов
├── .git/                         # Git repository
├── .gitignore                    # Базовые Git ignore правила (каждый модуль расширяет правила своим файлом конфигурации)
├── .gitmodules                   # Конфигурация git модулей
├── .github/
│   └── workflows/
│       └── build-devcontainer.yml  # GitHub Actions: автосборка и публикация Docker образа
├── .devcontainer/
│   ├── devcontainer.json         # Конфигурация Devcontainer
│   └── Dockerfile                # Конфигурация образа воспроизводимой среды разработки (Debian, NodeJS, PHP, Rust, утилиты)
├── config/                       # Конфигурации единых стандартов качества
│   ├── php/                      # PHP стандарты (php-cs-fixer, phpcs, phpstan)
│   ├── node/                     # Node.js стандарты (eslint, prettier)
│   └── rust/                     # Rust стандарты (rustfmt, clippy)
├── doc/                          # Документация workspace
│   ├── devcontainer.md           # Руководство по работе с Devcontainer
│   └── file-tree.md              # Этот файл
└── modules/                      # Git submodules (модули программных компонентов проекта - сервисы, приложения, библиотеки)
    └── .gitkeep                  # Placeholder для защиты каталога от удаления из Git
```
