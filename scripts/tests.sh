#!/usr/bin/env bash

# Copy from MIT licensed neotest plugin:
# https://github.com/nvim-neotest/neotest/blob/958a6bff41c7086fe8b46f7f320d0fd073cfc6a0/scripts/test

NVIM_DL_BASE="https://github.com/neovim/neovim/releases/download/"

prepare() {
  local version=$1

  if [[ ! -f _neovim/nvim ]] && [[ -n $version ]]; then
    mkdir -p _neovim && curl -sL -o _neovim/nvim "${NVIM_DL_BASE}${version}" && chmod +x _neovim/nvim
    _neovim/nvim --headless -c 'TSInstallSync lua | quit'
  fi
  if [[ ! -d ~/.local/share/nvim/site/pack/vendor/start/plenary.nvim ]]; then
    git clone --depth 1 \
      https://github.com/nvim-lua/plenary.nvim \
      ~/.local/share/nvim/site/pack/vendor/start/plenary.nvim
  fi
  if [[ ! -d ~/.local/share/nvim/site/pack/vendor/start/kulala.nvim ]]; then
    ln -s "$(pwd)" ~/.local/share/nvim/site/pack/vendor/start
  fi
}

run() {
  type _neovim/nvim && nvim() { _neovim/nvim "$@"; }

  local tempfile
  tempfile=$(mktemp)

  nvim --version

  if [[ -n $1 ]]; then
    nvim --headless --noplugin -u tests/init.vim -c "PlenaryBustedFile $1" | tee "${tempfile}"
  else
    nvim --headless --noplugin -u tests/init.vim -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init.vim'}" | tee "${tempfile}"
  fi

  # Plenary doesn't emit exit code 1 when tests have errors during setup
  errors=$(sed 's/\x1b\[[0-9;]*m//g' "${tempfile}" | awk '/(Errors|Failed) :/ {print $3}' | grep -v '0')

  if [[ -n $errors ]]; then
    echo "Tests failed"
    exit 1
  fi

  exit 0
}

main() {
  local action="$1"
  shift
  local args=$*
  case $action in
    "run")
      run "$args"
      ;;
    "prepare")
      prepare "$args"
      ;;
    *)
      echo "Invalid action"
      exit 1
      ;;
  esac

}
main "$@"
