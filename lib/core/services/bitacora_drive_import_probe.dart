import 'package:google_sign_in/google_sign_in.dart';

import '../utils/bitacora_backup_json.dart';
import 'drive_milestone_media_restore.dart';
import 'google_drive_scope_auth.dart';
import 'google_drive_service.dart';
import 'google_sign_in_silent.dart';
import 'premium_service.dart';

/// Comprueba si en Drive hay carpetas de medios para los ids del JSON de importación.
class BitacoraDriveImportProbe {
  BitacoraDriveImportProbe(
    this._premium,
    this._googleSignIn,
    this._restore,
  );

  final PremiumService _premium;
  final GoogleSignIn _googleSignIn;
  final DriveMilestoneMediaRestore _restore;

  Future<DriveMilestoneFolderProbeResult> probeFromJson(String json) async {
    if (!_premium.isPremium) return const DriveMilestoneFolderProbeResult();

    BitacoraImportPreview preview;
    try {
      preview = BitacoraBackupJson.parseImportPreview(json);
    } catch (_) {
      return const DriveMilestoneFolderProbeResult();
    }

    final ids = preview.milestoneMaps
        .map((m) => (m['id'] as String?)?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return const DriveMilestoneFolderProbeResult();

    final account = await googleSignInSilently(_googleSignIn);
    if (account == null) return const DriveMilestoneFolderProbeResult();

    final authorization = await driveAuthorizationSilently(account);
    if (authorization == null) return const DriveMilestoneFolderProbeResult();

    try {
      final drive = GoogleDriveService(_googleSignIn);
      return await _restore.probeFoldersForMilestoneIds(drive, ids);
    } catch (_) {
      return const DriveMilestoneFolderProbeResult();
    }
  }
}
