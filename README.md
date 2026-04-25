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
| `cmremote/v0.17.0-aws-lc-rs` | [`webrtc-rs/webrtc@v0.17.0`](https://github.com/webrtc-rs/webrtc) | Monorepo: `webrtc/`, `dtls/`, `stun/`, `turn/` | `v0.17.0-cmremote.1` | Planned (ADR 0001 Step 10+) |

The two branches share **no commit history** — they are seeded from different upstream repositories. Both branches and their `v*-cmremote.*` tags are protected; see [GITHUB_SETTINGS.md](GITHUB_SETTINGS.md) §§4a–4b. The `[patch.crates-io].webrtc-dtls` entry in `agent-rs/` resolves the v0.5.4 tag indefinitely; the monorepo R7.m PR will add four sibling entries against the v0.17 tag.

Documentation in this repo is currently scoped to the v0.5.4 dtls fork. The monorepo branch will carry its own sibling guidance per ADR 0001 Step 18.

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