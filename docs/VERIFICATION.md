---
summary: Local verification policy and commit-to-main gate.
read_when:
  - Starting work in this repo
status: active
---

# VERIFICATION

## Purpose

Make direct commits safer via a consistent local gate.

## Commit Gate

Run before behavior changes are committed:

```bash
mise run verify
```

## Expected Verify Stages

`verify` depends on available tasks in this order:
`fmt`, `lint`, `test`, `build`, `smoke`, `docs:verify`.
