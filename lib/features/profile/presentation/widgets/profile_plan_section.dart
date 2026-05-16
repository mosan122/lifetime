import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';

/// Bloque Plan en Mi perfil (Standard vs Premium).
class ProfilePlanSection extends StatelessWidget {
  const ProfilePlanSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isPremium = state is AuthAuthenticated && state.isPremium;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isPremium
                    ? 'Tu plan actual es: Plan Premium'
                    : 'Tu plan actual es: Plan Standard',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                isPremium
                    ? 'Tus datos de LifeTime pueden guardarse en la nube. '
                        'Sincroniza fotos y vídeos de tus hitos con tu espacio '
                        'Google Drive o iCloud y libera espacio en tu móvil.'
                    : 'Tus datos se guardan únicamente en tu dispositivo. Si te '
                        'pasas al plan Premium los datos de tu LifeTime se '
                        'guardarán en la nube y podrás sincronizar las fotos y '
                        'videos de tus hitos con tu espacio Google Drive o '
                        'iCloud y ahorrar espacio en tu móvil.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black87,
                      height: 1.45,
                    ),
              ),
              if (!isPremium) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () =>
                      context.read<AuthCubit>().setPremium(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Pasar a Premium'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
