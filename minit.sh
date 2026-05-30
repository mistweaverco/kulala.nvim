#!/usr/bin/env bash

if [ -z "$PLUGINS" ] && [ -z "$USE_DIR" ]; then
  echo "PLUGINS environment variable required. Example:"
  echo "PLUGINS='https://github.com/mistweaverco/kulala.nvim;kulala' $0"
  echo ".. separate multiple plugins with a space, and use the format 'repo_url;plugin_name' for each plugin."
  exit 1;
fi

TMP_DIR="$USE_DIR"
if [ -z "$TMP_DIR" ]; then
  CURRENT_DATESTR=$(date +"%Y-%m-%d-%H-%M-%S")
  TMP_DIR=$(mktemp -t -d "tmp.nvim-isolation-${CURRENT_DATESTR}-XXXXXXXX")
fi

{
  echo "#!/usr/bin/env bash"
  echo
  echo "export XDG_DATA_HOME=\"$TMP_DIR/data\""
  echo "export XDG_STATE_HOME=\"$TMP_DIR/state\""
  echo "export XDG_CACHE_HOME=\"$TMP_DIR/cache\""
  echo "export NVIM_REPRO_TMP_DIR=\"$TMP_DIR\""
  echo "export PLUGINS=\"$PLUGINS\""
  echo "nvim -u \"$TMP_DIR/minit.lua\" \"\$@\""
} > "$TMP_DIR/minit.sh"

chmod +x "$TMP_DIR/minit.sh"

cp minit.lua "$TMP_DIR/"

"$TMP_DIR/minit.sh" "$@"

echo "Neovim isolation"
echo "----------------"
echo
echo "To reuse the same isolation environment, run:"
echo "$TMP_DIR/minit.sh"
echo
echo "To clean up the temporary directory, run:"
echo "rm -rf $TMP_DIR"
echo
