# Stage 1: Copy uv from astral-sh/uv
FROM docker.io/golang:1.25-bookworm as golang

# Stage 2: Base image
FROM debian:bookworm-slim

# Set noninteractive frontend for apt
ENV DEBIAN_FRONTEND=noninteractive

# Define build arguments for user configuration
ARG USERNAME=toor
ARG USER_UID=1000
ARG USER_GID=1000

# config ca-certificates from mounted -v $HOME/source/*.crt:/var/crts/ & Configure Debian repositories
RUN echo "deb http://ftp.us.debian.org/debian bookworm main contrib" > /etc/apt/sources.list \
	&& echo "deb http://security.debian.org/debian-security bookworm-security main contrib" >> /etc/apt/sources.list \
	&& echo "deb http://ftp.us.debian.org/debian bookworm-updates main contrib" >> /etc/apt/sources.list \
	&& apt-get update -y \
   && apt-get install -y --no-install-recommends apt ca-certificates \
   && if [ -d /var/crts ] && [ -n "$(ls /var/crts/*.crt 2>/dev/null)" ]; then \
        cp /var/crts/*.crt /usr/local/share/ca-certificates/ \
        && update-ca-certificates; fi \
	&& apt-get clean \
   && rm -rf /var/lib/apt/lists/*
	 
# Copy uv and uvx from the uv stage
COPY --from=golang /usr/local/go /usr/local/

# Create a non-root user
RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USERNAME --shell /bin/bash --create-home $USERNAME

# Install Node.js
ENV NODE_VERSION=24.6.0

RUN set -ex \
    && ARCH= OPENSSL_ARCH= && dpkgArch="$(dpkg --print-architecture)" \
    && case "${dpkgArch##*-}" in \
        amd64) ARCH='x64' OPENSSL_ARCH='linux-x86_64';; \
        ppc64el) ARCH='ppc64le' OPENSSL_ARCH='linux-ppc64le';; \
        s390x) ARCH='s390x' OPENSSL_ARCH='linux-s390x';; \
        arm64) ARCH='arm64' OPENSSL_ARCH='linux-aarch64';; \
        armhf) ARCH='armv7l' OPENSSL_ARCH='linux-armv4';; \
        i386) ARCH='x86' OPENSSL_ARCH='linux-elf';; \
        *) echo "unsupported architecture"; exit 1 ;; \
    esac \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        curl wget gnupg dirmngr xz-utils libatomic1 \
    && export GNUPGHOME="$(mktemp -d)" \
    && for key in \
      5BE8A3F6C8A5C01D106C0AD820B1A390B168D356 \
      DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7 \
      CC68F5A3106FF448322E48ED27F5E38D5B0A215F \
      8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
      890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
      C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
      108F52B48DB57BB0CC439B2997B01419BD92F80A \
      A363A499291CBBC940DD62E41F10027AF002F8B0 \
    ; do \
        gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
        gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" \
    ; done \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
    && find /usr/local/include/node/openssl/archs -mindepth 1 -maxdepth 1 ! -name "$OPENSSL_ARCH" -exec rm -rf {} \; \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
    && node --version \
    && npm --version \
    && apt-get purge -y --auto-remove gnupg dirmngr \
    && rm -rf "$GNUPGHOME" /var/lib/apt/lists/*

# Enable pnpm
RUN corepack enable \
    && pnpm config --global set store-dir /pnpm-store

# Install common utilities
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        apt-utils bash-completion openssh-client iproute2 procps \
        lsof htop net-tools psmisc curl tree wget rsync ca-certificates \
        unzip bzip2 xz-utils zip nano vim-tiny less jq lsb-release apt-transport-https \
        dialog locales sudo ncdu man-db strace manpages git zsh zsh-autosuggestions zsh-syntax-highlighting \
    && if apt-cache show libssl3 > /dev/null 2>&1; then apt-get install -y --no-install-recommends libssl3; fi \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && usermod --shell /bin/zsh ${USERNAME} \
    && apt-get upgrade -y --no-install-recommends \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install oh-my-zsh and agnosterzak theme for root
RUN sh -c "$(curl -fsSL --insecure https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" -- --unattended \
    && git clone https://github.com/zakaziko99/agnosterzak-ohmyzsh-theme.git /root/.oh-my-zsh/custom/themes/agnosterzak-ohmyzsh-theme \
    && git clone https://github.com/zsh-users/zsh-autosuggestions.git /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git /root/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting \
    && git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git /root/.oh-my-zsh/custom/plugins/fast-syntax-highlighting \
    && git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git /root/.oh-my-zsh/custom/plugins/zsh-autocomplete \
    && ln -s /root/.oh-my-zsh/custom/themes/agnosterzak-ohmyzsh-theme/agnosterzak.zsh-theme /root/.oh-my-zsh/custom/themes/agnosterzak.zsh-theme \
    && grep -q '^ZSH_THEME=' /root/.zshrc \
    && sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnosterzak"/' /root/.zshrc \
    || echo 'ZSH_THEME="agnosterzak"' >> /root/.zshrc \
	 && grep -q '^plugins=' /root/.zshrc \
    && sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)' /root/.zshrc \
    || echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)' >> /root/.zshrc

# Enable unicode characters
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# -v $HOME/.ssh:/var/.ssh
# Copy oh-my-zsh configuration to toor user and set up .ssh directory mouted at /var/.ssh
RUN user_home=$(getent passwd $USERNAME | cut -d: -f6) \
    && cp -r /root/.oh-my-zsh ${user_home}/.oh-my-zsh \
    && cp /root/.zshrc ${user_home}/.zshrc \
    && cp -r /var/.ssh ${user_home}/.ssh \
    && ln -sf ${user_home}/.oh-my-zsh/custom/themes/agnosterzak-ohmyzsh-theme/agnosterzak.zsh-theme ${user_home}/.oh-my-zsh/custom/themes/agnosterzak.zsh-theme \
    && chown -R ${USERNAME}:${USERNAME} ${user_home}/.oh-my-zsh ${user_home}/.zshrc ${user_home}/.ssh \
    && chmod 700 ${user_home}/.ssh \
    && chmod 600 ${user_home}/.ssh/id* \
    && chmod 644 ${user_home}/.ssh/id*.pub \
    && for rc_file in .bashrc .profile .zprofile; do \
        if [ -f "/etc/skel/${rc_file}" ]; then \
            if [ ! -e "${user_home}/${rc_file}" ] || [ ! -s "${user_home}/${rc_file}" ]; then \
                cp "/etc/skel/${rc_file}" "${user_home}/${rc_file}" \
                && chown ${USERNAME}:${USERNAME} "${user_home}/${rc_file}"; \
            fi \
        fi \
	 done \
    && echo 'source $HOME/.profile' >> "${user_home}/.zprofile"  \
    && chown ${USERNAME}:${USERNAME} "${user_home}/.zprofile"\
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen


# Default command
CMD ["zsh"]