# webrtc-cmremote

CMRemote fork of [`webrtc-rs/dtls`](https://github.com/webrtc-rs/dtls) (v0.5.4) and [`webrtc-rs/webrtc`](https://github.com/webrtc-rs/webrtc) (v0.17.0 monorepo) with `ring` swapped for `aws-lc-rs`.

## Overview

This repository is a maintained fork of the `webrtc-rs/dtls` crate (v0.5.4) and the `webrtc-rs/webrtc` workspace (v0.17.0: `webrtc/`, `dtls/`, `stun/`, `turn/`, plus the rest of the upstream workspace) that replaces the `ring` cryptography library with `aws-lc-rs`. It exists to support the [CMRemote project](https://github.com/CrashMediaIT/CMRemote), which has a workspace-level ban on `ring` dependencies.

**Tracking:** [CMRemote ADR 0001](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-webrtc-crypto-provider.md)

## Key Differences from Upstream

- **Cryptography backend**: `aws-lc-rs` instead of `ring` (per-sub-crate sed substitution per ADR 0001 Steps 11–14)
- **Dependencies**: `rcgen` configured with `aws_lc_rs` feature (and `default-features = false` to avoid pulling `ring` back in via the unused `x509-parser` feature in the v0.17 monorepo); `rustls` configured with the `aws_lc_rs` feature (v0.17 only — the v0.5.4 branch drops `rustls` entirely and ships an internal `crate::pki` shim instead, see ADR §4.4)
- **License**: Dual MIT/Apache-2.0 (same as upstream)

## Usage

This crate is intended to be used via `[patch.crates-io]` in the CMRemote `agent-rs/` workspace.

For the v0.5.4 dtls-only fork:

```toml
[patch.crates-io]
webrtc-dtls = { git = "https://github.com/CrashMediaIT/webrtc-cmremote.git", tag = "v0.5.4-cmremote.1" }
```

For the v0.17.0 monorepo fork (slice R7.m driver — covers the umbrella crate plus the three RFC sub-crates the audit flagged):

```toml
[patch.crates-io]
webrtc       = { git = "https://github.com/CrashMediaIT/webrtc-cmremote.git", tag = "v0.17.0-cmremote.1" }
webrtc-dtls  = { git = "https://github.com/CrashMediaIT/webrtc-cmremote.git", tag = "v0.17.0-cmremote.1" }
stun         = { git = "https://github.com/CrashMediaIT/webrtc-cmremote.git", tag = "v0.17.0-cmremote.1" }
turn         = { git = "https://github.com/CrashMediaIT/webrtc-cmremote.git", tag = "v0.17.0-cmremote.1" }
```

Cargo discovers each named member by walking the fork's `[workspace.members]`; per-entry `path = "..."` selectors are not valid alongside `git` + `tag` (cargo rejects them as ambiguous).

## Branch Map

This repository hosts two long-lived CMRemote-fork branches, per [ADR 0001 Steps 1–9 and 10–18](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-spike-fork-instructions.md):

| Branch | Upstream | Scope | Tag | Status |
| --- | --- | --- | --- | --- |
| `cmremote/v0.5.4-aws-lc-rs` | [`webrtc-rs/dtls@v0.5.4`](https://github.com/webrtc-rs/dtls) | `webrtc-dtls` only | `v0.5.4-cmremote.1` | Active, immutable |
| `cmremote/v0.17.0-aws-lc-rs` | [`webrtc-rs/webrtc@v0.17.0`](https://github.com/webrtc-rs/webrtc) | Monorepo: `webrtc/`, `dtls/`, `stun/`, `turn/` (+ unmodified `data/`, `ice/`, `interceptor/`, `mdns/`, `media/`, `rtcp/`, `rtp/`, `sctp/`, `sdp/`, `srtp/`, `util/`) | `v0.17.0-cmremote.1` | Active |

The two branches share **no commit history** — they are seeded from different upstream repositories. Both branches and their `v*-cmremote.*` tags are protected; see [GITHUB_SETTINGS.md](GITHUB_SETTINGS.md) §§4a–4b. The `[patch.crates-io].webrtc-dtls` entry in `agent-rs/` resolves the v0.5.4 tag indefinitely; the slice R7.m driver PR adds four sibling entries against the v0.17 tag (see "Usage" above).

## Maintenance

See [MAINTENANCE.md](MAINTENANCE.md) for rebase procedures and ownership information. The same document carries both the v0.5.4 dtls-only recipe and the v0.17 monorepo recipe (the latter widens the rebase trigger surface to RFCs 5389 and 5766 and substitutes per-sub-crate).

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