# Конфигурации стандартов качества

Единые конфигурации для инструментов контроля качества кода, используемых в workspace.

## Структура

```
config/
├── php/               # PHP конфигурации
│   ├── .php-cs-fixer.php    # PHP-CS-Fixer (форматирование)
│   ├── phpcs.xml            # PHP_CodeSniffer (линтинг)
│   └── phpstan.neon         # PHPStan (статический анализ)
├── javascript/        # JavaScript/TypeScript конфигурации
│   ├── .eslintrc.json       # ESLint (линтинг)
│   ├── .prettierrc.json     # Prettier (форматирование)
│   └── .prettierignore      # Prettier исключения
├── python/            # Python конфигурации
│   ├── pyproject.toml       # Black, Mypy, Pytest (форматирование, типы, тесты)
│   ├── .flake8              # Flake8 (линтинг)
│   └── .pylintrc            # Pylint (статический анализ)
└── rust/              # Rust конфигурации
    ├── rustfmt.toml         # Rustfmt (форматирование)
    └── clippy.toml          # Clippy (линтинг)
```

## Использование в модулях

Существует два способа использования конфигураций в модулях:

### 1. Символические ссылки (рекомендуется)

Создайте symlink из модуля на конфигурацию workspace:

```bash
cd modules/mymodule

# PHP
ln -s ../../config/php/.php-cs-fixer.php .php-cs-fixer.php
ln -s ../../config/php/phpcs.xml phpcs.xml
ln -s ../../config/php/phpstan.neon phpstan.neon

# JavaScript
ln -s ../../config/javascript/.eslintrc.json .eslintrc.json
ln -s ../../config/javascript/.prettierrc.json .prettierrc.json
ln -s ../../config/javascript/.prettierignore .prettierignore

# Python
ln -s ../../config/python/pyproject.toml pyproject.toml
ln -s ../../config/python/.flake8 .flake8
ln -s ../../config/python/.pylintrc .pylintrc

# Rust
ln -s ../../config/rust/rustfmt.toml rustfmt.toml
ln -s ../../config/rust/clippy.toml clippy.toml
```

**Преимущества:**
- Автоматическое обновление при изменении базовой конфигурации
- Не нужно копировать файлы вручную
- Единый источник правды

### 2. Расширение конфигураций

Создайте собственный файл конфигурации, который расширяет базовый:

#### PHP-CS-Fixer

```php
<?php
// modules/mymodule/.php-cs-fixer.php

require __DIR__ . '/../../config/php/.php-cs-fixer.php';

$config->setRules(array_merge($config->getRules(), [
    'declare_strict_types' => true,
    // Дополнительные правила модуля
]));

return $config;
```

#### PHPCS

```xml
<?xml version="1.0"?>
<!-- modules/mymodule/phpcs.xml -->
<ruleset name="MyModule">
    <rule ref="../../config/php/phpcs.xml"/>

    <!-- Дополнительные правила -->
    <rule ref="SomeOtherStandard">
        <exclude name="SomeRule"/>
    </rule>
</ruleset>
```

#### PHPStan

```neon
# modules/mymodule/phpstan.neon
includes:
  - ../../config/php/phpstan.neon

parameters:
  level: 8  # Переопределить уровень
  # Дополнительные параметры
```

#### ESLint

```json
{
  "extends": "../../config/javascript/.eslintrc.json",
  "rules": {
    "no-console": "off"
  }
}
```

#### Prettier

```json
{
  "extends": "../../config/javascript/.prettierrc.json",
  "printWidth": 120
}
```

## Описание стандартов

### PHP

**PHP-CS-Fixer** - автоматическое форматирование кода PHP
- Базовый стандарт: PSR-12
- Дополнительно: PHP 8.0/8.1 миграции, оптимизации
- Использование: `php-cs-fixer fix`

**PHP_CodeSniffer** - проверка соответствия стандартам кодирования
- Базовый стандарт: PSR-12
- Дополнительные правила: метрики сложности, соглашения по именованию
- Использование: `phpcs` или `phpcbf` (автоисправление)

**PHPStan** - статический анализ кода
- Уровень строгости: 6 (из 9)
- Проверяет типы, неиспользуемые переменные, возможные ошибки
- Использование: `phpstan analyse`

### JavaScript/TypeScript

**ESLint** - линтер для JavaScript/TypeScript
- Базовые правила: eslint:recommended
- Стиль: согласованный с Prettier
- Использование: `eslint src/` или `eslint --fix src/`

**Prettier** - форматировщик кода
- Максимальная ширина строки: 100
- Отступы: 2 пробела
- Кавычки: одинарные
- Точка с запятой: всегда
- Использование: `prettier --write src/`

### Rust

**Rustfmt** - форматировщик кода Rust
- Максимальная ширина: 100
- Стиль: idiomatic Rust
- Edition: 2021
- Использование: `cargo fmt`

**Clippy** - линтер для Rust
- Проверяет производительность, стиль, корректность
- Настраиваемые пороги сложности
- Использование: `cargo clippy`

### Python

**Black** - форматировщик кода Python
- Максимальная ширина строки: 100
- Целевая версия: Python 3.11+
- Неконфигурируемый стиль для согласованности
- Использование: `black .`

**Flake8** - линтер для Python
- Базовые правила: PEP 8
- Максимальная сложность: 10
- Совместимость с Black
- Использование: `flake8`

**Pylint** - статический анализатор кода
- Проверяет стиль, ошибки, рефакторинг
- Настраиваемые лимиты сложности
- Использование: `pylint src/`

**Mypy** - проверка типов
- Строгая проверка типов
- Python 3.11+
- Использование: `mypy .`

**Pytest** - фреймворк тестирования
- Автоматическое обнаружение тестов
- Поддержка маркеров (unit, integration, slow)
- Использование: `pytest`

## Интеграция в Makefile модуля

Пример Makefile для модуля с использованием этих конфигураций:

```makefile
# modules/mymodule/Makefile

.PHONY: lint format check

# PHP
lint-php:
	phpcs
	phpstan analyse

format-php:
	php-cs-fixer fix

# JavaScript
lint-js:
	eslint src/

format-js:
	prettier --write src/

# Python
lint-python:
	flake8
	pylint src/
	mypy .

format-python:
	black .

test-python:
	pytest

# Rust
lint-rust:
	cargo clippy -- -D warnings

format-rust:
	cargo fmt

# Общие команды
lint: lint-php lint-js lint-python lint-rust

format: format-php format-js format-python format-rust

check: lint
	@echo "✓ Все проверки пройдены"
```

## Рекомендации

1. **Используйте symlink для новых модулей** - это обеспечит согласованность
2. **Расширяйте только при необходимости** - если модулю нужны специфичные правила
3. **Документируйте отклонения** - если переопределяете базовые правила
4. **Запускайте линтеры локально** - перед коммитом
5. **Интегрируйте с IDE** - для автоматического форматирования при сохранении

## IDE интеграция

### VS Code

Установите расширения:
- PHP: `bmewburn.vscode-intelephense-client`, `junstyle.php-cs-fixer`
- JavaScript: `dbaeumer.vscode-eslint`, `esbenp.prettier-vscode`
- Python: `ms-python.python`, `ms-python.black-formatter`, `ms-python.flake8`, `ms-python.mypy-type-checker`
- Rust: `rust-lang.rust-analyzer`

Настройте автоформатирование в `.vscode/settings.json`:

```json
{
  "editor.formatOnSave": true,
  "[php]": {
    "editor.defaultFormatter": "junstyle.php-cs-fixer"
  },
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter"
  },
  "[rust]": {
    "editor.defaultFormatter": "rust-lang.rust-analyzer"
  }
}
```

## Обновление конфигураций

При обновлении базовых конфигураций в `config/`:

1. Модули с symlink получат изменения автоматически
2. Модули с расширением нужно проверить на совместимость
3. Запустите тесты и линтеры во всех модулях

## Дополнительная информация

- [PHP-CS-Fixer документация](https://github.com/PHP-CS-Fixer/PHP-CS-Fixer)
- [PHP_CodeSniffer документация](https://github.com/squizlabs/PHP_CodeSniffer)
- [PHPStan документация](https://phpstan.org/)
- [ESLint документация](https://eslint.org/)
- [Prettier документация](https://prettier.io/)
- [Black документация](https://black.readthedocs.io/)
- [Flake8 документация](https://flake8.pycqa.org/)
- [Pylint документация](https://pylint.readthedocs.io/)
- [Mypy документация](https://mypy.readthedocs.io/)
- [Pytest документация](https://docs.pytest.org/)
- [Rustfmt документация](https://rust-lang.github.io/rustfmt/)
- [Clippy документация](https://github.com/rust-lang/rust-clippy)
