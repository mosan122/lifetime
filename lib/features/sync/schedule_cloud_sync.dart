import 'dart:async';

import '../../injection_container.dart';
import 'data/services/sync_service.dart';

/// Dispara [SyncService.syncData] en segundo plano (best-effort).
void scheduleCloudDataSync() {
  if (!sl.isRegistered<SyncService>()) return;
  unawaited(sl<SyncService>().syncData());
}
