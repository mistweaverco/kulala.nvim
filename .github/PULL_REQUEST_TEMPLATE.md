## Description

Briefly describe what this PR does

> [!NOTE]
> Please open your PR against the `main` branch.

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring
- [ ] Tree-sitter grammar change

## Checklist

- [ ] I have read the [CONTRIBUTING.md](../CONTRIBUTING.md) guidelines
- [ ] Code follows the project style (run `./scripts/lint.sh code`)
- [ ] Tests pass locally (`./minitest.sh`)
- [ ] Documentation is updated (if applicable)
- [ ] Docs follow the style guide (run `./scripts/lint.sh docs`)

### If this PR includes tree-sitter grammar changes:

- [ ] Updated version in `lua/tree-sitter/tree-sitter.json`
- [ ] Built tree-sitter (`tree-sitter generate && tree-sitter build`)
- [ ] Verified no parse errors in HTTP files
- [ ] Did NOT auto-update tree snapshots (only update when explicitly requested)

## Related Issues

Link any related issues: Fixes #123, Closes #456
