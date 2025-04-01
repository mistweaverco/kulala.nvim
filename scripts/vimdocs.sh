#!/usr/bin/env bash

PANDOC_DIR=./scripts/pandoc
PROJECT_NAME=kulala.nvim
VIM_VERSION="Neovim >= 0.8.0"
TOC=true
DESCRIPTION="A fully-featured REST Client Interface for Neovim."
DEDUP_SUBHEADINGS=true
TREESITTER=true

CMD="$PANDOC_DIR/panvimdoc.sh --vim-version \"$VIM_VERSION\" --toc $TOC --description \"$DESCRIPTION\" --dedup-subheadings $DEDUP_SUBHEADINGS --treesitter $TREESITTER --scripts-dir $PANDOC_DIR"

process_file() {
  local file=$1
  local project_name=$2
  local extra_flags=$3
  local cmd="$CMD --project-name \"$project_name\" --input-file \"$file\""

  echo "Processing $file as project $project_name"
  eval "$cmd $extra_flags"
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

process_files ./docs/docs 10 "*.md"
process_files . 1 "*.md"
process_files ./docs/docs 10 "*.mdx" "--include-imports true"

nvim -c "helptags doc" -c "quit"
