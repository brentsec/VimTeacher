---
summary: Semantic versioning policy and release bump rules for this repository.
read_when:
  - Preparing a release
  - Deciding whether a change is patch, minor, or major
status: active
---

# Semantic Versioning

## Purpose

Define how this repository assigns and increments release versions.

## Version Format

Releases use annotated git tags in the format:

```bash
vMAJOR.MINOR.PATCH
```

Examples:

- `v0.1.16`
- `v0.2.0`
- `v1.0.0`
- `v1.2.0-rc.1`

This repository does not currently maintain a separate version file. The release tag is the canonical published version.

Tags must represent released plugin versions, not routine commits or pushes.

Do not create a new version only because code was pushed, merged, or refactored. Create a new version only when publishing a new release.

## Public API For This Repository

Semantic Versioning depends on a clear public API.

For this repository, the public API includes documented user-facing behavior such as:

- the `:VimTeacher` command and any documented command arguments
- documented `require("vimteacher").setup()` options
- documented keymapping behavior and adaptive-keymapping behavior
- documented lesson availability and intentional lesson behavior
- documented stats, scoring, timing, validation, completion, and menu behavior that users can rely on

Internal module layout, private helper functions, tests, and implementation details are not public API unless they are explicitly documented as supported extension points.

## Standard SemVer Rules

Semantic Versioning uses `MAJOR.MINOR.PATCH`.

- Increase `MAJOR` for incompatible public API changes.
- Increase `MINOR` for backward-compatible new functionality in the public API.
- Increase `PATCH` for backward-compatible bug fixes.

When incrementing:

- `MINOR` resets `PATCH` to `0`.
- `MAJOR` resets both `MINOR` and `PATCH` to `0`.
- A released version is immutable. If contents change, release a new version.

## Pre-1.0 Policy

This project is currently pre-1.0 and uses `0.y.z`.

SemVer treats `0.y.z` as initial development and does not consider the API stable. To keep versions meaningful in this repository, use this project policy while `MAJOR` is `0`:

- Increase `PATCH` for backward-compatible bug fixes only.
- Increase `MINOR` for any new public functionality.
- Increase `MINOR` for any intentional public behavior change that is not strictly a backward-compatible bug fix.
- Increase `MINOR` for removals, renames, deprecations, or compatibility risks in public behavior.

This keeps pre-1.0 releases predictable:

- `0.1.3` -> `0.1.4`: backward-compatible fix only
- `0.1.3` -> `0.2.0`: new functionality or any public behavior change

Do not infer readiness for `1.0.0` from the version history alone. Continue using `0.y.z` until the project owner explicitly decides the plugin is ready for its first stable release.

## Stable Policy

Once the project owner explicitly approves `1.0.0`, use standard SemVer rules without the pre-1.0 simplification:

- `PATCH`: backward-compatible bug fixes
- `MINOR`: backward-compatible new functionality and deprecations
- `MAJOR`: incompatible public API changes

## Bump Decision Table

Choose the next version by classifying the net effect of the release since the last tag.

| Change type | Next version |
| --- | --- |
| Backward-compatible bug fix in existing public behavior | Patch |
| New lesson | Minor |
| New command, setup option, mapping capability, or documented UI capability | Minor |
| Deprecation of a public option or behavior after `1.0.0` | Minor |
| Intentional public behavior change while still on `0.y.z` | Minor |
| Removal, rename, or incompatible public behavior change while still on `0.y.z` | Minor |
| Stable-line incompatible change after `1.0.0` | Major |

Notes:

- Refactors, tests, docs, and tooling changes do not require a release by themselves.
- If such changes are included in a release for another reason, they do not change the required bump.
- If multiple change types are present, use the highest required bump.

## What Counts As Public Behavior

Treat a change as public if it changes what a plugin user can do, configure, observe, or depend on.

Examples in this repository:

- adding a lesson
- adding a new setup option
- changing command behavior
- changing adaptive keymap behavior in a way users notice
- changing stats, scoring, timing, or completion behavior intentionally
- changing highlights or menu behavior intentionally

Do not treat the following as user-facing by themselves:

- moving code between modules
- adding shared helpers
- increasing test coverage
- formatting, lint, or comment cleanup
- docs reorganization

## Release Rule

Do not default to patch bumps, and do not tag every merge or push.

Before creating a new tag:

1. Compare the release contents against the previous tag.
2. Identify the highest-impact public API change in that diff.
3. If there is no release-worthy change, do not create a tag.
4. If the release contains only backward-compatible bug fixes, bump `PATCH`.
5. If the release contains new public functionality, bump `MINOR`.
6. If the release contains incompatible public API changes and the project is on `1.y.z` or later, bump `MAJOR`.
7. If the project is still on `0.y.z`, use `MINOR` for any public behavior change that is not strictly a backward-compatible bug fix.
8. Do not create `v1.0.0` unless the project owner has been notified and has explicitly approved the first stable release.

## Repository-Specific Guidance

Use `PATCH` only when the release is limited to backward-compatible bug fixes in existing behavior.

Examples:

- fix lesson timing so timing starts at the correct point
- fix a scoring bug without changing the documented feature set
- fix highlight behavior that was incorrect relative to the existing contract

Use `MINOR` when the release includes any new or intentionally changed public functionality.

Examples:

- a new lesson in `lua/vimteacher/lessons/`
- a new exported setup option in `require("vimteacher").setup()`
- a new user-visible command or menu capability
- an intentional scoring, timing, validation, or adaptive-keymapping behavior change that affects users
- a deprecation after `1.0.0`

## Release Checklist

Before tagging:

1. Read the commits and diff since the previous tag.
2. Classify the release as `PATCH`, `MINOR`, or `MAJOR` using this document.
3. Confirm the chosen version is the highest required bump for any included change.
4. Run `mise run verify`.
5. If the proposed release is `v1.0.0`, stop and get explicit approval from the project owner before tagging.
6. Create an annotated tag using the `vX.Y.Z` format.

For pre-releases, append a SemVer pre-release identifier to the target version:

- `v0.2.0-rc.1`
- `v1.0.0-beta.1`

Use pre-release tags for validation or testing before the final release. Do not use build metadata in release tags unless there is a concrete distribution need.

## Examples From This Policy

- Fix lesson timing bug: patch
- Add integration tests only: no release required
- Split code into helper modules without behavior change: no release required unless bundled with another release-worthy change
- Add a macro lesson: minor
- Add a new adaptive keymap option: minor
- Change completion scoring intentionally while still on `0.y.z`: minor
- Rename or remove a public setup option while still on `0.y.z`: minor
- The repository has accumulated many minor releases and appears mature: still not enough by itself to release `1.0.0`
- Remove or rename a public setup option after `1.0.0`: major
