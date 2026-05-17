import 'package:google_sign_in/google_sign_in.dart';

/// Evita repetir [GoogleSignIn.attemptLightweightAuthentication] en cada pantalla
/// (en Android dispara `HiddenActivity` / Credential Manager).
class GoogleSignInSessionCache {
  GoogleSignInAccount? _account;
  DateTime? _accountCachedAt;
  DateTime? _lastFailureAt;
  Future<GoogleSignInAccount?>? _inFlight;

  static const _accountTtl = Duration(minutes: 15);
  static const _failureCooldown = Duration(minutes: 5);

  void invalidate() {
    _account = null;
    _accountCachedAt = null;
    _lastFailureAt = null;
    _inFlight = null;
  }

  Future<GoogleSignInAccount?> getAccount(GoogleSignIn signIn) async {
    final now = DateTime.now();
    if (_lastFailureAt != null &&
        now.difference(_lastFailureAt!) < _failureCooldown) {
      return null;
    }

    final cached = _account;
    final cachedAt = _accountCachedAt;
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _accountTtl) {
      return cached;
    }

    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final future = _resolve(signIn);
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<GoogleSignInAccount?> _resolve(GoogleSignIn signIn) async {
    try {
      final attempt = signIn.attemptLightweightAuthentication();
      final account = attempt == null ? null : await attempt;
      if (account != null) {
        _account = account;
        _accountCachedAt = DateTime.now();
        _lastFailureAt = null;
        return account;
      }
      _account = null;
      _accountCachedAt = null;
      _lastFailureAt = DateTime.now();
      return null;
    } catch (_) {
      _account = null;
      _accountCachedAt = null;
      _lastFailureAt = DateTime.now();
      return null;
    }
  }
}
