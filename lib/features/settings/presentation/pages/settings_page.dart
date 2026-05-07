import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import 'manage_people_page.dart';
import 'manage_categories_page.dart';
import 'manage_locations_page.dart';
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
                  builder: (_) => const ManageLocationsPage(),
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
