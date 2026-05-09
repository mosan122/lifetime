import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import 'manage_people_page.dart';
import 'manage_locations_page.dart';
import 'manage_categories_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../bloc/export_cubit.dart';
import '../bloc/people_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ExportCubit>(),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  List<(PersonCollection, DateTime)> _upcomingBirthdays(
    List<PersonCollection> people, {
    int daysAhead = 21,
  }) {
    final now = DateTime.now();
    DateTime nextBirthday(DateTime b) {
      final today = DateTime(now.year, now.month, now.day);
      final candidate = DateTime(now.year, b.month, b.day);
      return candidate.isBefore(today)
          ? DateTime(now.year + 1, b.month, b.day)
          : candidate;
    }

    final list = people
        .where((p) => p.birthDate != null)
        .map((p) => (p, nextBirthday(p.birthDate!)))
        .where((t) => t.$2.difference(now).inDays <= daysAhead)
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExportCubit, ExportState>(
      listener: (context, state) {
        if (state is ExportReady) {
          _showFormatSheet(context, state.result.json, state.result.markdown);
        }
        if (state is ExportError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Ajustes')),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, auth) {
                if (auth is! AuthAuthenticated) {
                  return const SizedBox.shrink();
                }
                final dn = auth.user.displayName?.trim();
                final label =
                    (dn != null && dn.isNotEmpty) ? dn : auth.user.email;
                final photo = auth.user.photoUrl;
                return Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.navy.withValues(alpha: 0.12),
                        backgroundImage: photo != null && photo.isNotEmpty
                            ? NetworkImage(photo)
                            : null,
                        child: photo == null || photo.isEmpty
                            ? Text(
                                label.isNotEmpty
                                    ? label[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.navy,
                                ),
                              )
                            : null,
                      ),
                      title: const Text('Mi perfil'),
                      subtitle: Text(label),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppTheme.navy,
                      ),
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const ProfilePage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                  ],
                );
              },
            ),
            const _SectionHeader(label: 'Plan'),
            const _PremiumTile(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Tu espacio se gestiona automáticamente: los archivos de más de un año se mantienen en la nube para ahorrar espacio en tu móvil.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            const Divider(height: 32, indent: 16, endIndent: 16),
            const _SectionHeader(label: 'Tus datos'),
            _UpcomingBirthdaysTile(
              items: _upcomingBirthdays,
            ),
            _ExportTile(),
            ListTile(
              leading: const Icon(Icons.people_outline, color: AppTheme.navy),
              title: const Text('Personas'),
              subtitle: const Text('Nombres y foto de perfil'),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.navy),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider(
                      create: (_) => sl<PeopleCubit>()..bootstrap(),
                      child: const ManagePeoplePage(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined, color: AppTheme.navy),
              title: const Text('Lugares'),
              subtitle: const Text('Tus lugares guardados'),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.navy),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ManageLocationsPage(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined, color: AppTheme.navy),
              title: const Text('Categorías'),
              subtitle: const Text('Crea y personaliza categorías'),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.navy),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ManageCategoriesPage(),
                ),
              ),
            ),
            const Divider(height: 32, indent: 16, endIndent: 16),
            const _SectionHeader(label: 'Cuenta'),
            _SignOutTile(),
          ],
        ),
      ),
    );
  }

  void _showFormatSheet(
      BuildContext context, String jsonContent, String mdContent) {
    final now = DateTime.now();
    final dateTag =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D4B8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('Elige formato',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.data_object_outlined,
                  color: AppTheme.navy),
              title: const Text('JSON'),
              subtitle: const Text('Para importar en otras apps'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _shareFile(
                  content: jsonContent,
                  filename: 'lifetime-bitacora-$dateTag.json',
                  mimeType: 'application/json',
                  subject: 'Mi Bitácora LifeTime',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined, color: AppTheme.navy),
              title: const Text('Markdown'),
              subtitle: const Text('Para leer en Obsidian o cualquier editor'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _shareFile(
                  content: mdContent,
                  filename: 'lifetime-bitacora-$dateTag.md',
                  mimeType: 'text/markdown',
                  subject: 'Mi Bitácora LifeTime',
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _shareFile({
    required String content,
    required String filename,
    required String mimeType,
    required String subject,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    await SharePlus.instance.share(
      ShareParams(
        subject: subject,
        files: [XFile.fromData(bytes, mimeType: mimeType, name: filename)],
      ),
    );
  }
}

class _UpcomingBirthdaysTile extends StatelessWidget {
  const _UpcomingBirthdaysTile({required this.items});

  final List<(PersonCollection, DateTime)> Function(List<PersonCollection>,
      {int daysAhead}) items;

  @override
  Widget build(BuildContext context) {
    final ds = sl<IsarPersonDataSource>();
    return FutureBuilder<List<PersonCollection>>(
      future: ds.fetchAll(),
      builder: (context, snapshot) {
        final people = snapshot.data ?? const <PersonCollection>[];
        final upcoming = items(people, daysAhead: 21);
        if (upcoming.isEmpty) return const SizedBox.shrink();

        final names = upcoming.take(2).map((t) => t.$1.name).join(', ');
        final more = upcoming.length > 2 ? ' +${upcoming.length - 2}' : '';

        return ListTile(
          leading: const Icon(Icons.cake_outlined, color: AppTheme.navy),
          title: const Text('Cumpleaños próximos'),
          subtitle: Text('$names$more'),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.navy),
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Cumpleaños próximos'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView(
                    shrinkWrap: true,
                    children: upcoming.map((t) {
                      final p = t.$1;
                      final d = t.$2;
                      final dd =
                          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.name),
                        subtitle: Text(dd),
                      );
                    }).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Export tile ───────────────────────────────────────────────────────────────

class _ExportTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExportCubit, ExportState>(
      builder: (context, state) {
        final isLoading = state is ExportLoading;
        return ListTile(
          leading: const Icon(Icons.download_outlined, color: AppTheme.navy),
          title: const Text('Exportar Bitácora'),
          subtitle: const Text('Descarga todos tus hitos como JSON o Markdown'),
          trailing: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.navy),
                )
              : const Icon(Icons.chevron_right, color: AppTheme.navy),
          onTap: isLoading
              ? null
              : () => context.read<ExportCubit>().export(),
        );
      },
    );
  }
}

// ── Sign-out tile ─────────────────────────────────────────────────────────────

class _SignOutTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.logout_outlined, color: Colors.red),
      title: const Text('Cerrar sesión',
          style: TextStyle(color: Colors.red)),
      subtitle: const Text('Desconectar tu Bitácora de Google Drive'),
      onTap: () => _confirmSignOut(context),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.cream,
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Desconectar tu Bitácora de Google Drive?\nTus hitos no se borrarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancelar',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(
                  color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthCubit>().signOut();
      Navigator.pop(context);
    }
  }
}

// ── Premium sync tile ─────────────────────────────────────────────────────────

class _PremiumTile extends StatelessWidget {
  const _PremiumTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (ctx, state) {
        final isPremium = state is AuthAuthenticated && state.isPremium;
        return SwitchListTile(
          secondary: Icon(
            Icons.cloud_sync_outlined,
            color: isPremium ? AppTheme.navy : Colors.grey,
          ),
          title: const Text('Sincronización en la Nube'),
          subtitle: Text(
            isPremium
                ? 'Activa · Biographer IA + Google Drive'
                : 'Desactivada · Solo almacenamiento local',
            style: TextStyle(
              color: isPremium ? AppTheme.navy : Colors.grey.shade600,
            ),
          ),
          value: isPremium,
          activeThumbColor: AppTheme.navy,
          onChanged: (v) => ctx.read<AuthCubit>().setPremium(v),
        );
      },
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.navy.withValues(alpha: 0.5),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
