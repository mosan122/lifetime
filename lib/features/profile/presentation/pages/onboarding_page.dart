import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/user_profile_details.dart';
import '../utils/onboarding_prefill.dart';
import '../widgets/user_profile_form.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  UserProfileDetails? _initial;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<AuthCubit>().state;
      if (!mounted) return;
      if (s is AuthAuthenticated) {
        setState(() {
          _initial = onboardingInitialFromAuth(
            user: s.user,
            isPremium: s.isPremium,
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initial == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.navy)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenido a LifeTime'),
        automaticallyImplyLeading: false,
      ),
      body: UserProfileForm(
        key: ValueKey(_initial!.userId),
        initial: _initial!,
        submitLabel: 'Continuar',
        isBusy: _busy,
        onSubmit: (details, bytes) async {
          setState(() => _busy = true);
          final r = await context.read<AuthCubit>().saveUserProfile(
                details: details,
                newAvatarBytes: bytes,
              );
          if (!mounted) return;
          setState(() => _busy = false);
          r.fold(
            (f) => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(f.message)),
            ),
            (_) {},
          );
        },
      ),
    );
  }
}
