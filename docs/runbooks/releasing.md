---
summary: Release tagging workflow for this repository.
read_when:
  - Preparing a release
  - Installing local hooks
status: active
---

# Releasing

## Purpose

Define the local release-tagging workflow.

## Hook Setup

Install the repository-managed local hooks with:

```bash
mise run hooks:install
```

These hooks do not create tags automatically. Routine commits and pushes remain untagged unless a release is being published.

## Release Flow

1. Read `docs/reference/semantic-versioning.md`.
2. Decide whether the release is `patch`, `minor`, `major`, or an explicit pre-release version.
3. Ensure the worktree is clean.
4. Run one of the explicit release commands:

```bash
mise run release:tag -- patch
mise run release:tag -- minor
mise run release:tag -- version v0.2.0-rc.1
```

5. If the release would be `v1.0.0`, notify the project owner and get explicit approval before tagging.
6. Push the commit and tag together.

## Notes

- Use `patch` only for backward-compatible bug-fix releases.
- Use `minor` for new functionality or intentional public behavior changes while the project is on `0.y.z`.
- The release command runs `mise run verify` before creating the tag.
- If verification changes files, stop, review those changes, and commit them before trying again.
