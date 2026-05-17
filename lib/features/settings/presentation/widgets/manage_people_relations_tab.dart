import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/premium_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/presentation/bloc/relationship_tree_cubit.dart';
import '../../../milestones/presentation/pages/relationship_tree_view.dart';
import '../../../premium/presentation/pages/paywall_view.dart';

/// Grafo de relaciones con la ficha del usuario (cuenta vinculada) en el centro.
class ManagePeopleRelationsTab extends StatefulWidget {
  const ManagePeopleRelationsTab({super.key});

  @override
  State<ManagePeopleRelationsTab> createState() =>
      _ManagePeopleRelationsTabState();
}

class _ManagePeopleRelationsTabState extends State<ManagePeopleRelationsTab> {
  String? _centerPersonId;
  bool _loading = true;
  String? _emptyMessage;

  @override
  void initState() {
    super.initState();
    _resolveCenterPerson();
  }

  Future<void> _resolveCenterPerson() async {
    final userId =
        (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
    if (userId.isEmpty) {
      setState(() {
        _loading = false;
        _emptyMessage = 'Inicia sesión para ver tu red de relaciones.';
      });
      return;
    }

    final person =
        await sl<IsarPersonDataSource>().fetchByLinkedUserId(userId);
    if (!mounted) return;

    if (person == null) {
      setState(() {
        _loading = false;
        _emptyMessage =
            'Completa tu perfil en «Mi perfil» para ver el mapa de relaciones centrado en ti.';
      });
      return;
    }

    setState(() {
      _centerPersonId = person.id;
      _loading = false;
      _emptyMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!sl<PremiumService>().isPremium) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hub_outlined,
                size: 48,
                color: AppTheme.navy.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 16),
              Text(
                'El mapa de relaciones está disponible con Premium.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PaywallView(),
                    ),
                  );
                },
                child: const Text('Ver Premium'),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final msg = _emptyMessage;
    if (msg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.black54,
                ),
          ),
        ),
      );
    }

    final personId = _centerPersonId;
    if (personId == null) {
      return const SizedBox.shrink();
    }

    return BlocProvider(
      create: (_) => sl<RelationshipTreeCubit>()..setCenterPerson(personId),
      child: const RelationshipTreeCanvas(),
    );
  }
}
