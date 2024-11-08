#!/usr/bin/env bash

check_code() {
  if ! command -v stylua &> /dev/null; then
    echo "stylua is not installed"
    exit 1
  fi
  stylua --version
  if [[ -n $1 ]]; then
    stylua --check "$1"
  else
    stylua --check .
  fi
}

check_docs() {
  if ! command -v vale &> /dev/null; then
    echo "stylua is not installed"
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
  shift
  local args=$*
  case $action in
    "check-code")
      check_code "$args"
      ;;
    "check-docs")
      check_docs "$args"
      ;;
    *)
      echo "Invalid action"
      exit 1
      ;;
  esac

}
main "$@"
