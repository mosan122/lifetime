import 'dart:async';

import '../../core/services/cloud_sync_service.dart';
import '../../core/services/cloud_sync_status_store.dart';
import '../../injection_container.dart';
import 'data/services/sync_service.dart';

Timer? _debounce;
var _pendingForceResync = false;

/// Tras login premium: marca pull en el primer timeline y programa sync en segundo plano.
void onPremiumSessionStarted() {
  if (sl.isRegistered<CloudSyncStatusStore>()) {
    unawaited(sl<CloudSyncStatusStore>().markNeedsTimelinePull());
  }
  scheduleCloudDataSync();
}

/// Tras restaurar copia local (import JSON): sube a la nube sin pisar lo recién importado.
void scheduleCloudDataSyncAfterLocalRestore() {
  scheduleCloudDataSync(forceResync: true);
}

/// Metadatos al instante; medios/Drive diferidos (agrupado ~3 s).
void scheduleCloudDataSync({bool forceResync = false}) {
  if (!sl.isRegistered<SyncService>()) return;
  if (forceResync) _pendingForceResync = true;
  _debounce?.cancel();
  _debounce = Timer(const Duration(seconds: 3), () {
    final force = _pendingForceResync;
    _pendingForceResync = false;
    final sync = sl<SyncService>();
    unawaited(sync.syncMetadata(forceResync: force).then((meta) {
      if (meta.skipped) return;
      unawaited(
        sl<CloudSyncService>().syncMediaDeferred(forceRestore: force),
      );
    }));
  });
}
