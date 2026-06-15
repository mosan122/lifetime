import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_flags.dart';
import '../../../../core/services/storage_metrics_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_bytes.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../sync/data/services/sync_service.dart';
import '../../../sync/domain/sync_pending_counts.dart';
import '../../../sync/domain/sync_run_result.dart';
import '../../../sync/schedule_cloud_sync.dart';
import 'paywall_view.dart';

/// Panel de control Premium: Drive, almacenamiento y sincronización.
class PremiumDashboardView extends StatefulWidget {
  const PremiumDashboardView({super.key});

  @override
  State<PremiumDashboardView> createState() => _PremiumDashboardViewState();
}

class _PremiumDashboardViewState extends State<PremiumDashboardView> {
  final _metrics = sl<StorageMetricsService>();
  StorageMetricsSnapshot? _snapshot;
  bool _loading = true;
  bool _linkingDrive = false;
  bool _syncing = false;
  bool _lastSyncHadErrors = false;
  String? _lastSyncErrorSummary;

  @override
  void initState() {
    super.initState();
    _loadMetrics(fetchDrive: false);
  }

  Future<void> _loadMetrics({bool fetchDrive = true}) async {
    setState(() => _loading = true);
    final snap = await _metrics.load(fetchDriveQuota: fetchDrive);
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      _loading = false;
    });
  }

  Future<void> _syncNow({required bool driveLinked}) async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _lastSyncHadErrors = false;
      _lastSyncErrorSummary = null;
    });
    try {
      SyncRunResult? result;
      if (sl.isRegistered<SyncService>()) {
        result = await sl<SyncService>().syncData(forceResync: true);
      } else {
        scheduleCloudDataSync(forceResync: true);
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      if (!mounted) return;
      final syncResult = result;
      if (syncResult != null) {
        setState(() {
          _lastSyncHadErrors =
              syncResult.skipped || syncResult.hasErrors;
          if (syncResult.skipped) {
            _lastSyncErrorSummary =
                syncResult.skipReason ?? 'No se pudo sincronizar.';
          } else if (syncResult.hasErrors) {
            _lastSyncErrorSummary = syncResult.errors.isNotEmpty
                ? syncResult.errors.first
                : 'Algunos elementos no se subieron '
                    '(${syncResult.totalFailed} fallos).';
          }
        });
        _showSyncResult(syncResult, driveLinked: driveLinked);
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
        await _loadMetrics(fetchDrive: driveLinked);
      }
    }
  }

  void _showSyncResult(SyncRunResult result, {required bool driveLinked}) {
    final messenger = ScaffoldMessenger.of(context);
    if (result.skipped) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.skipReason ?? 'No se pudo sincronizar.')),
      );
      return;
    }

    if (result.hasErrors) {
      final detail = result.errors.isNotEmpty
          ? result.errors.first
          : 'Comprueba que las migraciones estén aplicadas en Supabase.';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Sincronización con errores (${result.totalFailed} fallos). '
            '$detail',
          ),
          duration: const Duration(seconds: 8),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (result.totalSynced > 0) {
      final parts = <String>[];
      if (result.peopleSynced > 0) {
        parts.add('${result.peopleSynced} persona(s)');
      }
      if (result.relationshipsSynced > 0) {
        parts.add('${result.relationshipsSynced} relación(es)');
      }
      if (result.milestonesSynced > 0) {
        parts.add('${result.milestonesSynced} hito(s)');
      }
      var msg = 'Subido a Supabase: ${parts.join(', ')}.';
      if (!driveLinked && result.milestonesSynced > 0) {
        msg += ' Conecta Drive para subir fotos y vídeos.';
      }
      messenger.showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'No quedaban metadatos pendientes. En Supabase revisa las tablas '
          'contact_people, person_relationships y milestones (no solo profiles).',
        ),
        duration: Duration(seconds: 6),
      ),
    );
  }

  Future<void> _connectDrive() async {
    setState(() => _linkingDrive = true);
    final result = await context.read<AuthCubit>().linkGoogleAccount();
    if (!mounted) return;
    setState(() => _linkingDrive = false);

    result.fold(
      (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(f.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Drive conectado.')),
        );
        _loadMetrics(fetchDrive: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        if (auth is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: Text('Inicia sesión para ver este panel.')),
          );
        }

        if (!auth.isPremium) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const PaywallView()),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final snap = _snapshot;
        final driveLinked = auth.googleDriveLinked;

        return Scaffold(
          backgroundColor: AppTheme.cream,
          appBar: AppBar(
            title: const Text('Panel Premium'),
            actions: [
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _loading ? null : () => _loadMetrics(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            color: AppTheme.navy,
            onRefresh: () => _loadMetrics(fetchDrive: driveLinked),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                if (!driveLinked) ...[
                  _DriveConnectCard(
                    loading: _linkingDrive,
                    onConnect: _connectDrive,
                  ),
                  const SizedBox(height: 20),
                ],
                if (_loading && snap == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snap != null) ...[
                  _StorageSection(
                    title: 'Almacenamiento local',
                    subtitle: 'Medios y datos de la app en este dispositivo',
                    usedLabel: formatBytes(snap.localBytes),
                    progress: _localProgress(snap.localBytes),
                    progressColor: AppTheme.navy,
                  ),
                  if (driveLinked) ...[
                    const SizedBox(height: 20),
                    _StorageSection(
                      title: 'Google Drive',
                      subtitle: snap.driveError != null
                          ? 'No se pudo leer la cuota'
                          : 'Espacio de tu cuenta Google',
                      usedLabel: snap.driveAvailable
                          ? _driveUsedLabel(snap)
                          : '—',
                      progress: _driveProgress(snap),
                      progressColor: Colors.blue.shade800,
                      errorHint: snap.driveError,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _SyncStatusCard(
                    pending: snap.pending,
                    syncing: _syncing,
                    hasSyncError: _lastSyncHadErrors,
                    syncErrorSummary: _lastSyncErrorSummary,
                    driveLinked: driveLinked,
                    onSyncNow: () => _syncNow(driveLinked: driveLinked),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  double _localProgress(int bytes) {
    const ref = 5 * 1024 * 1024 * 1024; // referencia visual 5 GB
    return (bytes / ref).clamp(0.0, 1.0);
  }

  double _driveProgress(StorageMetricsSnapshot snap) {
    final limit = snap.driveLimitBytes;
    final usage = snap.driveUsageBytes ?? 0;
    if (limit == null || limit <= 0) return 0.35;
    return (usage / limit).clamp(0.0, 1.0);
  }

  String _driveUsedLabel(StorageMetricsSnapshot snap) {
    final usage = snap.driveUsageBytes ?? 0;
    final limit = snap.driveLimitBytes;
    if (limit == null || limit <= 0) {
      return '${formatBytes(usage)} usados';
    }
    return '${formatBytes(usage)} / ${formatBytes(limit)}';
  }
}

class _DriveConnectCard extends StatelessWidget {
  const _DriveConnectCard({
    required this.loading,
    required this.onConnect,
  });

  final bool loading;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.navy.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.navy.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.add_to_drive, color: AppTheme.navy.withValues(alpha: 0.9)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Conecta Google Drive',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Respalda fotos y vídeos de tus hitos en tu nube personal.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: loading ? null : onConnect,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link),
              label: Text(loading ? 'Conectando…' : 'Conectar Google Drive'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageSection extends StatelessWidget {
  const _StorageSection({
    required this.title,
    required this.subtitle,
    required this.usedLabel,
    required this.progress,
    required this.progressColor,
    this.errorHint,
  });

  final String title;
  final String subtitle;
  final String usedLabel;
  final double progress;
  final Color progressColor;
  final String? errorHint;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.navy.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: AppTheme.navy.withValues(alpha: 0.08),
                color: progressColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              usedLabel,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.navy,
                  ),
            ),
            if (errorHint != null) ...[
              const SizedBox(height: 6),
              Text(
                errorHint!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade800,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _SyncCardVisualState { syncing, synced, error, pending }

class _SyncStatusCard extends StatefulWidget {
  const _SyncStatusCard({
    required this.pending,
    required this.syncing,
    required this.hasSyncError,
    required this.syncErrorSummary,
    required this.driveLinked,
    required this.onSyncNow,
  });

  final SyncPendingCounts pending;
  final bool syncing;
  final bool hasSyncError;
  final String? syncErrorSummary;
  final bool driveLinked;
  final VoidCallback onSyncNow;

  @override
  State<_SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<_SyncStatusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(covariant _SyncStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncing && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!widget.syncing && _spinController.isAnimating) {
      _spinController.stop();
      _spinController.reset();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  _SyncCardVisualState get _visualState {
    if (widget.syncing) return _SyncCardVisualState.syncing;
    if (widget.hasSyncError) return _SyncCardVisualState.error;
    if (!widget.pending.isEmpty) return _SyncCardVisualState.pending;
    return _SyncCardVisualState.synced;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.syncing && !_spinController.isAnimating) {
      _spinController.repeat();
    }

    final theme = Theme.of(context);
    final state = _visualState;
    final pendingLines = widget.pending.pendingLines;

    final Color cardBg;
    final Color borderColor;
    switch (state) {
      case _SyncCardVisualState.syncing:
        cardBg = AppTheme.navy.withValues(alpha: 0.06);
        borderColor = AppTheme.navy.withValues(alpha: 0.2);
      case _SyncCardVisualState.synced:
        cardBg = Colors.green.shade50;
        borderColor = Colors.green.shade200;
      case _SyncCardVisualState.error:
        cardBg = Colors.red.shade50;
        borderColor = Colors.red.shade200;
      case _SyncCardVisualState.pending:
        cardBg = Colors.orange.shade50;
        borderColor = Colors.orange.shade200;
    }

    final canSync = !widget.syncing;
    final showPendingList = !widget.syncing && pendingLines.isNotEmpty;

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sincronización',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 14),
            _SyncStateBanner(
              state: state,
              spinController: _spinController,
              errorSummary: widget.syncErrorSummary,
            ),
            if (showPendingList) ...[
              const SizedBox(height: 16),
              Text(
                'Pendientes de sincronizar:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 8),
              for (final line in pendingLines)
                _PendingBulletLine(
                  count: line.count,
                  label: line.label,
                  hint: line.label == 'imágenes y vídeos' &&
                          !widget.driveLinked
                      ? 'conecta Google Drive'
                      : null,
                ),
            ],
            if (AppFlags.kIsCloudEnabled) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: canSync ? widget.onSyncNow : null,
                icon: widget.syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  widget.syncing ? 'Sincronizando…' : 'Sincronizar ahora',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppTheme.navy.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncStateBanner extends StatelessWidget {
  const _SyncStateBanner({
    required this.state,
    required this.spinController,
    this.errorSummary,
  });

  final _SyncCardVisualState state;
  final AnimationController spinController;
  final String? errorSummary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (state) {
      case _SyncCardVisualState.syncing:
        return Row(
          children: [
            RotationTransition(
              turns: spinController,
              child: Icon(
                Icons.sync,
                color: AppTheme.navy.withValues(alpha: 0.9),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Sincronizando',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
          ],
        );
      case _SyncCardVisualState.synced:
        return Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Sincronizado',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.green.shade900,
              ),
            ),
          ],
        );
      case _SyncCardVisualState.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Error de sincronización',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade900,
                  ),
                ),
              ],
            ),
            if (errorSummary != null && errorSummary!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                errorSummary!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.red.shade900,
                  height: 1.35,
                ),
              ),
            ],
          ],
        );
      case _SyncCardVisualState.pending:
        return Row(
          children: [
            Icon(
              Icons.cloud_queue,
              color: Colors.orange.shade900,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hay cambios pendientes de subir',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _PendingBulletLine extends StatelessWidget {
  const _PendingBulletLine({
    required this.count,
    required this.label,
    this.hint,
  });

  final int count;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '– ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
          ),
          Expanded(
            child: Text(
              '[$count] $label${hint != null ? ' ($hint)' : ''}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
