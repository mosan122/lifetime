import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../milestones/presentation/pages/timeline_page.dart';
import '../../../profile/presentation/pages/onboarding_page.dart';
import '../bloc/auth_cubit.dart';
import '../pages/auth_page.dart';
import '../pages/verification_pending_page.dart';

/// Enruta entre login, verificación pendiente y timeline según [AuthCubit].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticating) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.navy),
            ),
          );
        }
        if (state is AuthAuthenticated && state.user.emailVerified) {
          if (state.needsOnboarding) {
            return const OnboardingPage();
          }
          return const TimelinePage();
        }
        if (state is AuthPendingVerification) {
          return VerificationPendingPage(email: state.email);
        }
        return const AuthPage();
      },
    );
  }
}
