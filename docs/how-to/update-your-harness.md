---
title: "How to update your harness safely"
diataxis_type: how-to
---

# How to update your harness safely

`scripts/update.sh` is the **only supported way** to pull later template
improvements into an already-instantiated clone. It verifies the provenance of
the target release **before any template content is applied to your clone**, and is
**fail-closed**: a verification miss aborts the update and nothing is applied.
(The target tag is fetched into a throwaway temp repo to reproduce and verify the
release artifact; your clone is never touched — `copier update` is not invoked —
unless verification passes.)

Do **not** run `copier update` directly — that bypasses the provenance gate and
executes template `_tasks`/`_migrations` under `--trust` against an unverified
source.

## Prerequisites

- `git`, the GitHub CLI (`gh`) with `gh auth login` completed, `copier`, `gzip`,
  and `yq` on `PATH`.
- A **clean work tree** — commit or stash local changes first (`copier update`
  re-applies a diff and needs a clean tree).
- The upstream publishes an attested release (the template's `release.yml` does
  this automatically on every published release).

## Update

From the clone root:

```bash
bash scripts/update.sh
```

It will:

1. Resolve the latest release tag of the **pinned upstream template** and pin it to
   a concrete commit SHA. (The trust root — repository + release-workflow identity —
   is baked into `update.sh`, not taken from `.copier-answers.yml`.)
2. Reproduce the release artifact from that tree and verify its SLSA
   build-provenance attestation, pinned to the repository **and** the release
   workflow identity (`gh attestation verify … --signer-workflow …`). If the
   local reproduction misses verification, it falls back to the signed release
   asset and verifies that the extracted content matches the pinned commit.
3. On success only: run `copier update --vcs-ref <verified-sha>` — so Copier applies
   exactly the bytes that were verified (a git SHA is content-addressed, so the applied
   content is the verified content regardless of which path `_src_path` names). Then, if
   your clone's recorded `_src_path` lags an org move, **heal it** to the pinned upstream
   in `.copier-answers.yml` so future runs target it directly rather than relying on the
   redirect — that one-line rewrite lands in the same update diff you review and commit.
   (The heal must run *after* `copier update`, which refuses a dirty work tree.)

To update to a specific tag, or to pass extra Copier flags:

```bash
bash scripts/update.sh --target v1.2.3 -- --defaults
```

## When verification fails

A non-zero exit means **nothing was applied**. `update.sh` already handles the
reproducibility-mismatch case by verifying the downloaded signed release asset
and content-checking it against the pinned commit. So if it still exits non-zero,
the release either is not attested by the trusted release workflow, the expected
asset was missing, or the release asset's extracted content did not match the
pinned commit. See
[update-channel provenance model](../explanation/update-channel-provenance.md).

## Why this is the only supported path

The whole value of `copier update` over a snapshot engine is that it re-applies
template improvements to a live clone — but that channel runs template-supplied
code under `--trust`. The provenance gate is what *earns* that trust. Running it
in front of every update closes the one source-activity path the harness would
otherwise trust implicitly: its own update channel.
