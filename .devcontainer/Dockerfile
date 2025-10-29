# Polyglot окружение разработки для рабочего пространства проекта
# Debian Bookworm LTS + Node.js + PHP + Python + Rust + инструменты разработки

FROM debian:bookworm

# Версии технологических стеков
ARG NODE_VERSION=22
ARG PHP_VERSION=8.3

# Метаданные образа
LABEL maintainer="Nick Nizovtsev"
LABEL description="Polyglot development environment"

# ===================================
# Базовые системные инструменты
# ===================================
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
  # Системные утилиты
  ca-certificates \
  curl \
  wget \
  git \
  make \
  build-essential \
  # Docker CLI для работы с host Docker
  docker.io \
  docker-compose \
  # Утилиты для работы с данными
  jq \
  yq \
  # Утилиты файловой системы
  tree \
  file \
  unzip \
  zip \
  # Редакторы
  vim \
  nano \
  # Мониторинг
  htop \
  # Сетевые утилиты
  netcat-openbsd \
  iputils-ping \
  dnsutils \
  telnet \
  # Bash дополнения
  bash-completion \
  # Для PHP и Rust
  lsb-release \
  apt-transport-https \
  gnupg \
  pkg-config \
  libssl-dev \
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

# ===================================
# Gum - интерактивные CLI компоненты
# ===================================
RUN curl -fsSL https://github.com/charmbracelet/gum/releases/download/v0.14.5/gum_0.14.5_Linux_x86_64.tar.gz | \
  tar -xz -C /tmp && \
  mv /tmp/gum /usr/local/bin/gum && \
  chmod +x /usr/local/bin/gum

# ===================================
# Node.js + npm инструменты
# ===================================
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
  && apt-get install -y nodejs \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

# Глобальные npm пакеты
RUN npm install -g \
  npm@latest \
  yarn \
  pnpm \
  typescript \
  ts-node \
  eslint \
  prettier \
  nodemon \
  pm2

# ===================================
# PHP + Composer + инструменты
# ===================================
RUN curl -sSL https://packages.sury.org/php/README.txt | bash -x \
  && apt-get update

RUN apt-get install -y \
  php${PHP_VERSION}-cli \
  php${PHP_VERSION}-common \
  php${PHP_VERSION}-curl \
  php${PHP_VERSION}-mbstring \
  php${PHP_VERSION}-xml \
  php${PHP_VERSION}-zip \
  php${PHP_VERSION}-bcmath \
  php${PHP_VERSION}-intl \
  php${PHP_VERSION}-gd \
  php${PHP_VERSION}-mysql \
  php${PHP_VERSION}-pgsql \
  php${PHP_VERSION}-sqlite3 \
  php${PHP_VERSION}-redis \
  php${PHP_VERSION}-opcache \
  php${PHP_VERSION}-xdebug \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

# Установка Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Глобальные PHP инструменты для контроля единых стандартов качества workspace
RUN composer global require \
  friendsofphp/php-cs-fixer \
  squizlabs/php_codesniffer \
  phpstan/phpstan

# ===================================
# Python + pip + инструменты
# ===================================
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
  python3 \
  python3-pip \
  python3-venv \
  python3-dev \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

# Обновление pip и установка базовых инструментов
# --break-system-packages безопасно для Docker контейнеров (PEP 668)
RUN python3 -m pip install --break-system-packages --upgrade pip setuptools wheel

# Установка Python пакетных менеджеров
RUN python3 -m pip install --break-system-packages \
  poetry \
  pipenv

# Установка uv (современный быстрый пакетный менеджер для Python)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Глобальные Python инструменты для контроля единых стандартов качества workspace
RUN python3 -m pip install --break-system-packages \
  black \
  flake8 \
  pylint \
  pytest \
  mypy

# ===================================
# Создание непривилегированного пользователя
# Совместимость с Docker и Podman на всех платформах
# ===================================
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000

# Создаём группу и пользователя developer
RUN groupadd --gid ${USER_GID} ${USERNAME} && \
  useradd -m -u ${USER_UID} -g ${USER_GID} -s /bin/bash ${USERNAME}

# Создаём группы docker и podman (если не существуют) и добавляем пользователя
RUN (getent group docker || groupadd docker) && \
  (getent group podman || groupadd podman) && \
  usermod -aG docker,podman ${USERNAME}

# Настройка sudo без пароля
RUN apt-get update \
  && apt-get install -y sudo \
  && echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
  && chmod 0440 /etc/sudoers.d/${USERNAME} \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

# Настройка npm для пользователя
RUN mkdir -p /home/${USERNAME}/.npm-global \
  && chown -R ${USERNAME}:${USER_GID} /home/${USERNAME}/.npm-global

# Создаём /workspace и устанавливаем права
# Владелец будет автоматически исправлен entrypoint.sh при запуске
RUN mkdir -p /workspace \
  && chown -R ${USER_UID}:${USER_GID} /workspace \
  && chmod -R 775 /workspace

# Настройка git safe.directory (решает проблему "dubious ownership")
RUN git config --system --add safe.directory /workspace

# Копировать и настроить entrypoint для автоматической настройки прав
COPY .devcontainer/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Переключение на непривилегированного пользователя
USER ${USERNAME}
WORKDIR /workspace

# Entrypoint для автоматического исправления прав доступа
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# ===================================
# Node.js пакетные менеджеры для пользователя
# ===================================
# Установка bun (современный пакетный менеджер для Node.js)
RUN curl -fsSL https://bun.sh/install | bash

# ===================================
# Rust + cargo инструменты
# ===================================
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly \
  && . $HOME/.cargo/env \
  && rustup component add rustfmt clippy rust-analyzer

# Установка cargo утилит с кэшированием для ускорения сборки
RUN --mount=type=cache,target=/home/developer/.cargo/registry,uid=1000,gid=1000 \
    --mount=type=cache,target=/home/developer/.cargo/git,uid=1000,gid=1000 \
    . $HOME/.cargo/env \
    && cargo install cargo-watch cargo-edit cargo-outdated

# ===================================
# Настройка окружения и PATH
# ===================================
RUN npm config set prefix "/home/$USERNAME/.npm-global"

ENV PATH="/home/$USERNAME/.npm-global/bin:/home/$USERNAME/.cargo/bin:/home/$USERNAME/.composer/vendor/bin:/home/$USERNAME/.bun/bin:/root/.composer/vendor/bin:/root/.local/bin:${PATH}"

# Настройка git для пользователя
RUN git config --global init.defaultBranch main \
  && git config --global core.editor vim \
  && git config --global --add safe.directory /workspace

# Вывод версий установленных инструментов при сборке
RUN echo "========================================" \
  && echo "Установленные инструменты:" \
  && echo "========================================" \
  && echo "Docker:    $(docker --version)" \
  && echo "Git:       $(git --version)" \
  && echo "Make:      $(make --version | head -n1)" \
  && echo "jq:        $(jq --version)" \
  && echo "yq:        $(yq --version)" \
  && echo "gum:       $(gum --version)" \
  && echo "----------------------------------------" \
  && echo "Node.js:   $(node --version)" \
  && echo "bun:       $(bun --version)" \
  && echo "npm:       $(npm --version)" \
  && echo "pnpm:      $(pnpm --version)" \
  && echo "yarn:      $(yarn --version)" \
  && echo "----------------------------------------" \
  && echo "PHP:       $(php --version | head -n1)" \
  && echo "Composer:  $(composer --version)" \
  && echo "----------------------------------------" \
  && echo "Python:    $(python3 --version)" \
  && echo "pip:       $(python3 -m pip --version)" \
  && echo "pipenv:    $(pipenv --version)" \
  && echo "poetry:    $(poetry --version)" \
  && echo "uv:        $(uv --version)" \
  && echo "----------------------------------------" \
  && echo "Rust:      $(rustc --version)" \
  && echo "Cargo:     $(cargo --version)" \
  && echo "========================================"

# ===================================
# Настройка групповых прав доступа
# ===================================
# Установить umask для группового доступа к создаваемым файлам
RUN echo 'umask 0002' >> $HOME/.bashrc

# Установить групповые права на home директорию и кэши
RUN mkdir -p $HOME/.cache $HOME/.local

CMD ["/bin/bash"]
