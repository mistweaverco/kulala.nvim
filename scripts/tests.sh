#!/usr/bin/env bash

export TERM=xterm-color

if ! command -v nvim &> /dev/null; then
  echo "nvim is not installed"
  exit 1
fi

run() {
  nvim --version
  if [[ -n $1 ]]; then
    nvim -l tests/minit.lua tests --filter "$1"
  else
    nvim -l tests/minit.lua tests --shuffle-tests -o utfTerminal -Xoutput --color -v
  fi
}

case "${1:-run}" in
  "run")
    shift
    run "$*"
    ;;
  *)
    echo "Usage: $0 [run] [filter]"
    exit 1
    ;;
esac
