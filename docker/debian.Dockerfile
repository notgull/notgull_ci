# MIT/Apache2 License
# Written by John Nunley

ARG DEBIAN_VERSION=bullseye
ARG RUST_VERSION=stable
ARG DEBIAN_FRONTEND=noninteractive

FROM debian:"${DEBIAN_VERSION}-slim"
SHELL ["/bin/sh", "-eux", "-c"]
ARG DEBIAN_FRONTEND
ARG RUST_VERSION

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH="/usr/local/cargo/bin:$PATH" \
    NVM_DIR=/usr/local/nvm \
    NODE_VERSION=21.2.0 \
    SHFMT_URL=https://github.com/mvdan/sh/releases/download/v3.7.0/shfmt_v3.7.0_linux_amd64 \
    NVM_URL=https://github.com/nvm-sh/nvm/raw/v0.39.5/install.sh

# Install dependencies from apk
RUN apt-get -o Acquire::Retries=10 -qq update && \
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    ca-certificates \
    clang-format \
    curl \
    git \
    jq \
    shellcheck \
    && \
rm -rf \
    /var/lib/apt/lists/* \
    /var/cache/* \
    /var/log/* \
    /usr/share/{doc,man}

# Install rustup and Rust, delete unneeded docs
RUN curl https://sh.rustup.rs -sSf | \
    sh -s -- -y --no-modify-path --profile minimal --default-toolchain "$RUST_VERSION" && \
    rm -rf "$RUSTUP_HOME"/toolchains/*/share && \
    cargo --version && \
    rustup --version && \
    rustc --version

# Debian's repos don't have shfmt; download it for ourselves.
RUN curl -k -L -s "$SHFMT_URL" -o /usr/bin/shfmt && \
    chmod +x /usr/bin/shfmt && \
    shfmt --version

# Debian's repos have a really old npm; download a newer version.
RUN mkdir -pv "$NVM_DIR" && \
    curl -k -L -s -o- "$NVM_URL" | bash && \
    bash -c ". $NVM_DIR/nvm.sh && nvm install $NODE_VERSION" && \
    set +u && \
    . "$NVM_DIR/nvm.sh" && \
    npm --version && \
    node --version

# Copy files from our checks.
COPY ./checks/*.sh /usr/bin
RUN chmod +x /usr/bin/*.sh
