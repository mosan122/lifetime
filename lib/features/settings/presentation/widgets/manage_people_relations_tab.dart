import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../injection_container.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/presentation/bloc/relationship_tree_cubit.dart';
import '../../../milestones/presentation/pages/relationship_tree_view.dart';

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
    final personDs = sl<IsarPersonDataSource>();

    // Usuario raíz local ("yo") como centro por defecto; si aún no existe,
    // recae en la persona vinculada a la sesión de Supabase (si la hubiera).
    var person = await personDs.getRootUser();
    if (person == null) {
      final userId =
          (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
      if (userId.isNotEmpty) {
        person = await personDs.fetchByLinkedUserId(userId);
      }
    }
    if (!mounted) return;

    if (person == null) {
      setState(() {
        _loading = false;
        _emptyMessage =
            'Completa tu perfil para ver el mapa de relaciones centrado en ti.';
      });
      return;
    }

    setState(() {
      _centerPersonId = person!.id;
      _loading = false;
      _emptyMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
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
