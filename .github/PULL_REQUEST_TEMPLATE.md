## Description

Briefly describe what this PR does

> [!NOTE]
> Please open your PR against `develop` branch.  It will be merged into develop and in ~5-7 days merged into main 
> as part of `Weekly updates PR`.

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring
- [ ] Tree-sitter grammar change

## Checklist

- [ ] I have read the [CONTRIBUTING.md](../CONTRIBUTING.md) guidelines
- [ ] Code follows the project style (run `./scripts/lint.sh check-code`)
- [ ] Tests pass locally (`make test`)
- [ ] Documentation is updated (if applicable)
- [ ] Docs follow the style guide (run `./scripts/lint.sh check-docs`)

> [!NOTE]
> Neovim help files will be generated automatically from `.md` documentation, so no need to edit `.txt` files manually.

### If this PR includes tree-sitter grammar changes:

- [ ] Updated version in `lua/tree-sitter/tree-sitter.json`
- [ ] Built tree-sitter (`tree-sitter generate && tree-sitter build`)
- [ ] Verified no parse errors in HTTP files
- [ ] Did NOT auto-update tree snapshots (only update when explicitly requested)

## Related Issues

Link any related issues: Fixes #123, Closes #456
