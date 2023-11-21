#!/bin/sh

set -eu

# Requires rustup, jq and yq

np() {
  cmd="$1"
  shift
  "$cmd" "$@" >/dev/null 2>/dev/null
}

base_dir="$(dirname -- "$(dirname -- "$0")")"
ver_database="$base_dir/rust-versions.json"

real_rust_version() {
  ver="$1"
  np rustup toolchain install "$ver" --profile minimal
  rustc +"$ver" --version | cut -d' ' -f2 | cut -d'-' -f1
}

versions="stable beta nightly"
for version in $versions; do
  real_version="$(real_rust_version "$version")"
  cur_version="$(jq -r ".$version" <"$ver_database")"

  # Update the version of rust in our setup if needed.
  if [ "$real_version" != "$cur_version" ]; then
    echo "[info]: rust version $version was $cur_version, is now $real_version"
    jq -r ".$version = \"$real_version\"" <"$ver_database" >"$ver_database.new"
  fi
done

if [ -e "$ver_database.new" ]; then
  mv "$ver_database.new" "$ver_database"
fi
