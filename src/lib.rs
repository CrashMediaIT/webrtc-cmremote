#![warn(rust_2018_idioms)]
#![allow(dead_code)]
// CMRemote fork: the clippy lints below all fire on upstream
// `webrtc-rs/dtls@v0.5.4` source that we want to keep byte-identical for
// clean future rebases. They are intentionally allowed at the crate level
// rather than fixed in-place. See ADR 0001 (fork instructions, §"Failure
// mode") for the rationale ("the substitution is supposed to be observably
// identical").
#![allow(
    clippy::assertions_on_constants,
    clippy::bool_assert_comparison,
    clippy::derivable_impls,
    clippy::field_reassign_with_default,
    clippy::iter_kv_map,
    clippy::needless_as_bytes,
    clippy::new_ret_no_self,
    clippy::question_mark,
    clippy::single_match,
    clippy::to_string_in_format_args,
    clippy::type_complexity,
    clippy::unnecessary_cast,
    clippy::unwrap_or_default,
    clippy::useless_vec
)]

#[macro_use]
extern crate serde_derive;

pub mod alert;
pub mod application_data;
pub mod change_cipher_spec;
pub mod cipher_suite;
pub mod client_certificate_type;
pub mod compression_methods;
pub mod config;
pub mod conn;
pub mod content;
pub mod crypto;
pub mod curve;
mod error;
pub mod extension;
pub mod flight;
pub mod fragment_buffer;
pub mod handshake;
pub mod handshaker;
pub mod listener;
pub mod pki;
pub mod prf;
pub mod record_layer;
pub mod signature_hash_algorithm;
pub mod state;

pub use error::Error;

use cipher_suite::*;
use extension::extension_use_srtp::SrtpProtectionProfile;

pub(crate) fn find_matching_srtp_profile(
    a: &[SrtpProtectionProfile],
    b: &[SrtpProtectionProfile],
) -> Result<SrtpProtectionProfile, ()> {
    for a_profile in a {
        for b_profile in b {
            if a_profile == b_profile {
                return Ok(*a_profile);
            }
        }
    }
    Err(())
}

pub(crate) fn find_matching_cipher_suite(
    a: &[CipherSuiteId],
    b: &[CipherSuiteId],
) -> Result<CipherSuiteId, ()> {
    for a_suite in a {
        for b_suite in b {
            if a_suite == b_suite {
                return Ok(*a_suite);
            }
        }
    }
    Err(())
}
