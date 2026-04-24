# Maintenance Guide for webrtc-cmremote

This repository is a fork of [`webrtc-rs/dtls`](https://github.com/webrtc-rs/dtls) with the `ring` cryptography library replaced by `aws-lc-rs`. It is maintained as part of the [CMRemote project](https://github.com/CrashMediaIT/CMRemote).

> **Scope:** This guide covers the `cmremote/v0.5.4-aws-lc-rs` branch (the dtls-only fork tagged `v0.5.4-cmremote.1`). The forthcoming `cmremote/v0.17.0-aws-lc-rs` monorepo branch (ADR 0001 Steps 10–18, covering `webrtc/`, `dtls/`, `stun/`, `turn/`) will carry its own sibling guidance per Step 18; the maintenance contract is structurally the same but the rebase trigger surface is wider (RFCs 5389 and 5766 are added) and the substitution is per-sub-crate. See the [branch map in README.md](README.md#branch-map).

## Purpose

This fork exists to enable CMRemote's `agent-rs/` workspace to use WebRTC DTLS without depending on the `ring` crate, which is banned in the workspace per [ADR 0001](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-webrtc-crypto-provider.md).

## Rebase Cadence

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
    enforces this in the `no-banned-crates` job:
   ```bash
   ! cargo tree -i ring 2>/dev/null
   ! cargo tree -i webpki 2>/dev/null
   ! cargo tree -i rustls 2>/dev/null
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

## Version Naming Convention

Tags follow the pattern: `v<upstream-version>-cmremote.<rev>`

- `<upstream-version>`: The upstream `webrtc-rs/dtls` version (e.g., `0.5.4`)
- `<rev>`: CMRemote revision number, incremented for each CMRemote-side change
  - Increment `.1` → `.2` when making changes without rebasing upstream
  - Reset to `.1` when rebasing to a new upstream version

**Examples:**
- `v0.5.4-cmremote.1` - First CMRemote fork of upstream v0.5.4
- `v0.5.4-cmremote.2` - Security patch on top of upstream v0.5.4
- `v0.5.5-cmremote.1` - First CMRemote fork of upstream v0.5.5

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
