# Auto-detect new psycopg releases

**Date:** 2026-06-10
**Status:** Approved (pending spec review)

## Problem

The psycopg wheel built in this repo lags behind upstream because bumping it is
a fully manual chore: someone has to notice a PyPI release, edit the version,
and dispatch `build-psycopg.yml` by hand. We want new psycopg releases to surface
automatically as a reviewable PR.

## Decisions

- **Detection:** scheduled GitHub Actions workflow polling PyPI's JSON API.
- **Action on new version:** open a PR bumping the version (human reviews/merges).
- **Scope:** psycopg only. (zxing-cpp is no longer used, they ship aarch64 wheels
  directly, so it is intentionally excluded.)
- **Build around the PR:** the detection job dispatches the existing
  `build-psycopg.yml` in `testing` mode (build only, no release) against the PR
  branch, so a green build is visible before merge. The real release stays a
  deliberate, manual dispatch after merge.
- **Cadence:** monthly, to line up with the project's monthly Dependabot cadence.
- **Debian release:** `trixie` (the main repo's Docker image is now on Trixie).

## Source of truth for "current version"

The current version is not recorded in a single place today:

- `psycopg.dockerfile` -> `ARG PSYCOPG_VERSION` has no default.
- `build.sh` -> `build_psycopg` defaults to `3.2.5` (stale).
- `build-psycopg.yml` -> `version` input default is `3.2.12` (stale).
- GitHub release tags are the real "what we shipped" record.

**Authoritative signal: the highest version across all `psycopg-*` GitHub release
tags.** Tags come in two shapes:

- `psycopg-<version>` (older, e.g. `psycopg-3.2.5`)
- `psycopg-<debian>-<version>` (current, e.g. `psycopg-bookworm-3.2.12`,
  `psycopg-trixie-3.3.0`)

All new tags will always include the debian suite
(`psycopg-<suite>-<version>`); the bare `psycopg-<version>` shape only exists on
legacy tags. So parsing just grabs the trailing dotted version regardless of an
optional leading suite segment, e.g. regex `^psycopg-(?:[a-z]+-)?([0-9][0-9.]*)$`.
No special-casing beyond that is needed. At time of writing the ceiling to beat is
`3.3.0`.

The PR also syncs the two cosmetic defaults (`build.sh` and the `build-psycopg.yml`
input default) up to the new version so they stop drifting. These defaults are
convenience only; the build is always parameterized by the dispatched/typed
version.

## Flow

1. **Trigger:** `schedule` (monthly cron) plus `workflow_dispatch` for manual runs.
2. **Query PyPI:** `GET https://pypi.org/pypi/psycopg/json`. Take the latest
   **stable** release: skip pre-releases (PEP 440 `a`/`b`/`rc`/`dev`) and any
   release whose files are all yanked.
3. **Determine current ceiling:** list `psycopg-*` tags (via `gh` / git), parse
   each to a version, take the max.
4. **Compare** using numeric tuple ordering, not string compare. Detection logic
   lives in `scripts/check_psycopg_version.py` (stdlib only, no third-party
   dependency) so it is runnable and testable outside CI.
5. **Idempotency guard:** if PyPI latest is not strictly newer, exit quietly. If a
   branch `psycopg-update-<version>` or an open PR for that version already
   exists, exit quietly (do not reopen).
6. **Open PR:**
   - Branch: `psycopg-update-<version>`.
   - Edits: bump the `build_psycopg` default in `build.sh` only. The bot must
     **not** edit `.github/workflows/build-psycopg.yml`: `GITHUB_TOKEN` cannot
     push commits that modify workflow files (the `workflows` scope is not
     grantable to it), so including that edit makes the push fail. The
     `build-psycopg.yml` input default is just the prefilled value on the manual
     dispatch form and is allowed to drift.
   - PR body links the PyPI release page and the upstream changelog, and notes
     that the real release must be dispatched manually after merge.
7. **Test build:** the detection job runs
   `gh workflow run build-psycopg.yml --ref psycopg-update-<version>
-f version=<version> -f debian-release=trixie -f testing=true`
   and links the run from the PR.
8. **Human:** reviews the PR, confirms the test build is green, merges, then
   manually dispatches `build-psycopg.yml` for the real release as today.

## Why dispatch the test build explicitly

PRs created with the default `GITHUB_TOKEN` do not emit `pull_request`/`push`
events that would trigger other workflows. So a `pull_request` trigger on the
build would never fire for these bot PRs. Having the detection job call
`gh workflow run` explicitly sidesteps that limitation and requires zero changes
to `build-psycopg.yml`.

## What changes

- **New file:** `.github/workflows/detect-psycopg-update.yml` (the workflow).
- **New file:** `scripts/check_psycopg_version.py` (the detection logic).
- **Defaults synced to current reality** as part of this change:
  `psycopg.dockerfile` `DEBIAN_RELEASE` default `bookworm` -> `trixie`, `build.sh`
  default `3.2.5` -> `3.3.0`, and `build-psycopg.yml` version default `3.2.12` ->
  `3.3.0` with `trixie` first in the release dropdown.
- **`build-psycopg.yml` hardened:** its `run` blocks now reference the shell env
  vars (`${INPUTS_VERSION}`, `${DEBIAN_RELEASE}`) instead of `${{ env.* }}`
  expansions, clearing pre-existing zizmor `template-injection` findings that the
  version-bump otherwise dragged into scope.
- **Permissions** on the new workflow: `contents: write` (push the branch),
  `pull-requests: write` (open the PR), `actions: write` (dispatch the test build).
  Note `GITHUB_TOKEN` has no `workflows` scope, so the bot branch must avoid
  editing any file under `.github/workflows/` (see Flow step 6).

## Out of scope (noted, not done here)

- Removing the now-unused `zxing.dockerfile` and `build-zxing.yml`.
- Applying the same auto-detection pattern to other tools (qpdf, ghostscript,
  jbig2enc track Debian Trixie / GitHub releases, not PyPI, so they need different
  detection sources).

## Testing

- `workflow_dispatch` on the detection workflow lets us run it on demand to verify
  end to end without waiting for the cron.
- Verify the idempotency guards: a second run with no new version must be a no-op,
  and a run where the branch/PR already exists must not duplicate it.
- Verify version parsing against all three tag shapes present in the repo
  (`psycopg-3.2.5`, `psycopg-bookworm-3.2.12`, `psycopg-trixie-3.3.0`).
- Confirm the dispatched test build runs in `testing` mode and produces no release.
