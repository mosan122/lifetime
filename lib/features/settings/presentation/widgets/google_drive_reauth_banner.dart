import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';

/// Aviso cuando Drive requiere volver a vincular Google.
class GoogleDriveReauthBanner extends StatelessWidget {
  const GoogleDriveReauthBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (prev, next) {
        if (prev is AuthAuthenticated && next is AuthAuthenticated) {
          return prev.requiresGoogleReauth != next.requiresGoogleReauth ||
              prev.googleDriveLinked != next.googleDriveLinked;
        }
        return prev.runtimeType != next.runtimeType;
      },
      builder: (context, auth) {
        if (auth is! AuthAuthenticated) return const SizedBox.shrink();

        if (auth.requiresGoogleReauth) {
          return _DriveBanner(
            color: Colors.orange.shade50,
            borderColor: Colors.orange.shade700,
            icon: Icons.cloud_off_outlined,
            message:
                'Tu sesión de Google Drive ha expirado. Pulsa aquí para volver a conectar.',
            onTap: () => _reconnect(context),
          );
        }

        if (auth.isPremium && !auth.googleDriveLinked) {
          return _DriveBanner(
            color: AppTheme.cream,
            borderColor: AppTheme.navy.withValues(alpha: 0.35),
            icon: Icons.add_to_drive_outlined,
            message:
                'Conecta Google Drive para respaldar fotos y vídeos de tus hitos.',
            onTap: () => _reconnect(context),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _reconnect(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await context.read<AuthCubit>().linkGoogleAccount();
    if (!context.mounted) return;
    result.fold(
      (f) => messenger.showSnackBar(
        SnackBar(
          content: Text(f.message),
          backgroundColor: Colors.red.shade700,
        ),
      ),
      (_) => messenger.showSnackBar(
        const SnackBar(
          content: Text('Google Drive conectado correctamente.'),
        ),
      ),
    );
  }
}

class _DriveBanner extends StatelessWidget {
  const _DriveBanner({
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.message,
    required this.onTap,
  });

  final Color color;
  final Color borderColor;
  final IconData icon;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: borderColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Icon(Icons.chevron_right, color: borderColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
