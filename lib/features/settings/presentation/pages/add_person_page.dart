import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/presentation/widgets/quick_create_person_sheet.dart';
import '../bloc/people_cubit.dart';

/// Creación rápida desde Personas: mismo formulario que al añadir desde un hito.
/// Grupo, cumpleaños, notas y email se gestionan al editar la ficha.
class AddPersonPage extends StatelessWidget {
  const AddPersonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva persona')),
      body: QuickCreatePersonForm(
        personDs: sl<IsarPersonDataSource>(),
        showHeaderBar: false,
        title: 'Nueva persona',
        submitLabel: 'Guardar',
        onSubmitted: (ctx, _) async {
          await ctx.read<PeopleCubit>().reload();
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }
}
