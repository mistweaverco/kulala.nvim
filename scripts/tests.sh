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

  echo "Installing Formatters ===================================="
  apt-get update -y
  apt-get install -y jq
  apt-get install -y libxml2-utils
  npm install -g prettier

  echo "Installing Node packages ===================================="
  cd ./tests/functional/scripts
  npm install
  cd ../../..

  echo "Installing Tools ===================================="
  apt-get install -y gh

  # echo "Installing kulala-fmt build dependencies ===================================="
  # apt-get update -y
  # apt-get install -y python3-pip build-essential
}

run() {
  nvim --version
  if [[ -n $1 ]]; then
    nvim -l tests/minit.lua tests --filter "$1"
  else
    nvim -l tests/minit.lua tests --shuffle-tests -o utfTerminal -Xoutput --color -v
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
