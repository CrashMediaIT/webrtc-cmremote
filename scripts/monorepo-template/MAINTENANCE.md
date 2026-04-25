# Maintenance Guide for webrtc-cmremote — `cmremote/v0.17.0-aws-lc-rs` (monorepo fork)

This document is the sibling of [`MAINTENANCE.md` on `main`](https://github.com/CrashMediaIT/webrtc-cmremote/blob/main/MAINTENANCE.md) for the **monorepo fork** branch (`cmremote/v0.17.0-aws-lc-rs`), per [ADR 0001 Step 18](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-spike-fork-instructions.md).

> **Scope:** This guide covers the `cmremote/v0.17.0-aws-lc-rs` branch, which forks the full `webrtc-rs/webrtc@v0.17.0` workspace (`webrtc/`, `dtls/`, `stun/`, `turn/`) with `ring` swapped for `aws-lc-rs`. The dtls-only `cmremote/v0.5.4-aws-lc-rs` branch and its `v0.5.4-cmremote.1` tag are immutable and are documented on `main`.

## Purpose

This branch exists so CMRemote's `agent-rs/` workspace can consume a `ring`-free WebRTC stack via four sibling `[patch.crates-io]` entries against the `v0.17.0-cmremote.1` tag (Step 17). The `ring` ban in `agent-rs/deny.toml` is workspace-wide and untouched.

## Initial Seeding (Steps 10–14)

Don't follow the ADR's hand-typed Steps 10–14 commands; use the automated runbook on `main` instead:

```bash
git checkout main
scripts/seed-monorepo-branch.sh --test
```

The script performs Steps 10–14 deterministically (creates the branch from `webrtc-rs/webrtc@v0.17.0` with disjoint history, applies the four scoped sed substitutions, edits the four `Cargo.toml` files, installs this `MAINTENANCE.md` and the workspace-scoped CI workflow, and optionally runs `cargo test --workspace`). It then prints the exact Step 15 push and Step 16 tag commands.

## Rebase Cadence

### Trigger 1: Upstream Minor Releases

**When:** Every upstream `webrtc-rs/webrtc` minor or patch release.

**Process:**

1. Re-run the seeding script against the new upstream tag. Edit `UPSTREAM_TAG` and `FORK_BRANCH` at the top of `scripts/seed-monorepo-branch.sh` (or pass them as env overrides if you've extended the script), then:

   ```bash
   git checkout main
   scripts/seed-monorepo-branch.sh --force --test
   ```

   `--force` is required because the rebase is a re-seed, not a fast-forward — the disjoint-history guarantee in ADR 0001 §10 means there is no commit-level continuity between successive `cmremote/v<NEW>-aws-lc-rs` branches.

2. If the script's TOML edits fail with "expected line not found", upstream has rearranged a `Cargo.toml`. Update the literal strings in the script's `python3 - <<PY` block to match the new upstream shape; do **not** loosen the matchers to substring/regex (the strict-match exists so silent drift never leaks into a cmremote tag).

3. Verify the lockfile is free of the banned crates (CI enforces this in the `no-banned-crates` job, but check locally before tagging):

   ```bash
   ! cargo tree --workspace -i ring
   ! cargo tree --workspace -i webpki
   ```

   Note: unlike the dtls v0.5.4 branch, **`rustls` is NOT banned here** — Step 11 keeps it with the `aws_lc_rs` feature instead of `ring`.

4. Verify cross-compilation on all five target triples (CI runs this on push).

5. Tag the new version (Step 16):

   ```bash
   git tag -a v<NEW>-cmremote.1 -m "CMRemote v<NEW> monorepo fork: ring -> aws-lc-rs in webrtc/, dtls/, stun/, turn/"
   git push origin v<NEW>-cmremote.1
   ```

6. Update the four `[patch.crates-io]` entries in `CMRemote/agent-rs/Cargo.toml` to reference the new tag (Step 17). See the ADR's note about the `{ git, tag, path }` shape — Cargo doesn't accept `path` alongside `git`+`tag` for source replacement of a registry crate, so the agent-side PR will likely use one entry per sub-crate without `path`, or move to per-sub-crate registry packaging in this monorepo.

### Trigger 2: Security Advisories

**When:** Any security advisory affecting:

- `aws-lc-rs` or its dependencies
- `rustls`, `rcgen`, or `webrtc-util`
- The WebRTC RFC stack: RFCs 5389 (STUN), 5763, 5764, 5766 (TURN), 6347 (DTLS 1.2), 6904, 8261

**Process:**

- Perform an out-of-band rebase regardless of upstream cadence
- Follow the same process as Trigger 1
- Increment the `-cmremote.<rev>` version number if rebasing from the same upstream version

### Trigger 3: Upstream Repo Switch

**When:** An upstream `webrtc-rs/rtc` v0.20.x release lands.

Re-run the slice R7.l audit against the new repo and decide whether the v0.17 monorepo fork supersedes or coexists. This is a **maintainer decision**, not a mechanical rebase; do not auto-port.

## Version Naming Convention

Tags follow the pattern: `v<upstream-version>-cmremote.<rev>`

- `<upstream-version>`: The upstream `webrtc-rs/webrtc` version (e.g., `0.17.0`)
- `<rev>`: CMRemote revision number, incremented for each CMRemote-side change
  - Increment `.1` → `.2` when making changes without rebasing upstream
  - Reset to `.1` when rebasing to a new upstream version

## Ownership

**Maintainers:** `agent-rs/` CMRemote CODEOWNERS (per [ADR 0001 Question 3](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-webrtc-crypto-provider.md))

All changes to this branch require approval from the same reviewers who own the `agent-rs/` workspace in the CMRemote repository. The branch is protected by the `cmremote/*` rule in [`GITHUB_SETTINGS.md`](https://github.com/CrashMediaIT/webrtc-cmremote/blob/main/GITHUB_SETTINGS.md) §4a.

## Failure Mode

If at any point:

- The fork cannot build on all five target triples (`x86_64-pc-windows-msvc`, `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu`, `x86_64-apple-darwin`, `aarch64-apple-darwin`)
- Any of the four scoped sed substitutions stops being mechanical (e.g., upstream introduces `ring::aead::` or another module not in the substitution list)
- A workspace dependency requires re-implementing cryptographic primitives

Then **stop** and re-evaluate Option C (embedded DTLS) or Option L1 (one fork per sub-crate) per the parent ADR's failure path. Do **not** silently fall back to Option A (admitting `ring`) without a fresh decision and new ADR.

## Related Documentation

- [ADR 0001: WebRTC Crypto Provider](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-webrtc-crypto-provider.md)
- [Fork Creation Instructions §§10–18](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-spike-fork-instructions.md)
- [Crate Graph Audit (slice R7.l)](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-webrtc-crate-graph-audit.md)
- [Sibling MAINTENANCE.md for the dtls v0.5.4 branch](https://github.com/CrashMediaIT/webrtc-cmremote/blob/main/MAINTENANCE.md)
