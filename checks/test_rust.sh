#!/bin/sh
# shellcheck disable=SC2086

set -eu

# Expects cargo to be on the system

rx() {
  cmd="$1"
  shift
  (
    set -x
    "$cmd" "$@"
  )
}
rx_cargo() {
  rx cargo -vv "$@" --workspace
}
np() {
  cmd="$1"
  shift

  "$cmd" "$@" >/dev/null 2>/dev/null
}
bail() {
  echo >&2 "[fatal]: $*"
  exit 1
}
clippy_build() {
  rx_cargo clippy "$@"
  rx_cargo build "$@"
}

run_cargo_tests() {
  # Run basic tests for the current OS.
  rx_cargo build --all --all-targets "$@"
  rx_cargo test "$@"

  # Run checks for Windows.
  np rustup target add x86_64-pc-windows-gnu
  np rustup component add clippy
  clippy_build --all --target x86_64-pc-windows-gnu "$@"

  # Run checks for macOS.
  np rustup target add x86_64-apple-darwin
  rx_cargo clippy --all --target x86_64-apple-darwin "$@"

  # Run checks for WASM.
  np rustup target add wasm32-unknown-unknown
  clippy_build --all --target wasm32-unknown-unknown "$@"

  # Run documentation checks.
  rx_cargo doc --no-deps --document-private-items "$@"

  cargo clean
}

toolchain="${1:-stable}"
shift

if np command -v ensure_tool.sh; then
  ensure_tool.sh clang rust:"$toolchain"
fi

if ! np command -v rustup; then
  bail "rustup not found on the system"
fi
if ! np command -v cargo; then
  bail "cargo not found on the system"
fi

featuresets=""
for argument in "$@"; do
  case "$argument" in
  "--skip-ndf") skip_ndf=1 ;;
  *) featuresets="$featuresets $argument" ;;
  esac
done

# Just test the default feature-set and the feature-less set.
run_cargo_tests
if [ -z "${skip_ndf:-}" ]; then
  run_cargo_tests --no-default-features
fi

# Run other feature sets as well.
if [ -n "$featuresets" ]; then
  for featureset in $featuresets; do
    run_cargo_tests --no-default-features --features "$featureset"
  done
fi
