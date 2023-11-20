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


run_cargo_tests() {
  # Run basic tests for the current OS.
  rx_cargo build --all --all-targets "$@"
  rx_cargo test "$@"

  # Run checks for Windows.
  np rustup target add x86_64-pc-windows-gnu
  np rustup component add clippy
  rx_cargo clippy --all --target x86_64-pc-windows-gnu "$@"

  # Run checks for macOS.
  np rustup target add x86_64-apple-darwin
  rx_cargo clippy --all --target x86_64-apple-darwin "$@"

  # Run checks for WASM.
  np rustup target add wasm32-unknown-unknown
  rx_cargo clippy --all --target wasm32-unknown-unknown "$@"

  # Run documentation checks.
  rx_cargo doc --no-deps --document-private-items "$@"

  cargo clean
}

if ! np command -v rustup; then
  bail "rustup not found on the system"
fi
if ! np command -v cargo; then
  bail "cargo not found on the system"
fi

# Just test the default feature-set and the feature-less set.
run_cargo_tests
run_cargo_tests --no-default-features

# Run other feature sets as well.
for featureset in "$@"; do
  run_cargo_tests --no-default-features --features "$featureset"
done
