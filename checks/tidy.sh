#!/bin/sh

set -eu

# Checks that the Rust project is tidied up.
# Assumes that the following utilities are already installed:
# - cargo with rustfmt and clippy (if there are any *.rs files)
# - clang-format (if there are any *.c or *.cpp files)
# - shellcheck
# - shfmt
# - git
# - npm
# These are all usually installed in the Docker images.

rx() {
  cmd="$1"
  shift
  (
    set -x
    "$cmd" "$@"
  )
}
info() {
  echo >&2 "[info]: $*"
}
warn() {
  echo >&2 "[warning]: $*"
  should_fail=1
}
error() {
  echo >&2 "[error]: $*"
  should_fail=1
}
np() {
  cmd="$1"
  shift
  "$cmd" "$@" >/dev/null 2>/dev/null
}

check_diff() {
  if ! git --no-pager diff --exit-code "$@"; then
    should_fail=1
  fi
}

tidy_rust_files() {
  # If there are no rust files, skip them.
  if [ -z "$(git ls-files '*.rs')" ]; then
    return
  fi

  info "checking Rust code style"
  if np command -v rustup; then
    # Check formatting.
    np rustup component add rustfmt
    # shellcheck disable=SC2046
    rx rustfmt $(git ls-files '*.rs')
    # shellcheck disable=SC2046
    check_diff $(git ls-files '*.rs')

    # Avoid using up all of our disk space by cleaning.
    np cargo clean
  else
    warn "'rustup' is not installed; skipped Rust style check"
  fi
}
tidy_c_files() {
  if [ -z "$(git ls-files '*.c' '*.h' '*.cpp' '*.hpp')" ]; then
    return
  fi

  info "checking C/C++ code style"
  if np command -v clang-format; then
    # shellcheck disable=SC2046
    rx clang-format -i $(git ls-files '*.c' '*.h' '*.cpp' '*.hpp')
    # shellcheck disable=SC2046
    check_diff $(git ls-files '*.c' '*.h' '*.cpp' '*.hpp')
  else
    warn "'clang-format' is not installed; skipped C/C++ style check"
  fi
}
tidy_prettier() {
  if [ -z "$(git ls-files '*.yml' '*.js' '*.json')" ]; then
    return
  fi

  info "checking JavaScript/YAML/JSON code style"
  if np command -v npm; then
    # shellcheck disable=SC2046
    rx npx -y prettier -l -w $(git ls-files '*.yml' '*.js' '*.json')
    # shellcheck disable=SC2046
    check_diff $(git ls-files '*.yml' '*.js' '*.json')
  else
    warn "'npm' is not installed; skipped Prettier style check"
  fi
}
tidy_markdown() {
  if ! (git ls-files '*.md' | grep -qiv license); then
    return
  fi

  info "checking Markdown style"
  if np command -v npm; then
    # shellcheck disable=SC2046
    if ! rx npx -y markdownlint-cli2 $(git ls-files '*.md' | grep -iv license); then
      should_fail=1
    fi
  else
    warn "'npm' is not installed; skipped Markdown style check"
  fi
}
tidy_shell() {
  if [ -z "$(git ls-files '*.sh')" ]; then
    return
  fi

  info "checking shell style"
  if np command -v shfmt; then
    # shellcheck disable=SC2046
    rx shfmt -i 2 -l -w $(git ls-files '*.sh')
  else
    warn "'shfmt' is not installed; skip shell script fmt check"
  fi
  if np command -v shellcheck; then
    # shellcheck disable=SC2046
    if ! rx shellcheck $(git ls-files '*.sh'); then
      should_fail=1
    fi
    if [ -n "$(git ls-files '*Dockerfile')" ]; then
      # SC2154 doesn't seem to work on dockerfile.
      # shellcheck disable=SC2046
      if ! rx shellcheck -e SC1090,SC2148,SC2154,SC2250 $(git ls-files '*Dockerfile'); then
        should_fail=1
      fi
    fi
  else
    warn "'shellcheck' is not installed; skip shell script lint"
  fi
}

if [ -n "$(git ls-files '*.yaml')" ]; then
  error "please use '.yml' instead of '.yaml'"
  rx git ls-files '*.yaml'
fi

tidy_rust_files
tidy_c_files
tidy_prettier
tidy_markdown
tidy_shell

if [ -n "${should_fail:-}" ]; then
  error "errors or warning emitted; returning 1"
  exit 1
fi
