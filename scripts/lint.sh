#!/usr/bin/env bash

set -eo pipefail

check_code() {
  if ! command -v stylua &> /dev/null; then
    echo "stylua is not installed"
    exit 1
  fi
  if ! command -v luacheck &> /dev/null; then
    echo "luacheck is not installed"
    exit 1
  fi
  if [[ -n $1 ]]; then
    stylua --check "$1"
    luacheck --formatter plain "$1"
  else
    stylua --check .
    luacheck --formatter plain lua
  fi
}

check_docs() {
  if ! command -v vale &> /dev/null; then
    echo "vale is not installed"
    exit 1
  fi
  cd docs || exit 1
  if [[ -n $1 ]]; then
    vale "$1"
  else
    vale .
  fi
}

main() {
  local action="$1"
  if [[ -z $action ]]; then
    check_code
    check_docs
    return
  fi
  shift
  local args=$*
  case $action in
    "code")
      check_code "$args"
      ;;
    "docs")
      check_docs "$args"
      ;;
    *)
      echo "Invalid action"
      exit 1
      ;;
  esac

}
main "$@"
