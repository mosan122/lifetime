import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/cloud_sync_format.dart';

/// Última sincronización premium exitosa con la nube (Supabase + Drive).
class CloudSyncStatusStore {
  static const _kLastSuccessUtcMs = 'cloud_sync.last_success_utc_ms';
  static const _kNeedsTimelinePull = 'cloud_sync.needs_timeline_pull';

  final ValueNotifier<DateTime?> lastSuccessUtc = ValueNotifier(null);

  Future<void> hydrate() async {
    lastSuccessUtc.value = await readLastSuccessUtc();
  }

  Future<DateTime?> readLastSuccessUtc() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kLastSuccessUtcMs);
    if (ms == null || ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> recordSuccess(DateTime whenUtc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kLastSuccessUtcMs,
      whenUtc.toUtc().millisecondsSinceEpoch,
    );
    lastSuccessUtc.value = whenUtc.toUtc();
  }

  Future<void> clearLastSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastSuccessUtcMs);
    lastSuccessUtc.value = null;
  }

  Future<void> markNeedsTimelinePull() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNeedsTimelinePull, true);
  }

  /// Devuelve true solo la primera vez tras marcar (p. ej. login premium).
  Future<bool> consumeNeedsTimelinePull() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kNeedsTimelinePull) ?? false)) return false;
    await prefs.setBool(_kNeedsTimelinePull, false);
    return true;
  }

  static String formatForDisplay(DateTime utc) => formatCloudSyncTimestamp(utc);
}
