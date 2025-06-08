package tree_sitter_kulala_http_test

import (
	"testing"

	tree_sitter "github.com/tree-sitter/go-tree-sitter"
	tree_sitter_kulala_http "github.com/mistweaverco/kulala.nvim/lua/tree-sitter/bindings/go"
)

func TestCanLoadGrammar(t *testing.T) {
	language := tree_sitter.NewLanguage(tree_sitter_kulala_http.Language())
	if language == nil {
		t.Errorf("Error loading Kulala HTTP grammar")
	}
}
