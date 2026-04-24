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