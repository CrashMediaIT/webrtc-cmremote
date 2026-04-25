# webrtc-cmremote

CMRemote fork of [`webrtc-rs/dtls`](https://github.com/webrtc-rs/dtls) with `ring` swapped for `aws-lc-rs`.

## Overview

This repository is a maintained fork of the `webrtc-rs/dtls` crate that replaces the `ring` cryptography library with `aws-lc-rs`. It exists to support the [CMRemote project](https://github.com/CrashMediaIT/CMRemote), which has a workspace-level ban on `ring` dependencies.

**Tracking:** [CMRemote ADR 0001](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-webrtc-crypto-provider.md)

## Key Differences from Upstream

- **Cryptography backend**: `aws-lc-rs` instead of `ring`
- **Dependencies**: Updated `rcgen` with `aws_lc_rs` feature enabled
- **License**: Dual MIT/Apache-2.0 (same as upstream)

## Usage

This crate is intended to be used via `[patch.crates-io]` in the CMRemote `agent-rs/` workspace:

```toml
[patch.crates-io]
webrtc-dtls = { git = "https://github.com/CrashMediaIT/webrtc-cmremote.git", tag = "v0.5.4-cmremote.1" }
```

## Branch Map

This repository hosts two long-lived CMRemote-fork branches, per [ADR 0001 Steps 1–9 and 10–18](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-spike-fork-instructions.md):

| Branch | Upstream | Scope | Tag | Status |
| --- | --- | --- | --- | --- |
| `cmremote/v0.5.4-aws-lc-rs` (currently `main`) | [`webrtc-rs/dtls@v0.5.4`](https://github.com/webrtc-rs/dtls) | `webrtc-dtls` only | `v0.5.4-cmremote.1` | Active, immutable |
| `cmremote/v0.17.0-aws-lc-rs` | [`webrtc-rs/webrtc@v0.17.0`](https://github.com/webrtc-rs/webrtc) | Monorepo: `webrtc/`, `dtls/`, `stun/`, `turn/` | `v0.17.0-cmremote.1` | Maintainer-runnable via [`scripts/seed-monorepo-branch.sh`](scripts/seed-monorepo-branch.sh) |

The two branches share **no commit history** — they are seeded from different upstream repositories. Both branches and their `v*-cmremote.*` tags are protected; see [GITHUB_SETTINGS.md](GITHUB_SETTINGS.md) §§4a–4b. The `[patch.crates-io].webrtc-dtls` entry in `agent-rs/` resolves the v0.5.4 tag indefinitely; the monorepo R7.m PR will add four sibling entries against the v0.17 tag.

The monorepo branch is created by running [`scripts/seed-monorepo-branch.sh`](scripts/seed-monorepo-branch.sh) from a clean `main` checkout. The script automates ADR 0001 Steps 10–14 (add the upstream remote, create the branch from `webrtc-rs/webrtc@v0.17.0` with disjoint history, apply the four scoped `ring` → `aws-lc-rs` substitutions, edit the four `Cargo.toml` files, and install the workspace-scoped CI workflow + sibling `MAINTENANCE.md`) and prints the exact Step 15 push and Step 16 tag commands. See [`scripts/monorepo-template/MAINTENANCE.md`](scripts/monorepo-template/MAINTENANCE.md) for the rebase cadence that ships onto the monorepo branch.

## Maintenance

See [MAINTENANCE.md](MAINTENANCE.md) for rebase procedures and ownership information.

## Topics

- webrtc
- dtls
- aws-lc-rs
- cmremote

## License

This project is licensed under either of:

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)

at your option.

## Upstream

This is a fork of [webrtc-rs/dtls](https://github.com/webrtc-rs/dtls).