---
summary: Day-to-day local workflow and command behavior.
read_when:
  - Starting work in this repo
status: active
---

# Local Workflow Runbook

## Daily Flow

1. Make a small change
2. Add or update tests if applicable
3. Run `mise run verify`
4. Commit

## Standard Commands

- `docs:verify`: validate docs layout and front matter
- `docs:build`: generate `.agent/*` indexes
- `verify`: run available quality gates
- Optional stack commands depend on adapter/capabilities
