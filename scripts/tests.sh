#!/usr/bin/env bash

export TERM=xterm-color

if ! command -v nvim &> /dev/null; then
  echo "nvim is not installed"
  exit 1
fi

case "${1:-run}" in
  "run")
    shift
    ./minit_test.sh "$@"
    ;;
  *)
    echo "Usage: $0 [run]"
    exit 1
    ;;
esac
