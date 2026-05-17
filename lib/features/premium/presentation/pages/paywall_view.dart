import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import 'premium_dashboard_view.dart';

/// Paywall simulado (sin pasarela de pago real).
class PaywallView extends StatefulWidget {
  const PaywallView({super.key});

  @override
  State<PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends State<PaywallView> {
  bool _loading = false;

  Future<void> _subscribe() async {
    setState(() => _loading = true);
    final result = await context.read<AuthCubit>().activatePremium();
    if (!mounted) return;
    setState(() => _loading = false);

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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const PremiumDashboardView(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serif = GoogleFonts.playfairDisplay;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('LifeTime Premium'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Icon(
                Icons.auto_awesome,
                size: 56,
                color: AppTheme.navy.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 20),
              Text(
                'Tu bitácora,\nen la nube',
                textAlign: TextAlign.center,
                style: serif(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Respalda fotos y vídeos en Google Drive, sincroniza entre dispositivos '
                'y explora tu red de personas con vistas Premium.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.black87,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              _BenefitRow(
                icon: Icons.cloud_upload_outlined,
                text: 'Copia de seguridad en Google Drive',
              ),
              _BenefitRow(
                icon: Icons.hub_outlined,
                text: 'Árbol genealógico interactivo',
              ),
              _BenefitRow(
                icon: Icons.bubble_chart_outlined,
                text: 'Constelaciones de tus círculos sociales',
              ),
              _BenefitRow(
                icon: Icons.sync_outlined,
                text: 'Sincronización con Supabase',
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.navy.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '3,99 €',
                      style: serif(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy,
                      ),
                    ),
                    Text(
                      'al mes · cancela cuando quieras',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _subscribe,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Suscribirse',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                'Simulación de compra: no se realizará ningún cargo. '
                'Se activará Premium en este dispositivo y en tu perfil de nube.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black45,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.navy, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.navy,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
