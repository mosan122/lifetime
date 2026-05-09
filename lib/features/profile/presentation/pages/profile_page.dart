import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/user_profile_details.dart';
import '../../domain/repositories/profile_repository.dart';
import '../widgets/user_profile_form.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserProfileDetails? _details;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthAuthenticated) return;
    final r = await sl<ProfileRepository>().fetchUserProfile(
      userId: auth.user.id,
      emailFallback: auth.user.email,
    );
    if (!mounted) return;
    r.fold(
      (f) => setState(() {
        _error = f.message;
        _loading = false;
      }),
      (d) => setState(() {
        _details = d;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.navy),
            )
          : _error != null
              ? Center(child: Text(_error!))
              : _details == null
                  ? const Center(child: Text('Sin datos de perfil'))
                  : UserProfileForm(
                      key: ObjectKey(_details),
                      initial: _details!,
                      submitLabel: 'Guardar cambios',
                      isBusy: _saving,
                      onSubmit: (d, bytes) async {
                        setState(() => _saving = true);
                        final r = await context.read<AuthCubit>().saveUserProfile(
                              details: d,
                              newAvatarBytes: bytes,
                            );
                        if (!mounted) return;
                        setState(() => _saving = false);
                        r.fold(
                          (f) => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(f.message)),
                          ),
                          (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Perfil actualizado')),
                            );
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
    );
  }
}
