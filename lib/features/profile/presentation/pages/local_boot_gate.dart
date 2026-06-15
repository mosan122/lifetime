import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/models/local/person_collection.dart';
import '../../../milestones/presentation/pages/timeline_page.dart';
import 'local_onboarding_view.dart';

/// Arranque en modo Local-First (sin Supabase).
///
/// Consulta Isar al iniciar: si no existe un usuario raíz ([getRootUser] es
/// `null`) muestra el onboarding local; si existe, entra directo a la bitácora.
class LocalBootGate extends StatefulWidget {
  const LocalBootGate({super.key});

  @override
  State<LocalBootGate> createState() => _LocalBootGateState();
}

class _LocalBootGateState extends State<LocalBootGate> {
  late Future<PersonCollection?> _rootUserFuture;

  @override
  void initState() {
    super.initState();
    _rootUserFuture = sl<IsarPersonDataSource>().getRootUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PersonCollection?>(
      future: _rootUserFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppTheme.cream,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.navy),
            ),
          );
        }
        if (snapshot.data == null) {
          return const LocalOnboardingView();
        }
        return const TimelinePage();
      },
    );
  }
}
