import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../milestones/presentation/bloc/relationship_tree_cubit.dart';
import '../../../milestones/presentation/pages/relationship_tree_view.dart';

/// Grafo de relaciones centrado en una persona concreta (vista de ficha).
class PersonDetailRelationshipTree extends StatelessWidget {
  const PersonDetailRelationshipTree({
    super.key,
    required this.personId,
    this.height = 360,
  });

  final String personId;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.navy.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.navy.withValues(alpha: 0.08),
            ),
          ),
          child: BlocProvider(
            create: (_) =>
                sl<RelationshipTreeCubit>()..setCenterPerson(personId),
            child: const RelationshipTreeCanvas(),
          ),
        ),
      ),
    );
  }
}
