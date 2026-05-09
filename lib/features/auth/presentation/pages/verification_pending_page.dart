import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_cubit.dart';

class VerificationPendingPage extends StatefulWidget {
  const VerificationPendingPage({
    super.key,
    required this.email,
    this.fromRegistration = false,
  });

  final String email;
  final bool fromRegistration;

  @override
  State<VerificationPendingPage> createState() =>
      _VerificationPendingPageState();
}

class _VerificationPendingPageState extends State<VerificationPendingPage> {
  bool _sending = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    final r = await context.read<AuthCubit>().resendSignupEmail(widget.email);
    if (!mounted) return;
    setState(() => _sending = false);
    r.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message)),
      ),
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Te hemos vuelto a enviar el correo.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifica tu correo'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await context.read<AuthCubit>().signOut();
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.mark_email_unread_outlined,
                size: 72,
                color: AppTheme.navy.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 24),
              Text(
                'Revisa tu correo',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Te hemos enviado un enlace de confirmación a\n${widget.email}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Abre el enlace y vuelve a la app; si ya verificaste, pulsa «Ya he verificado».',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _sending ? null : _resend,
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reenviar correo'),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  await context
                      .read<AuthCubit>()
                      .refreshAfterEmailVerification();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Ya he verificado'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await context.read<AuthCubit>().signOut();
                  if (context.mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Volver al inicio de sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
