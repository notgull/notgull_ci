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
if find_str "$tagname" -E '^v[0-9]+.*$'; then
  # Success.
  exit 0
else
  # Error code 78 tells Drone CI to skip the rest of the steps.
  exit 78
fi

