import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/person_ui_filters.dart';
import '../../../../core/utils/bitacora_backup_json.dart';
import '../../../../core/utils/picked_file_utf8_text.dart';
import '../../../../core/services/bitacora_drive_import_probe.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/services/cloud_sync_status_store.dart';
import '../../../../core/services/premium_service.dart';
import '../../../sync/data/services/sync_service.dart';
import '../../../sync/schedule_cloud_sync.dart';
import '../../../../injection_container.dart';
import '../../../profile/domain/entities/user_profile_details.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import 'manage_people_page.dart';
import 'manage_locations_page.dart';
import 'manage_categories_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../bloc/export_cubit.dart';
import '../bloc/import_cubit.dart';
import '../bloc/people_cubit.dart';
import '../widgets/account_settings_widgets.dart';
import '../widgets/google_drive_reauth_banner.dart';
import '../../../premium/presentation/pages/paywall_view.dart';
import '../../../premium/presentation/pages/premium_dashboard_view.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<ExportCubit>()),
        BlocProvider(create: (_) => sl<ImportCubit>()),
      ],
      child: const _SettingsView(),
    );
  }
}

Future<void> _handleBitacoraImportSuccess(
  BuildContext context,
  ImportSuccess state,
) async {
  var message = state.imported == 0
      ? 'Importación completada (0 hitos nuevos).'
      : 'Importados ${state.imported} hito${state.imported == 1 ? '' : 's'}.';

  final auth = context.read<AuthCubit>().state;
  if (auth is AuthAuthenticated && auth.isPremium) {
    if (sl.isRegistered<SyncService>()) {
      await sl<SyncService>().markAllLocalRowsPending();
      scheduleCloudDataSyncAfterLocalRestore();
    }
    if (sl.isRegistered<CloudSyncService>()) {
      final restore =
          await sl<CloudSyncService>().restoreMilestoneMediaFromDrive(force: true);
      if (restore.anyWork) {
        message +=
            ' Medios enlazados desde Drive: ${restore.filesLinked} archivo(s) '
            'en ${restore.milestonesTouched} hito(s).';
      }
    }
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
  context.read<ImportCubit>().reset();
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  static Future<void> runBitacoraImport(BuildContext context) async {
    final importCubit = context.read<ImportCubit>();
    if (importCubit.state is ImportLoading) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (!context.mounted) return;
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    String? text;
    try {
      text = await readPickedFileAsUtf8Text(picked);
    } on FormatException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El archivo no es UTF-8 válido.')),
      );
      return;
    }
    if (text == null || text.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo.')),
      );
      return;
    }
    final n = BitacoraBackupJson.countMilestones(text);
    if (!context.mounted) return;
    if (n == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontraron hitos válidos en el JSON.'),
        ),
      );
      return;
    }

    var driveFolderHint = '';
    if (sl<PremiumService>().isPremium &&
        sl.isRegistered<BitacoraDriveImportProbe>()) {
      final probe = await sl<BitacoraDriveImportProbe>().probeFromJson(text);
      if (probe.hasMatches && context.mounted) {
        driveFolderHint =
            '\n\nCarpetas de imágenes anteriores detectadas en Google Drive '
            '(LifeTime_App/Media): ${probe.count} hito(s) con archivos que coinciden '
            'por id. Tras importar se intentará reconstruir los medios desde la nube.';
      }
    }
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar hitos'),
        content: Text(
          'Se importarán $n hito(s). En archivos v3 también se fusionan personas, '
          'categorías personalizadas, lugares favoritos, grupos, enlaces y relaciones '
          'cuando el JSON las incluya. Los hitos con el mismo id sustituyen al local.'
          '$driveFolderHint\n\n'
          '¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await importCubit.importJson(text);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ExportCubit, ExportState>(
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
        ),
        BlocListener<ImportCubit, ImportState>(
          listener: (context, state) {
            if (state is ImportSuccess) {
              unawaited(_handleBitacoraImportSuccess(context, state));
            }
            if (state is ImportError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red.shade700,
                ),
              );
              context.read<ImportCubit>().reset();
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Ajustes')),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const GoogleDriveReauthBanner(),
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
            const SettingsSectionHeader(label: 'Mis datos'),
            const _UpcomingBirthdaysTile(),
            ListTile(
              leading: const Icon(Icons.people_outline, color: AppTheme.navy),
              title: const Text('Personas'),
              subtitle: const Text(
                'Contactos en hitos; tu nombre, foto y cumple en Mi perfil',
              ),
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
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, auth) {
                if (auth is! AuthAuthenticated) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    const SettingsSectionHeader(label: 'Premium'),
                    ListTile(
                      leading: Icon(
                        auth.isPremium
                            ? Icons.workspace_premium_outlined
                            : Icons.star_outline,
                        color: AppTheme.navy,
                      ),
                      title: Text(
                        auth.isPremium ? 'Panel Premium' : 'Pasar a Premium',
                      ),
                      subtitle: Text(
                        auth.isPremium
                            ? 'Almacenamiento, Drive y sincronización'
                            : 'Respaldo en la nube y funciones avanzadas',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppTheme.navy,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => auth.isPremium
                                ? const PremiumDashboardView()
                                : const PaywallView(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                  ],
                );
              },
            ),
            const SettingsSectionHeader(label: 'Copia de seguridad'),
            const _CloudBackupStatusTile(),
            const _ExportTile(),
            const _ImportTile(),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exportar bitácora',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'JSON completo (v2) para copia de seguridad e importación en esta u otra instalación.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.data_object_outlined,
                  color: AppTheme.navy),
              title: const Text('JSON'),
              subtitle: const Text('Compartir archivo .json'),
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
              leading: const Icon(Icons.copy_outlined, color: AppTheme.navy),
              title: const Text('Copiar JSON'),
              subtitle: const Text('Al portapapeles en este dispositivo'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: jsonContent));
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('JSON copiado al portapapeles'),
                    ),
                  );
                }
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

Future<({List<PersonCollection> contacts, UserProfileDetails? profile})>
    _loadBirthdaysContext() async {
  final ds = sl<IsarPersonDataSource>();
  final repo = sl<ProfileRepository>();
  final supa = sl<SupabaseClient>();
  final raw = await ds.fetchAll();
  final contacts = withoutLinkedCurrentUser(raw);
  final u = supa.auth.currentUser;
  UserProfileDetails? profile;
  if (u != null) {
    final r = await repo.fetchUserProfile(
      userId: u.id,
      emailFallback: u.email ?? '',
    );
    profile = r.fold((_) => null, (d) => d);
  }
  return (contacts: contacts, profile: profile);
}

List<(String name, DateTime next)> _mergedUpcomingBirthdays(
  List<PersonCollection> contacts,
  UserProfileDetails? selfProfile, {
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

  final out = <(String, DateTime)>[];
  for (final p in contacts) {
    final b = p.birthDate;
    if (b == null) continue;
    final n = p.name.trim();
    if (n.isEmpty) continue;
    final nx = nextBirthday(b);
    if (nx.difference(now).inDays <= daysAhead) {
      out.add((n, nx));
    }
  }
  final sb = selfProfile?.birthDate;
  if (sb != null) {
    final nx = nextBirthday(sb);
    if (nx.difference(now).inDays <= daysAhead) {
      final dn = (selfProfile!.displayName).trim();
      final fn = (selfProfile.firstName ?? '').trim();
      final ln = (selfProfile.lastName ?? '').trim();
      final composed =
          [fn, ln].where((s) => s.isNotEmpty).join(' ').trim();
      final name = dn.isNotEmpty
          ? dn
          : (composed.isNotEmpty ? composed : selfProfile.email);
      out.add((name, nx));
    }
  }
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

class _UpcomingBirthdaysTile extends StatefulWidget {
  const _UpcomingBirthdaysTile();

  @override
  State<_UpcomingBirthdaysTile> createState() => _UpcomingBirthdaysTileState();
}

class _UpcomingBirthdaysTileState extends State<_UpcomingBirthdaysTile> {
  late final Future<
      ({List<PersonCollection> contacts, UserProfileDetails? profile})> _future =
      _loadBirthdaysContext();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({List<PersonCollection> contacts, UserProfileDetails? profile})>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final upcoming = _mergedUpcomingBirthdays(
          data.contacts,
          data.profile,
          daysAhead: 21,
        );
        if (upcoming.isEmpty) return const SizedBox.shrink();

        final names = upcoming.take(2).map((t) => t.$1).join(', ');
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
                      final name = t.$1;
                      final d = t.$2;
                      final dd =
                          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(name),
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

class _CloudBackupStatusTile extends StatefulWidget {
  const _CloudBackupStatusTile();

  @override
  State<_CloudBackupStatusTile> createState() => _CloudBackupStatusTileState();
}

class _CloudBackupStatusTileState extends State<_CloudBackupStatusTile> {
  @override
  void initState() {
    super.initState();
    if (sl.isRegistered<CloudSyncStatusStore>()) {
      unawaited(sl<CloudSyncStatusStore>().hydrate());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        if (auth is! AuthAuthenticated || !auth.isPremium) {
          return const SizedBox.shrink();
        }
        if (!sl.isRegistered<CloudSyncStatusStore>()) {
          return const SizedBox.shrink();
        }
        final store = sl<CloudSyncStatusStore>();
        return ValueListenableBuilder<DateTime?>(
          valueListenable: store.lastSuccessUtc,
          builder: (context, lastUtc, _) {
            final subtitle = lastUtc == null
                ? 'Aún no hay una copia completa en la nube. Sincroniza con Premium.'
                : 'Última copia en nube: ${CloudSyncStatusStore.formatForDisplay(lastUtc)}';
            return ListTile(
              leading: const Icon(Icons.cloud_done_outlined, color: AppTheme.navy),
              title: const Text('Respaldo en la nube'),
              subtitle: Text(subtitle),
            );
          },
        );
      },
    );
  }
}

class _ImportTile extends StatelessWidget {
  const _ImportTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImportCubit, ImportState>(
      builder: (context, state) {
        final loading = state is ImportLoading;
        return ListTile(
          leading: const Icon(Icons.upload_file_outlined, color: AppTheme.navy),
          title: const Text('Importar hitos'),
          subtitle: const Text(
            'JSON v3 exportado desde LifeTime (hitos y datos de agenda)',
          ),
          trailing: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.navy,
                  ),
                )
              : const Icon(Icons.chevron_right, color: AppTheme.navy),
          onTap: loading ? null : () => _SettingsView.runBitacoraImport(context),
        );
      },
    );
  }
}

// ── Export tile ───────────────────────────────────────────────────────────────

class _ExportTile extends StatelessWidget {
  const _ExportTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExportCubit, ExportState>(
      builder: (context, state) {
        final isLoading = state is ExportLoading;
        return ListTile(
          leading: const Icon(Icons.download_outlined, color: AppTheme.navy),
          title: const Text('Exportar datos'),
          subtitle: const Text(
            'JSON v3 (hitos + agenda) o Markdown: participantes, etiquetas, medios',
          ),
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

