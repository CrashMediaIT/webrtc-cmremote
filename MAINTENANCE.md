# Maintenance Guide for webrtc-cmremote

This repository is a fork of [`webrtc-rs/dtls`](https://github.com/webrtc-rs/dtls) with the `ring` cryptography library replaced by `aws-lc-rs`. It is maintained as part of the [CMRemote project](https://github.com/CrashMediaIT/CMRemote).

> **Scope:** This guide covers two long-lived CMRemote-fork branches: `cmremote/v0.5.4-aws-lc-rs` (the dtls-only fork tagged `v0.5.4-cmremote.1`, ADR Steps 1–9) and `cmremote/v0.17.0-aws-lc-rs` (the monorepo fork tagged `v0.17.0-cmremote.1`, ADR Steps 10–18, covering `webrtc/`, `dtls/`, `stun/`, `turn/`). The two recipes share the same maintenance contract but the monorepo trigger surface is wider (RFCs 5389 and 5766 are added) and the substitution is per-sub-crate. See the [branch map in README.md](README.md#branch-map).

## Purpose

This fork exists to enable CMRemote's `agent-rs/` workspace to use WebRTC DTLS without depending on the `ring` crate, which is banned in the workspace per [ADR 0001](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-webrtc-crypto-provider.md).

## Maintainer one-time branch fix-up

> **Status (2026-04-25):** the two `v*-cmremote.*` tags are correct and immutable, but the `cmremote/*` long-lived branches that ADR 0001 §Step 10 calls for are not yet aligned with them. This section is the one-time recipe to fix that. It is **not** a routine maintenance trigger — once executed, future rebases follow the per-branch "Trigger 1" recipes below, which already push branch and tag together.

### Why this is needed

- `cmremote/v0.5.4-aws-lc-rs` currently points at upstream-plus-CODEOWNERS (`83236f8`), not the PR #2 fork commit. The tag `v0.5.4-cmremote.1` (`5ef4a82`) is on `main` instead.
- `cmremote/v0.17.0-aws-lc-rs` does not exist at all. The tag `v0.17.0-cmremote.1` (`2c1ab4f`) is on `main` instead — the agent that produced PR #4 could only push one branch.

Tag-based `[patch.crates-io]` consumers are unaffected (they address the immutable tag SHAs directly), so this is policy hygiene, not a consumption blocker.

### Procedure

1. **Run before enabling `cmremote/*` branch protection's force-push prohibition** (per [GITHUB_SETTINGS.md §4a](GITHUB_SETTINGS.md#4a-branch-protection-rules-for-cmremote-long-lived-branches)), or run it as an admin with bypass enabled. After this fix-up the branches will be immutable for real.

2. From a local clone with `origin = github.com/CrashMediaIT/webrtc-cmremote`:
   ```bash
   git fetch origin --tags

   # Realign the v0.5.4 branch onto its tag commit (force-update, replaces the upstream-only stub).
   git push origin +refs/tags/v0.5.4-cmremote.1^{commit}:refs/heads/cmremote/v0.5.4-aws-lc-rs

   # Create the v0.17 monorepo branch from its tag commit.
   git push origin refs/tags/v0.17.0-cmremote.1^{commit}:refs/heads/cmremote/v0.17.0-aws-lc-rs
   ```

3. Verify both branches now match their tags:
   ```bash
   git ls-remote origin refs/heads/cmremote/v0.5.4-aws-lc-rs   # expect 5ef4a82…
   git ls-remote origin refs/heads/cmremote/v0.17.0-aws-lc-rs  # expect 2c1ab4f…
   ```

4. Apply (or re-apply) the `cmremote/*` branch protection rule per [GITHUB_SETTINGS.md §4a](GITHUB_SETTINGS.md#4a-branch-protection-rules-for-cmremote-long-lived-branches).

### CI gating caveat for the existing `.1` tags

Both existing tags (`v0.5.4-cmremote.1` and `v0.17.0-cmremote.1`) were cut **before** the `ci` workflow concluded on either commit — every `ci` run on `main` is currently stuck in `queued` and has no `success`/`failure` outcome. This violates the ADR 0001 §"Step 4.5" / §Step 16 precondition that tagging be gated on green CI.

The runners need to be unblocked at the org/repo settings level (Settings → Actions → Runners; check that the `ubuntu-24.04-arm`, `macos-13`, and `macos-14` pools are enabled for the org). Once `ci` actually concludes:

- If green on the existing tag commits (`5ef4a82`, `2c1ab4f`), the `.1` tags are retroactively validated; no re-tag needed.
- If red and a fix has to land, cut `v<UPSTREAM>-cmremote.2` on the green commit per the standard "Trigger 1" recipe below. Bump the matching `tag = "..."` lines in `CMRemote/agent-rs/Cargo.toml` at the same time.

## Rebase Cadence — `cmremote/v0.5.4-aws-lc-rs` (dtls-only)

### Trigger 1: Upstream Minor Releases

**When:** Every upstream `webrtc-rs/dtls` minor or patch release.

**Process:**
1. Create a new branch from the upstream tag:
   ```bash
   git fetch upstream --tags
   git checkout -b cmremote/v<NEW>-aws-lc-rs v<NEW>
   ```

2. Re-apply the symbol substitution (mechanical sed patch). The runbook ships
   this snippet, but only `src/crypto/mod.rs` actually contains `ring::`
   symbols in `webrtc-dtls@v0.5.4`:
   ```bash
   git ls-files 'src/**/*.rs' | xargs sed -i \
       -e 's|use ring::|use aws_lc_rs::|g' \
       -e 's|ring::signature::|aws_lc_rs::signature::|g' \
       -e 's|ring::rand::|aws_lc_rs::rand::|g'
   ```

3. Verify no real `ring` references remain. **Do not** use the runbook's
   `! grep -rn 'ring' src/` — it false-positives on `String::`, `Ordering::`,
   `from_utf8`, `server_name`, etc. Use a word-boundary check instead:
   ```bash
   ! grep -rn -E '\b(use ring|ring::|extern crate ring)\b' src/
   ```

4. Update dependencies in `Cargo.toml`:
   - Remove `ring` dependency
   - Ensure `aws-lc-rs = "1"` is present
   - Update `rcgen` to use `aws_lc_rs` feature (rcgen ≥ 0.13)
   - Drop `rustls` and `webpki` entirely. The fork ships an internal
     `crate::pki` module that provides the type-shape `webrtc-dtls` needs
     (`Certificate`, `RootCertStore`, `Server/ClientCertVerifier`,
     `WebPKIVerifier`, `AllowAnyAuthenticatedClient`); the `WebPKIVerifier`
     and `AllowAnyAuthenticatedClient` defaults are intentional placeholders
     because CMRemote's WebRTC stack always installs an SDP-fingerprint
     `verify_peer_certificate` callback (RFC 8122).
   - Pin `x25519-dalek = "=2.0.0-pre.1"` exactly. Upstream wrote
     `"2.0.0-pre.1"`, but Cargo SemVer-matches `2.0.1` (current 2.x stable),
     where `StaticSecret` was renamed and the build breaks.

5. Run the test suite:
   ```bash
   cargo build
   cargo test
   cargo clippy --all-targets -- -D warnings
   cargo fmt -- --check
   ```

   Two upstream tests are marked `#[ignore]` in this fork because they
   exercise the `WebPKIVerifier` defaults the fork dropped:
   `conn::conn_test::test_client_certificate` and
   `conn::conn_test::test_server_certificate`. Confirm the *count* of
   ignored tests still matches expectations after a rebase; if upstream adds
   new tests against the verifier defaults, mark them too.

5a. Verify the lockfile is free of the banned crates (this is the hard
    precondition for tagging per ADR 0001 §"Step 4.5"). The CI workflow
    enforces this in the `no-banned-crates` job. Note `cargo tree -i <pkg>`
    exits 0 with a stderr warning when the package is absent, so compare
    stdout to an empty string rather than relying on the exit code:
   ```bash
   [ -z "$(cargo tree -i ring    2>/dev/null)" ]
   [ -z "$(cargo tree -i webpki  2>/dev/null)" ]
   [ -z "$(cargo tree -i rustls  2>/dev/null)" ]
   ```

6. Re-run the agent-side spike PoC tests:
   ```bash
   cd path/to/CMRemote/agent-rs
   cargo test -p cmremote-webrtc-crypto-spike
   ```
   (Note: This crate may be deleted after initial fork setup)

7. Verify cross-compilation on all five target triples (see CI workflow)

8. Tag the new version:
   ```bash
   git tag -a v<NEW>-cmremote.1 -m "CMRemote v<NEW> fork: ring -> aws-lc-rs"
   git push origin v<NEW>-cmremote.1
   ```

9. Update the `[patch.crates-io]` entry in `CMRemote/agent-rs/Cargo.toml` to reference the new tag

### Trigger 2: Security Advisories

**When:** Any security advisory affecting:
- `aws-lc-rs` or its dependencies
- The WebRTC RFC stack (RFCs 5763, 5764, 6347, 6904, 8261)
- Any transitive dependency surfaced by Dependabot

**Process:**
- Perform an out-of-band rebase regardless of upstream cadence
- Follow the same process as Trigger 1
- Increment the `-cmremote.<rev>` version number if rebasing from the same upstream version

## Rebase Cadence — `cmremote/v0.17.0-aws-lc-rs` (monorepo)

The monorepo fork's maintenance contract is structurally identical to the dtls-only contract above, but the trigger surface widens (RFCs 5389 and 5766 enter the security-advisory list because of `stun/` and `turn/`) and the substitution is per-sub-crate.

### Trigger 1: Upstream Minor Releases

**When:** Every upstream `webrtc-rs/webrtc` minor or patch release.

**Process:**

1. Create a new branch from the upstream tag:
   ```bash
   git fetch upstream-monorepo --tags
   git checkout -b cmremote/v<NEW>-aws-lc-rs v<NEW>
   ```
   (Where `upstream-monorepo` is the `webrtc-rs/webrtc` remote.)

2. Re-apply the four sed patches from ADR Steps 11–14, each scoped to the relevant sub-crate. Use word-boundary verification (the same false-positive-avoiding regex as the dtls recipe):

   ```bash
   # Step 11 — dtls/
   git ls-files 'dtls/src/*.rs' 'dtls/src/**/*.rs' | xargs sed -i \
       -e 's|use ring::|use aws_lc_rs::|g' \
       -e 's|ring::signature::|aws_lc_rs::signature::|g' \
       -e 's|ring::rand::|aws_lc_rs::rand::|g' \
       -e 's|ring::hmac::|aws_lc_rs::hmac::|g' \
       -e 's|ring::rsa::|aws_lc_rs::rsa::|g'

   # Step 12 — stun/
   git ls-files 'stun/src/*.rs' 'stun/src/**/*.rs' | xargs sed -i \
       -e 's|use ring::|use aws_lc_rs::|g' \
       -e 's|ring::hmac::|aws_lc_rs::hmac::|g'

   # Step 13 — turn/
   git ls-files 'turn/src/*.rs' 'turn/src/**/*.rs' | xargs sed -i \
       -e 's|use ring::|use aws_lc_rs::|g' \
       -e 's|ring::hmac::|aws_lc_rs::hmac::|g'

   # Step 14 — webrtc/
   git ls-files 'webrtc/src/*.rs' 'webrtc/src/**/*.rs' | xargs sed -i \
       -e 's|use ring::|use aws_lc_rs::|g' \
       -e 's|ring::signature::|aws_lc_rs::signature::|g' \
       -e 's|ring::rand::|aws_lc_rs::rand::|g' \
       -e 's|ring::hmac::|aws_lc_rs::hmac::|g' \
       -e 's|ring::digest::|aws_lc_rs::digest::|g' \
       -e 's|ring::rsa|aws_lc_rs::rsa|g'

   # Sanity check (word-boundary; do NOT use plain `grep -n ring` — it false-positives
   # on String::, Ordering::, from_utf8, server_name, etc.)
   ! grep -rn -E '\b(use ring|ring::|extern crate ring)\b' dtls/src/ stun/src/ turn/src/ webrtc/src/
   ```

3. Update the four sub-crate `Cargo.toml` files:

   - **`dtls/Cargo.toml`** — drop `ring`; add `aws-lc-rs = "1"`; change `rustls = { version = "0.23.27", default-features = false, features = ["std", "ring"] }` to `... features = ["std", "aws_lc_rs"]`; change `rcgen = "0.13"` to `rcgen = { version = "0.13", default-features = false, features = ["aws_lc_rs", "pem"] }`; pin `x509-parser = { version = "0.16", default-features = false }` (the upstream default `verify` feature pulls `ring` back in transitively).
   - **`stun/Cargo.toml`** — drop `ring`; add `aws-lc-rs = "1"`.
   - **`turn/Cargo.toml`** — drop `ring`; add `aws-lc-rs = "1"`.
   - **`webrtc/Cargo.toml`** — drop `ring`; add `aws-lc-rs = "1"`; change `rcgen = { version = "0.13", features = ["pem", "x509-parser"] }` to `rcgen = { version = "0.13", default-features = false, features = ["aws_lc_rs", "pem"] }` (drop the unused `x509-parser` feature so `ring` doesn't re-enter via `rcgen → x509-parser/verify`).

4. Mechanical-substitution code follow-ups (these are the small API-shape diffs between `ring` and `aws-lc-rs` that the sed patches don't catch):

   - `EcdsaKeyPair::from_pkcs8(alg, der, rng)` → `EcdsaKeyPair::from_pkcs8(alg, der)` — `aws_lc_rs::signature::EcdsaKeyPair` takes 2 args, not 3 (no `rng` argument).
   - `RsaKeyPair::public()` → `RsaKeyPair::public_key()` — accessed via the `aws_lc_rs::signature::KeyPair` trait. Bring the trait into scope (the `dtls/src/crypto/mod.rs` file already imports `rcgen::KeyPair`, so import the aws-lc-rs trait under a placeholder: `use aws_lc_rs::signature::{EcdsaKeyPair, Ed25519KeyPair, KeyPair as _};`).
   - Drop any now-unused `aws_lc_rs::rand::SystemRandom` imports left behind by the `from_pkcs8` rewrites.

5. Run the test suite for each forked sub-crate:
   ```bash
   cargo test -p dtls
   cargo test -p stun
   cargo test -p turn
   cargo test -p webrtc
   # or, single-shot smoke test (exercises the sub-crates transitively via `workspace = true`):
   cargo test --workspace
   cargo build --workspace
   cargo clippy --workspace --all-targets -- -D warnings
   cargo fmt -- --check
   ```

   One upstream test is marked `#[ignore]` in this fork because it is a substitution-induced semantic change rather than a true failure: `webrtc::peer_connection::certificate::test::test_generate_certificate_rsa` asserts that `KeyPair::generate_for(&rcgen::PKCS_RSA_SHA256)` *errors* — true under ring-backed rcgen, false under aws-lc-rs-backed rcgen. Confirm the *count* of ignored tests stays at 1 after a rebase; if upstream introduces another assertion that contradicts aws-lc-rs's broader algorithm coverage, mark it the same way (do **not** edit the assertion itself — that is the same "do not 'fix' tests" rule as the dtls recipe).

5a. Verify the lockfile is free of the banned crates (this is the hard precondition for tagging per ADR 0001 §"Step 4.5"). The CI workflow enforces this in the `no-banned-crates` job. Note `cargo tree -i <pkg>` exits 0 even when the package is absent (it just emits a warning to stderr), so compare stdout to an empty string rather than relying on the exit code:
   ```bash
   [ -z "$(cargo tree -i ring    2>/dev/null)" ]
   [ -z "$(cargo tree -i webpki  2>/dev/null)" ]
   # rustls itself is allowed when configured with the aws_lc_rs feature; this
   # check confirms it is not pulling ring transitively.
   ! cargo tree -i ring 2>/dev/null | grep -q rustls
   ```

6. Verify cross-compilation on all five target triples (see CI workflow). The matrix and runners are identical to the dtls recipe.

7. Tag the new version:
   ```bash
   git tag -a v<NEW>-cmremote.1 \
       -m "CMRemote v<NEW> monorepo fork: ring -> aws-lc-rs in webrtc/, dtls/, stun/, turn/"
   git push origin v<NEW>-cmremote.1
   ```

8. Update the four `[patch.crates-io]` entries in `CMRemote/agent-rs/Cargo.toml` (`webrtc`, `dtls`, `stun`, `turn` — bare names, **not** `webrtc-dtls`; the v0.17 monorepo publishes its `dtls/` sub-crate without the `package = "..."` rename) to reference the new tag.

### Trigger 2: Security Advisories

**When:** Any security advisory affecting:
- `aws-lc-rs` or its dependencies
- `rustls` (configured with the `aws_lc_rs` feature in this fork)
- `rcgen` (configured with the `aws_lc_rs` feature in this fork)
- The WebRTC RFC stack (RFCs 5389, 5763, 5764, 5766, 6347, 6904, 8261)
- Any transitive dependency surfaced by Dependabot

**Process:** identical to Trigger 1; out-of-band rebase regardless of upstream cadence.

### Trigger 3: Upstream Repo Migration

**When:** an upstream `webrtc-rs/rtc` v0.20.x release (per ADR 0001 Step 18). Re-run the slice R7.l audit against the new repo and decide whether the v0.17 monorepo fork supersedes or coexists with the rtc-based fork.

## Version Naming Convention

Tags follow the pattern: `v<upstream-version>-cmremote.<rev>`

- `<upstream-version>`: The upstream `webrtc-rs/dtls` (for `cmremote/v0.5.4-aws-lc-rs`) or `webrtc-rs/webrtc` (for `cmremote/v0.17.0-aws-lc-rs`) version (e.g., `0.5.4`, `0.17.0`)
- `<rev>`: CMRemote revision number, incremented for each CMRemote-side change
  - Increment `.1` → `.2` when making changes without rebasing upstream
  - Reset to `.1` when rebasing to a new upstream version

**Examples:**
- `v0.5.4-cmremote.1` - First CMRemote fork of upstream `webrtc-rs/dtls` v0.5.4
- `v0.5.4-cmremote.2` - Security patch on top of upstream `webrtc-rs/dtls` v0.5.4
- `v0.5.5-cmremote.1` - First CMRemote fork of upstream `webrtc-rs/dtls` v0.5.5
- `v0.17.0-cmremote.1` - First CMRemote fork of upstream `webrtc-rs/webrtc` v0.17.0 (monorepo)

## Ownership

**Maintainers:** `agent-rs/` CMRemote CODEOWNERS (per [ADR 0001 Question 3](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-webrtc-crypto-provider.md))

All changes to this repository require approval from the same reviewers who own the `agent-rs/` workspace in the CMRemote repository.

## Failure Mode

If at any point:
- The fork cannot build on all five target triples (x86_64-pc-windows-msvc, x86_64-unknown-linux-gnu, aarch64-unknown-linux-gnu, x86_64-apple-darwin, aarch64-apple-darwin)
- The dependencies (rcgen, rustls-pki-types) require re-implementing cryptographic primitives
- The mechanical substitution breaks semantic equivalence

Then **stop** and re-evaluate Option C (embedded DTLS) per the parent ADR's failure path. Do **not** silently fall back to Option A (admitting `ring`) without a fresh decision and new ADR.

## Related Documentation

- [ADR 0001: WebRTC Crypto Provider](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-webrtc-crypto-provider.md)
- [Fork Creation Instructions](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-spike-fork-instructions.md)
- [Spike Report](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-spike-report.md)

## CI/CD

The repository includes a GitHub Actions workflow that builds and tests the fork on all five required target platforms. All checks must pass before merging any changes.
