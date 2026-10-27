// FlowPay passkey bridge (WebAuthn + PRF extension), called from Dart.
//
// The PRF extension lets a passkey produce a secret that never leaves the
// authenticator unless the user verifies (Face ID / fingerprint / device PIN).
// FlowPay uses that secret to encrypt the wallet key, so stolen browser storage
// is useless without the passkey. All binary values cross the bridge as base64url.
(function () {
  'use strict';

  function toB64u(buffer) {
    const bytes = new Uint8Array(buffer);
    let s = '';
    for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
    return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  function fromB64u(text) {
    const s = atob(text.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((text.length + 3) % 4));
    const out = new Uint8Array(s.length);
    for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i);
    return out;
  }

  function random(n) {
    return crypto.getRandomValues(new Uint8Array(n));
  }

  async function supported() {
    if (!window.PublicKeyCredential || !navigator.credentials) return false;
    try {
      if (typeof PublicKeyCredential.getClientCapabilities === 'function') {
        const caps = await PublicKeyCredential.getClientCapabilities();
        if (caps && 'extension:prf' in caps) return !!caps['extension:prf'];
      }
      // Older browsers: a user-verifying platform authenticator is the best signal we have;
      // registration still confirms PRF support before anything is changed.
      return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
    } catch (_) {
      return false;
    }
  }

  async function register(userName) {
    const credential = await navigator.credentials.create({
      publicKey: {
        rp: { name: 'FlowPay' },
        user: { id: random(16), name: userName, displayName: userName },
        challenge: random(32),
        pubKeyCredParams: [
          { type: 'public-key', alg: -7 },
          { type: 'public-key', alg: -257 },
        ],
        authenticatorSelection: { residentKey: 'preferred', userVerification: 'required' },
        extensions: { prf: {} },
        timeout: 120000,
      },
    });
    const ext = credential.getClientExtensionResults();
    if (!ext || !ext.prf || ext.prf.enabled !== true) {
      throw new Error('This passkey or browser does not support the PRF extension FlowPay needs.');
    }
    return toB64u(credential.rawId);
  }

  async function prf(credentialIdB64u, saltB64u) {
    const assertion = await navigator.credentials.get({
      publicKey: {
        challenge: random(32),
        allowCredentials: [{ type: 'public-key', id: fromB64u(credentialIdB64u) }],
        userVerification: 'required',
        extensions: { prf: { eval: { first: fromB64u(saltB64u) } } },
        timeout: 120000,
      },
    });
    const ext = assertion.getClientExtensionResults();
    const first = ext && ext.prf && ext.prf.results && ext.prf.results.first;
    if (!first) throw new Error('The passkey did not return a key. Try again or use your recovery key.');
    return toB64u(first);
  }

  window.flowpayPasskey = { supported, register, prf };
})();
