import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_cubit.dart';
import 'login_page.dart';
import 'register_page.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  bool get _showApple =>
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.auto_stories_outlined,
                size: 80,
                color: AppTheme.navy.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 28),
              Text(
                'LifeTime',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: AppTheme.navy,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tu bitácora personal, conectada a tu espacio seguro.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.navy,
                    elevation: 1,
                    side: const BorderSide(color: AppTheme.navy, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text(
                    'Continuar con Google',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  onPressed: () =>
                      context.read<AuthCubit>().signInWithGoogle(),
                ),
              ),
              if (_showApple) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.apple, size: 26),
                    label: const Text(
                      'Continuar con Apple',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    onPressed: () =>
                        context.read<AuthCubit>().signInWithApple(),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 54,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.navy,
                    side: const BorderSide(color: AppTheme.navy, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => BlocProvider.value(
                          value: context.read<AuthCubit>(),
                          child: const LoginPage(),
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Entrar con email',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider.value(
                        value: context.read<AuthCubit>(),
                        child: const RegisterPage(),
                      ),
                    ),
                  );
                },
                child: const Text('Crear cuenta con email'),
              ),
              BlocBuilder<AuthCubit, AuthState>(
                buildWhen: (p, c) =>
                    p is AuthUnauthenticated && c is AuthUnauthenticated,
                builder: (context, state) {
                  if (state is AuthUnauthenticated && state.error != null) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        state.error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red.shade800,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
