import 'package:flutter/foundation.dart';

/// Indica si hay sync con la nube en curso (Supabase y/o Drive).
class CloudSyncActivityNotifier extends ChangeNotifier {
  int _activeOps = 0;

  bool get isActive => _activeOps > 0;

  void acquire() {
    final wasIdle = _activeOps == 0;
    _activeOps++;
    if (wasIdle) notifyListeners();
  }

  void release() {
    if (_activeOps <= 0) return;
    _activeOps--;
    if (_activeOps == 0) notifyListeners();
  }
}
