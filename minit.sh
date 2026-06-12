#!/usr/bin/env bash

PLUGIN_NAME=${PLUGIN_NAME:-"kulala"}
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS=${PLUGINS:-"file://$CURRENT_DIR;$PLUGIN_NAME"}

CURRENT_DATESTR=$(date +"%Y-%m-%d-%H-%M-%S")
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tmp.nvim-isolation-${CURRENT_DATESTR}.XXXXXX")

ADDITIONAL_USER_SCRIPT="$1"

if [[ -n "$ADDITIONAL_USER_SCRIPT" ]]; then
  if [[ ! -f "$ADDITIONAL_USER_SCRIPT" ]]; then
    echo "Error: Additional user script '$ADDITIONAL_USER_SCRIPT' not found."
    exit 1
  fi
  cp "$ADDITIONAL_USER_SCRIPT" "$TMP_DIR/"
  ADDITIONAL_USER_SCRIPT="$TMP_DIR/$(basename "$ADDITIONAL_USER_SCRIPT")"
  {
    echo "#!/usr/bin/env bash"
    echo
    echo "set -eo pipefail"
    echo
    echo "nvim -u \"$TMP_DIR/minit.lua\"" "-c 'source $ADDITIONAL_USER_SCRIPT'"
  } > "$TMP_DIR/minit.sh"
else
  {
    echo "#!/usr/bin/env bash"
    echo
    echo "set -eo pipefail"
    echo
    echo "nvim -u \"$TMP_DIR/minit.lua\""
  } > "$TMP_DIR/minit.sh"
fi


chmod +x "$TMP_DIR/minit.sh"

{
  echo "local vim = vim or {}"
  echo "vim.env = vim.env or {}"
  echo "vim.env.XDG_DATA_HOME = '$TMP_DIR/data'"
  echo "vim.env.XDG_STATE_HOME = '$TMP_DIR/state'"
  echo "vim.env.XDG_CACHE_HOME = '$TMP_DIR/cache'"
  echo "vim.env.XDG_CONFIG_HOME = '$TMP_DIR/config'"
  echo "vim.env.NVIM_REPRO_TMP_DIR = '$TMP_DIR'"
  echo "vim.env.PLUGINS = '$PLUGINS'"
  echo
} > "$TMP_DIR/minit.lua"
cat minit.lua >> "$TMP_DIR/minit.lua"

"$TMP_DIR/minit.sh"

if [ ! -t 0 ]; then
  echo "Non-interactive terminal detected. Cleaning up temporary directory..."
  rm -rf "$TMP_DIR"
  echo "Done."
  exit 0
fi
echo "Neovim isolation"
echo "----------------"
echo
echo "The isolation environment is located at: $TMP_DIR"
echo

echo -n "Do you want to keep the isolation environment for future use? (y/n): "
read -n 1 -r KEEP_ENV
echo
if [[ "$KEEP_ENV" != "y" && "$KEEP_ENV" != "Y" ]]; then
  echo "Cleaning up temporary directory..."
  rm -rf "$TMP_DIR"
  echo "Done."
  exit 0
fi
echo "To reuse the same isolation environment, run:"
echo "$TMP_DIR/minit.sh"
echo
echo "To clean up the temporary directory, run:"
echo "rm -rf $TMP_DIR"
echo
