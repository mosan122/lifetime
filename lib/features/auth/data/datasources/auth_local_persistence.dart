import 'package:isar/isar.dart';

import '../../../../core/services/local_user_settings_service.dart';
import '../models/local/local_user_session_collection.dart';

/// Snapshot de sesión cacheada (Isar + SharedPreferences).
class CachedUserSession {
  final String userId;
  final String email;
  final bool isPremiumCached;
  final bool emailVerified;

  const CachedUserSession({
    required this.userId,
    required this.email,
    required this.isPremiumCached,
    required this.emailVerified,
  });
}

/// Persistencia local-first del usuario autenticado (Isar cuando existe instancia).
class AuthLocalPersistence {
  AuthLocalPersistence(this._prefs, this._isar);

  final LocalUserSettingsService _prefs;
  final Isar? _isar;

  Future<CachedUserSession?> read() async {
    if (_isar != null) {
      final row = await _isar!.localUserSessionCollections.get(1);
      if (row != null && row.userId.isNotEmpty && row.email.isNotEmpty) {
        return CachedUserSession(
          userId: row.userId,
          email: row.email,
          isPremiumCached: row.isPremiumCached,
          emailVerified: row.emailVerified,
        );
      }
    }
    final p = await _prefs.getCurrent();
    if (p == null) return null;
    return CachedUserSession(
      userId: p.userId,
      email: p.email,
      isPremiumCached: p.isPremiumCached,
      emailVerified: p.emailVerified,
    );
  }

  Future<void> save({
    required String userId,
    required String email,
    required bool isPremiumCached,
    required bool emailVerified,
  }) async {
    if (_isar != null) {
      await _isar!.writeTxn(() async {
        await _isar!.localUserSessionCollections.put(
          LocalUserSessionCollection()
            ..id = 1
            ..userId = userId
            ..email = email
            ..isPremiumCached = isPremiumCached
            ..emailVerified = emailVerified,
        );
      });
    }
    await _prefs.save(
      userId: userId,
      email: email,
      isPremiumCached: isPremiumCached,
      emailVerified: emailVerified,
    );
  }

  Future<void> clear() async {
    if (_isar != null) {
      await _isar!.writeTxn(() async {
        await _isar!.localUserSessionCollections.delete(1);
      });
    }
    await _prefs.clear();
  }
}
