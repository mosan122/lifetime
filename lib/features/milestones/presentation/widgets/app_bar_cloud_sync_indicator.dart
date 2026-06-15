import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/notifiers/cloud_sync_activity_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';

/// Icono giratorio en el AppBar mientras hay sincronización activa (Premium).
class AppBarCloudSyncIndicator extends StatefulWidget {
  const AppBarCloudSyncIndicator({super.key, this.iconColor});

  final Color? iconColor;

  @override
  State<AppBarCloudSyncIndicator> createState() =>
      _AppBarCloudSyncIndicatorState();
}

class _AppBarCloudSyncIndicatorState extends State<AppBarCloudSyncIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  CloudSyncActivityNotifier? _notifier;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (sl.isRegistered<CloudSyncActivityNotifier>()) {
      _notifier = sl<CloudSyncActivityNotifier>()..addListener(_onActivity);
    }
  }

  void _onActivity() {
    if (!mounted) return;
    final active = _notifier?.isActive ?? false;
    if (active && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!active && _spin.isAnimating) {
      _spin.stop();
      _spin.reset();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _notifier?.removeListener(_onActivity);
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    if (auth is! AuthAuthenticated || !auth.isPremium) {
      return const SizedBox.shrink();
    }

    final active = _notifier?.isActive ?? false;
    if (!active) return const SizedBox.shrink();

    if (!_spin.isAnimating) {
      _spin.repeat();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: 'Sincronizando con la nube',
        child: RotationTransition(
          turns: _spin,
          child: Icon(
            Icons.sync,
            color: widget.iconColor ?? AppTheme.navy,
            size: 22,
          ),
        ),
      ),
    );
  }
}
