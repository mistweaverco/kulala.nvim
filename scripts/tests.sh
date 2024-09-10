#!/usr/bin/env bash

run() {
  nvim --version
  if [[ -n $1 ]]; then
    nvim -l tests/minit.lua tests --filter "$1"
  else
    nvim -l tests/minit.lua tests
  fi
}

main() {
  local action="$1"
  shift
  local args=$*
  case $action in
    "run")
      run "$args"
      ;;
    *)
      echo "Invalid action"
      exit 1
      ;;
  esac

}
main "$@"
