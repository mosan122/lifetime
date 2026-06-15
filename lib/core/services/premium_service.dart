import 'package:shared_preferences/shared_preferences.dart';

class PremiumService {
  static const _key = 'is_premium';
  bool _isPremium = false;

  bool get isPremium => _isPremium;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_key) ?? false;
  }

  Future<void> setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
