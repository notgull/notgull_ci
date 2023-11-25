#!/bin/sh
# MIT/Apache2 License

set -eu

rx() {
  cmd="$1"
  shift
  (
    set -x
    "$cmd" "$@"
  )
}
retry() {
  for i in $(seq 1 10); do
    if "$@"; then
      return 0
    else
      sleep "$i"
    fi
  done
  "$@"
}
bail() {
  echo >&2 "[fatal]: $*"
  exit 1
}
info() {
  echo >&2 "[info]: $*"
}
np() {
  cmd="$1"
  shift
  "$cmd" "$@" >/dev/null 2>/dev/null
}
find_str() {
  haystack="$1"
  shift
  grep -q "$@" <<EOF
$haystack
EOF
}
split_str() {
  haystack="$1"
  shift
  cut "$@" <<EOF
$haystack
EOF
}
has_command() {
  np command -v "$@"
}
priv() {
  if has_command doas; then
    doas "$@"
  elif has_command sudo; then
    sudo "$@"
  else
    "$@"
  fi
}

apt_update() {
  retry priv apt-get -o Acquire::Retries=10 -qq update
  apt_updated=1
}
apt_install() {
  if [ -z "${apt_updated:-}" ]; then
    apt_update
  fi
  retry priv apt-get -qq -o Acquire::Retries=10 -o Dpkg:Use-Pty=0 -y --no-install-recommends install "$@"
}
apk_install() {
  priv apk --no-cache add "$@"
}
dnf_install() {
  if [ -z "${dnf:-}" ]; then
    if has_command dnf; then
      dnf=dnf
    elif has_command microdnf; then
      dnf=microdnf
    else
      dnf=yum
    fi
  fi

  retry priv "$dnf" install -y "$@"
}
sys_install() {
  case "$base_distro" in
  debian) apt_install "$@" ;;
  alpine) apk_install "$@" ;;
  fedora) dnf_install "$@" ;;
  *) bail "cannot use sys_install on non-Linux" ;;
  esac
}

install_node() {
  version="$1"

  NVM_URL="https://github.com/nvm-sh/nvm/raw/v0.39.5/install.sh"
  NVM_DIR="/usr/local/nvm"

  if ! has_command bash; then
    install_package bash
  fi

  mkdir -pv "$NVM_DIR"
  curl -sSf -L "$NVM_URL" | NVM_DIR="$NVM_DIR" bash
  rx bash -c ". $NVM_DIR/nvm.sh && nvm install $version && nvm alias default $version && nvm use default"
  priv ln -s "$NVM_DIR/versions/node/v$version/bin/npm" /usr/bin/npm
  priv ln -s "$NVM_DIR/versions/node/v$version/bin/node" /usr/bin/node
  priv ln -s "$NVM_DIR/versions/node/v$version/bin/npx" /usr/bin/npx
  np npm --version
  np node --version
}
install_shfmt() {
  SHFMT_URL="https://github.com/mvdan/sh/releases/download/v3.7.0/shfmt_v3.7.0_linux_amd64"

  priv curl -sSf -L "$SHFMT_URL" -o /usr/bin/shfmt
  priv chmod +x /usr/bin/shfmt
  np shfmt --version
}
install_rust() {
  toolchain="${1:-stable}"

  if ! has_command curl; then
    info "curl not found; installing"
    sys_install curl
  fi

  # Install rustup if we don't have it.
  if ! has_command rustup; then
    info "rustup not found; installing"
    curl https://sh.rustup.rs -sSf |
      sh -s -- -y --no-modify-path --profile minimal --default-toolchain "$toolchain"
    priv ln -s "$HOME/.cargo/bin/rustup" "/usr/bin/rustup"
    np rustup --version
  fi

  # Install the toolchain.
  rx rustup toolchain add "$toolchain"
  priv ln -s "$HOME/.cargo/bin/cargo" "/usr/bin/cargo"
  np cargo --version
}
install_tea() {
  TEA_URL="https://dl.gitea.com/tea/0.9.2/tea-0.9.2-linux-amd64"

  priv curl -sSf -L "$TEA_URL" -o /usr/bin/tea
  priv chmod +x /usr/bin/tea
  np tea --version
}
install_package() {
  package="$1"

  info "installing package $package"

  case "$package" in
  node*)
    if find_str "$package" ':'; then
      version="$(split_str "$package" -d':' -f2)"
    else
      version="21.2.0"
    fi
    install_node "$version"
    ;;
  rust*)
    if find_str "$package" ':'; then
      toolchain="$(split_str "$package" -d':' -f2)"
    else
      toolchain=stable
    fi
    install_rust "$toolchain"
    ;;
  bash)
    if [ "$base_distro" = "alpine" ]; then
      sys_install bash
    fi
    ;;
  clang) sys_install clang ;;
  clang-format) sys_install clang-format ;;
  curl) sys_install curl ca-certificates ;;
  git) sys_install git ;;
  jq) sys_install jq ;;
  mingw-w64)
    case "$base_distro" in
    alpine) sys_install mingw-w64-gcc mingw-w64-headers ;;
    *) sys_install mingw-w64 ;;
    esac
    ;;
  shellcheck) sys_install shellcheck ;;
  shfmt) install_shfmt ;;
  tea)
    case "$base_distro" in
    alpine) sys_install tea ;;
    *) install_tea ;;
    esac
    ;;
  *) bail "unknown package $package" ;;
  esac
}

base_distro=""
base_distro=""
case "$(uname -s)" in
Linux)
  if grep -q '^ID_LIKE=' /etc/os-release; then
    base_distro=$(grep '^ID_LIKE=' /etc/os-release | sed 's/^ID_LIKE=//')
    case "${base_distro}" in
    *debian*) base_distro=debian ;;
    *alpine*) base_distro=alpine ;;
    *fedora*) base_distro=fedora ;;
    esac
  else
    base_distro=$(grep '^ID=' /etc/os-release | sed 's/^ID=//')
  fi
  ;;
*) bail "unsupported operating system $(uname -s)" ;;
esac

for package in "$@"; do
  install_package "$package"
done
