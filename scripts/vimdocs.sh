#!/usr/bin/env bash

set -o pipefail

PANDOC_DIR=./scripts/pandoc
PROJECT_NAME=kulala
VIM_VERSION="Neovim >= 0.8.0"
TOC=true

DEDUP_SUBHEADINGS=true
TREESITTER=true

CMD="$PANDOC_DIR/panvimdoc.sh --vim-version \"$VIM_VERSION\" --toc $TOC --description \"$DESCRIPTION\" --dedup-subheadings $DEDUP_SUBHEADINGS --treesitter $TREESITTER --scripts-dir $PANDOC_DIR"
PRE_CODE_BLOCKS="lua $PANDOC_DIR/normalize-code-blocks.lua"
PRE_CODE_IMPORTS="lua $PANDOC_DIR/include-imports.lua"

process_file() {
  local file=$1
  local project_name=$2
  local cmd="$CMD --project-name \"$project_name\"" # --input-file \"$file\""

  [ "$3" == "--include-imports" ] && cmd="$PRE_CODE_IMPORTS | $cmd"
  cmd="cat $1 | $PRE_CODE_BLOCKS | $cmd"

  echo "Processing $file as project $project_name"
  eval "$cmd"
}

process_files() {
  local dir=$1
  local depth=$2
  local search_pattern=$3
  local extra_flags=$4

  find "$dir" -maxdepth $depth -type f ! -name "todo.md" -name "$search_pattern" | while read -r file; do
      filename=$(basename "$file")
      project_name="$PROJECT_NAME.${filename%.*}"
      process_file "$file" "$project_name" "$extra_flags"
  done
}

if [ -n "$1" ]; then
  process_files . 10 "$1" "$2"
else
  process_files . 1 "NEWS.md"
  process_files . 1 "README.md"
  process_files ./docs/docs 10 "*.md"
  process_files ./docs/docs 10 "*.mdx" --include-imports
fi

nvim --headless -c "helptags doc" -c "quit"
