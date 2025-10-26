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

# Установка bun (современный пакетный менеджер для Node.js)
RUN curl -fsSL https://bun.sh/install | bash \
  && ln -s /root/.bun/bin/bun /usr/local/bin/bun

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
RUN python3 -m pip install --upgrade pip setuptools wheel

# Установка Python пакетных менеджеров
RUN python3 -m pip install \
  poetry \
  pipenv

# Установка uv (современный быстрый пакетный менеджер для Python)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Глобальные Python инструменты для контроля единых стандартов качества workspace
RUN python3 -m pip install \
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
ARG USER_GID=$USER_UID

# Создаём группу и пользователя developer
RUN groupadd --gid ${USER_GID} ${USERNAME} && \
  useradd -m -u ${USER_UID} -g ${USER_GID} -s /bin/bash ${USERNAME}

# Создаём группы docker и podman (если не существуют) и добавляем пользователя
RUN (getent group docker || groupadd docker) && \
  (getent group podman || groupadd podman) && \
  usermod -aG docker,podman ${USERNAME}

# Создать группу users (GID 100) для совместимости с большинством Linux дистрибутивов
# Это позволяет пользователю в контейнере редактировать файлы созданные на хосте
RUN groupadd -f -g 100 users && usermod -aG users ${USERNAME}

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
# Setgid бит (2775) обеспечивает что все файлы наследуют GID директории
# Групповые права (g+rwX) позволяют работать с файлами независимо от runtime UID/GID
RUN mkdir -p /workspace \
  && chown -R ${USER_UID}:users /workspace \
  && chmod -R 2775 /workspace

# Настройка git safe.directory (решает проблему "dubious ownership")
RUN git config --system --add safe.directory /workspace

# Переключение на непривилегированного пользователя
USER ${USERNAME}
WORKDIR /workspace

# ===================================
# Rust + cargo инструменты
# ===================================
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly \
  && . $HOME/.cargo/env \
  && rustup component add rustfmt clippy rust-analyzer \
  && cargo install cargo-watch cargo-edit cargo-outdated

# ===================================
# Настройка окружения и PATH
# ===================================
RUN npm config set prefix "/home/$USERNAME/.npm-global"

ENV PATH="/home/$USERNAME/.npm-global/bin:/home/$USERNAME/.cargo/bin:/home/$USERNAME/.composer/vendor/bin:/root/.composer/vendor/bin:/root/.bun/bin:/root/.local/bin:${PATH}"

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

# Установить setgid бит и групповые права на home директорию и кэши
# Это позволяет работать с файлами независимо от runtime UID/GID
RUN mkdir -p $HOME/.cache $HOME/.local \
  && sudo chgrp -R users $HOME $HOME/.cache $HOME/.local $HOME/.npm-global \
  && sudo chmod -R g+rwX $HOME $HOME/.cache $HOME/.local $HOME/.npm-global \
  && sudo chmod g+s $HOME $HOME/.cache $HOME/.local $HOME/.npm-global

CMD ["/bin/bash"]
