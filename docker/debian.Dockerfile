# MIT/Apache2 License
# Written by John Nunley

ARG DEBIAN_VERSION=bullseye

FROM debian:"${DEBIAN_VERSION}-slim"
SHELL ["/bin/sh", "-eux", "-c"]
ARG DEBIAN_FRONTEND

# Install dependencies from apk
RUN apt-get -o Acquire::Retries=10 -qq update && \
apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends \
    ca-certificates \
    curl \
    git
rm -rf \
    /var/lib/apt/lists/* \
    /var/cache/* \
    /var/log/* \
    /usr/share/{doc,man}

# Copy files from our checks and configs.
COPY ./checks/*.sh /usr/bin/
RUN chmod +x /usr/bin/*.sh
