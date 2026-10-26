/// Employee invite links: `https://<app>/invite/<token>`, `flowpay://invite/<token>`,
/// or the bare 48-hex token.
class InviteLink {
  /// Set at startup (web) when the app was opened from an invite link; consumed
  /// once by the auth gate.
  static String? pendingToken;

  static final _token = RegExp(r'([0-9a-f]{48})');

  /// Extracts the token from a link or bare token, or null if there isn't one.
  static String? parse(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.contains('/invite/')) {
      return _token.firstMatch(trimmed.split('/invite/').last)?.group(1);
    }
    final m = _token.firstMatch(trimmed);
    return m != null && m.group(1)!.length == trimmed.length ? m.group(1) : null;
  }

  static String? takePending() {
    final t = pendingToken;
    pendingToken = null;
    return t;
  }
}
