import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_flags.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../sync/presentation/bloc/sync_status_cubit.dart';

/// Indicador de sincronización premium en el timeline (AppBar + franja informativa).
class TimelineSyncStatusIndicator extends StatefulWidget {
  const TimelineSyncStatusIndicator({super.key});

  @override
  State<TimelineSyncStatusIndicator> createState() =>
      _TimelineSyncStatusIndicatorState();
}

class _TimelineSyncStatusIndicatorState extends State<TimelineSyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppFlags.kIsCloudEnabled) return const SizedBox.shrink();
    final auth = context.watch<AuthCubit>().state;
    if (auth is! AuthAuthenticated || !auth.isPremium) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<SyncStatusCubit, SyncStatusState>(
      builder: (context, sync) {
        if (sync.showSuccessCheck) {
          return Tooltip(
            message: sync.displayMessage ?? 'Sincronización completada',
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.check_circle_outline,
                size: 20,
                color: AppTheme.navy.withValues(alpha: 0.65),
              ),
            ),
          );
        }

        if (sync.phase == SyncPhase.syncingMetadata) {
          return Tooltip(
            message: sync.displayMessage ?? 'Sincronizando metadatos',
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.35, end: 1).animate(
                  CurvedAnimation(parent: _blink, curve: Curves.easeInOut),
                ),
                child: Icon(
                  Icons.cloud_sync_outlined,
                  size: 20,
                  color: AppTheme.navy.withValues(alpha: 0.85),
                ),
              ),
            ),
          );
        }

        if (sync.phase == SyncPhase.syncingMedia) {
          return Tooltip(
            message: sync.displayMessage ?? 'Sincronizando medios',
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.navy.withValues(alpha: 0.85),
                ),
              ),
            ),
          );
        }

        if (sync.phase == SyncPhase.error) {
          return Tooltip(
            message: sync.errorMessage ?? 'Error de sincronización',
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 20,
                color: Colors.red.shade700.withValues(alpha: 0.85),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

/// Franja bajo el AppBar con mensaje y barra de progreso durante la sync.
class TimelineSyncMediaProgressBar extends StatelessWidget {
  const TimelineSyncMediaProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppFlags.kIsCloudEnabled) return const SizedBox.shrink();
    final auth = context.watch<AuthCubit>().state;
    if (auth is! AuthAuthenticated || !auth.isPremium) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<SyncStatusCubit, SyncStatusState>(
      builder: (context, sync) {
        final visible = sync.isBusy ||
            sync.showSuccessCheck ||
            sync.phase == SyncPhase.error;
        if (!visible) return const SizedBox.shrink();

        final message = sync.displayMessage;
        final isMedia = sync.phase == SyncPhase.syncingMedia;
        final isError = sync.phase == SyncPhase.error;
        final isSuccess = sync.showSuccessCheck;

        return Material(
          color: isError
              ? Colors.red.shade50
              : isSuccess
                  ? AppTheme.navy.withValues(alpha: 0.06)
                  : AppTheme.cream,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message != null && message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: Row(
                    children: [
                      Icon(
                        isError
                            ? Icons.error_outline
                            : isSuccess
                                ? Icons.check_circle_outline
                                : isMedia
                                    ? Icons.photo_library_outlined
                                    : Icons.cloud_outlined,
                        size: 16,
                        color: isError
                            ? Colors.red.shade700
                            : AppTheme.navy.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: isError
                                    ? Colors.red.shade800
                                    : AppTheme.navy.withValues(alpha: 0.82),
                                height: 1.2,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isMedia || sync.phase == SyncPhase.syncingMetadata)
                SizedBox(
                  height: 2,
                  width: double.infinity,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: const Color(0x14000080),
                    color: AppTheme.navy,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
