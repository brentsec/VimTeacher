---
summary: Local setup and standard task usage for this project.
read_when:
  - Starting work in this repo
status: active
---

# DEVELOPMENT

## Purpose

Define local development workflow through `mise` tasks.

## Prerequisites

Run:

```bash
mise run docs:verify
```

## Common Tasks

Use:

```bash
mise run <task>
```

Standard tasks in this repo: `fmt lint test docs:verify docs:build verify`

If you need live module reloads while iterating on `:VimTeacher`, set
`vim.g.vimteacher_dev_reload = true` before launching the command.

## Release Versioning

Use the semantic versioning policy in `docs/reference/semantic-versioning.md` before creating a release tag.

Use:

```bash
mise run hooks:install
mise run release:tag -- <patch|minor|major|version ...>
```
