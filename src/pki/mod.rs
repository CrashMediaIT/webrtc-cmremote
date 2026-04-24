//! Minimal PKI type plumbing for the CMRemote `webrtc-dtls` fork.
//!
//! Replaces the upstream dependency on `rustls = "0.19"` (and transitively on
//! `webpki = "0.21"` and `ring = "0.16"`), which the CMRemote `agent-rs/`
//! workspace bans per [ADR 0001 — webrtc-crypto-provider][adr0001].
//!
//! The fork's only consumer is CMRemote's WebRTC stack, where peer
//! authentication is performed out-of-band via the SDP `a=fingerprint`
//! attribute (RFC 8122). The application is therefore expected to install a
//! `verify_peer_certificate` callback on [`crate::config::Config`] that
//! validates the fingerprint; the verifier defaults provided here
//! ([`WebPKIVerifier`], [`AllowAnyAuthenticatedClient`]) are placeholders that
//! preserve the upstream `webrtc-dtls@v0.5.4` API shape but are not intended
//! to be relied on for real X.509 path validation.
//!
//! [adr0001]: https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-webrtc-crypto-provider.md

use std::sync::Arc;

/// A wrapper around a single DER-encoded X.509 certificate.
///
/// Drop-in replacement for `rustls::Certificate` from rustls 0.19.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct Certificate(pub Vec<u8>);

impl AsRef<[u8]> for Certificate {
    fn as_ref(&self) -> &[u8] {
        &self.0
    }
}

/// A pool of trusted root certificates.
///
/// Drop-in replacement for `rustls::RootCertStore` from rustls 0.19, reduced
/// to just the operations the DTLS layer actually exercises.
#[derive(Clone, Debug, Default)]
pub struct RootCertStore {
    /// The DER-encoded root certificates currently in the store.
    pub roots: Vec<Certificate>,
}

impl RootCertStore {
    /// Construct an empty store.
    pub fn empty() -> Self {
        Self { roots: Vec::new() }
    }

    /// Add a single trust anchor to the store.
    ///
    /// Always succeeds for well-formed input; the `Result` shape is preserved
    /// to match the upstream rustls 0.19 method signature.
    pub fn add(&mut self, cert: &Certificate) -> Result<(), RootCertStoreError> {
        if cert.0.is_empty() {
            return Err(RootCertStoreError::EmptyCertificate);
        }
        self.roots.push(cert.clone());
        Ok(())
    }
}

/// Error returned by [`RootCertStore::add`].
#[derive(Debug, thiserror::Error)]
pub enum RootCertStoreError {
    #[error("certificate DER is empty")]
    EmptyCertificate,
}

/// Verifier of a peer's server certificate chain.
///
/// Drop-in trait shape for `rustls::ServerCertVerifier` from rustls 0.19,
/// minus the `webpki::DNSNameRef` parameter (replaced by `&str`).
pub trait ServerCertVerifier: Send + Sync {
    fn verify_server_cert(
        &self,
        roots: &RootCertStore,
        presented_certs: &[Certificate],
        dns_name: &str,
        ocsp_response: &[u8],
    ) -> Result<(), VerifierError>;
}

/// Verifier of a peer's client certificate chain.
///
/// Drop-in trait shape for `rustls::ClientCertVerifier` from rustls 0.19,
/// minus the `webpki::DNSName` SNI parameter (replaced by `Option<&str>`).
pub trait ClientCertVerifier: Send + Sync {
    fn verify_client_cert(
        &self,
        presented_certs: &[Certificate],
        sni: Option<&str>,
    ) -> Result<(), VerifierError>;
}

/// Error returned by [`ServerCertVerifier`] / [`ClientCertVerifier`] impls.
#[derive(Debug, thiserror::Error)]
pub enum VerifierError {
    #[error("certificate chain is empty")]
    EmptyChain,
    #[error(
        "default WebPKI verifier is a placeholder in the CMRemote fork; \
         install a SDP-fingerprint `verify_peer_certificate` callback on Config"
    )]
    NoBuiltinVerifier,
    #[error("{0}")]
    Other(String),
}

/// Default server-cert verifier — placeholder for the CMRemote fork.
///
/// In the upstream `webrtc-rs/dtls@v0.5.4`, this delegated to `webpki` (and
/// hence `ring`). For the CMRemote use case, peer authentication is always
/// performed via the SDP fingerprint callback, so this default is intended to
/// be replaced. If reached without an override, it returns
/// [`VerifierError::NoBuiltinVerifier`] to fail safely.
#[derive(Default, Debug)]
pub struct WebPKIVerifier;

impl WebPKIVerifier {
    pub fn new() -> Self {
        Self
    }
}

impl ServerCertVerifier for WebPKIVerifier {
    fn verify_server_cert(
        &self,
        _roots: &RootCertStore,
        presented_certs: &[Certificate],
        _dns_name: &str,
        _ocsp_response: &[u8],
    ) -> Result<(), VerifierError> {
        if presented_certs.is_empty() {
            return Err(VerifierError::EmptyChain);
        }
        Err(VerifierError::NoBuiltinVerifier)
    }
}

/// Client-cert verifier that accepts any chain bound to a trusted root.
///
/// Drop-in shape for `rustls::AllowAnyAuthenticatedClient` from rustls 0.19.
/// The CMRemote fork does **not** perform CA-chain validation here — the
/// expectation, per the ADR, is that the application installs an SDP
/// fingerprint callback. This impl simply requires that *some* chain was
/// presented, matching the "any authenticated client" semantics modulo CA
/// validation.
#[derive(Debug)]
pub struct AllowAnyAuthenticatedClient {
    #[allow(dead_code)]
    roots: RootCertStore,
}

impl AllowAnyAuthenticatedClient {
    pub fn new(roots: RootCertStore) -> Arc<dyn ClientCertVerifier> {
        Arc::new(Self { roots })
    }
}

impl ClientCertVerifier for AllowAnyAuthenticatedClient {
    fn verify_client_cert(
        &self,
        presented_certs: &[Certificate],
        _sni: Option<&str>,
    ) -> Result<(), VerifierError> {
        if presented_certs.is_empty() {
            return Err(VerifierError::EmptyChain);
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn root_store_empty_then_add() {
        let mut s = RootCertStore::empty();
        assert!(s.roots.is_empty());
        s.add(&Certificate(vec![1, 2, 3])).unwrap();
        assert_eq!(s.roots.len(), 1);
    }

    #[test]
    fn root_store_rejects_empty_cert() {
        let mut s = RootCertStore::empty();
        assert!(s.add(&Certificate(Vec::new())).is_err());
    }

    #[test]
    fn webpki_verifier_rejects_empty_chain() {
        let v = WebPKIVerifier::new();
        let s = RootCertStore::empty();
        assert!(matches!(
            v.verify_server_cert(&s, &[], "example.com", &[]),
            Err(VerifierError::EmptyChain)
        ));
    }

    #[test]
    fn webpki_verifier_is_placeholder() {
        let v = WebPKIVerifier::new();
        let s = RootCertStore::empty();
        let cert = Certificate(vec![0, 1, 2]);
        assert!(matches!(
            v.verify_server_cert(&s, &[cert], "example.com", &[]),
            Err(VerifierError::NoBuiltinVerifier)
        ));
    }

    #[test]
    fn allow_any_authenticated_client_requires_chain() {
        let v = AllowAnyAuthenticatedClient::new(RootCertStore::empty());
        assert!(v.verify_client_cert(&[], None).is_err());
        assert!(v
            .verify_client_cert(&[Certificate(vec![1, 2])], None)
            .is_ok());
    }
}
