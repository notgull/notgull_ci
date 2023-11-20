#!/bin/sh
# Push the docker image to hub.docker.com

rx() {
  cmd="$1"
  shift
  (
    set -x
    "$cmd" "$@"
  )
}

root="$(dirname -- "$(dirname -- "$0")")"

rx docker build \
  --file "docker/debian.Dockerfile" "$root" \
  --tag notgull/ci:stable
rx docker push notgull/ci:stable
