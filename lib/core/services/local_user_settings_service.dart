import 'package:shared_preferences/shared_preferences.dart';

class LocalUserSettings {
  final String userId;
  final String email;
  final bool isPremiumCached;

  const LocalUserSettings({
    required this.userId,
    required this.email,
    required this.isPremiumCached,
  });
}

class LocalUserSettingsService {
  static const _kUserId = 'user_settings.user_id';
  static const _kEmail = 'user_settings.email';
  static const _kPremium = 'user_settings.is_premium_cached';

  Future<LocalUserSettings?> getCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = (prefs.getString(_kUserId) ?? '').trim();
    final email = (prefs.getString(_kEmail) ?? '').trim();
    if (userId.isEmpty || email.isEmpty) return null;
    final premium = prefs.getBool(_kPremium) ?? false;
    return LocalUserSettings(userId: userId, email: email, isPremiumCached: premium);
  }

  Future<void> save({
    required String userId,
    required String email,
    required bool isPremiumCached,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kEmail, email);
    await prefs.setBool(_kPremium, isPremiumCached);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kEmail);
    await prefs.remove(_kPremium);
  }
}

