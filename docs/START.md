---
summary: Quick orientation and reading path for this repository.
read_when:
  - Starting work in this repo
status: active
---

# START

## Purpose

Provide a predictable onboarding path for contributors.

## Documentation Layout

- `doc/` contains the Neovim help files that ship with the plugin and power `:help`.
- `docs/` contains contributor-facing project documentation such as architecture, development workflow, and verification notes.

## Read Order

1. `README.md`
2. `docs/DEVELOPMENT.md`
3. `docs/VERIFICATION.md`
4. `docs/runbooks/local-workflow.md`

## Common Commands

```bash
mise run docs:verify
mise run docs:build
mise run verify
```
