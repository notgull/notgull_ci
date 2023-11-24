#!/bin/sh

# Check if the current commit is tagged as a new release.

rx() {
  cmd="$1"
  shift
  (
    set -ex
    "$cmd" "$@"
  )
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
info() {
  echo >&2 "[info]: $*"
}
find_str() {
  haystack="$1"
  shift
  grep -q "$@" <<EOF
$haystack
EOF
}

if ! np command -v git; then
  bail "Unable to find git"
fi

# Get the current git commit.
tagname="$(rx git name-rev --tags --name-only "$(git rev-parse HEAD)")"

# Check for a tag.
if ! find_str "$tagname" -E '^v[0-9]+.*$'; then
  # Not a release.
  info "'$tagname' is not a release -- exiting"
  exit 0
fi

# Make a release.
if ! np command -v tea; then
  fatal "tea command line tool not found"
fi
rx tea release create \
    --title "$tagname" \
    -n "TODO: describe changelog" \
    --tag "$tagname"
