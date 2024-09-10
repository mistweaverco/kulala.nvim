#!/usr/bin/env bash

if ! command -v stylua &> /dev/null; then
  echo "stylua is not installed"
  exit 1
fi

check() {
  stylua --version
  if [[ -n $1 ]]; then
    stylua --check "$1"
  else
    stylua --check .
  fi
}

main() {
  local action="$1"
  shift
  local args=$*
  case $action in
    "check")
      check "$args"
      ;;
    *)
      echo "Invalid action"
      exit 1
      ;;
  esac

}
main "$@"
