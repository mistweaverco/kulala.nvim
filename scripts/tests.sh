#!/usr/bin/env bash

export TERM=xterm-color

if ! command -v nvim &> /dev/null; then
  echo "nvim is not installed"
  exit 1
fi

install_dependencies() {
  echo "Installing NVM ===================================="
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

  nvm -v

  echo "Installing NPM ===================================="
  nvm install --lts
  npm -v

  echo "Installing JQ ===================================="
  yes | apt-get install jq

  echo "Installing Node packages ===================================="
  cd ./tests/functional/scripts
  npm install
  cd ../../..
}

run() {
  nvim --version
  if [[ -n $1 ]]; then
    nvim -l tests/minit.lua tests --filter "$1"
  else
    nvim -l tests/minit.lua tests --shuffle-tests -o utfTerminal -Xoutput --color
  fi
}

main() {
  local action="$1"
  shift

  local args=$*

  case $action in
    "run")
      install_dependencies
      run "$args"
      ;;
    *)
      echo "Invalid action"
      exit 1
      ;;
  esac
}

main "$@"
