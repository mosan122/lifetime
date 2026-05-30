import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/premium_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../../milestones/presentation/bloc/relationship_tree_cubit.dart';
import '../../../milestones/presentation/pages/relationship_tree_view.dart';
import '../../../premium/presentation/pages/paywall_view.dart';

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
    if (!sl<PremiumService>().isPremium) {
      return SizedBox(
        height: height,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hub_outlined,
                  size: 40,
                  color: AppTheme.navy.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 12),
                Text(
                  'El mapa de relaciones está disponible con Premium.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: 16),
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
        ),
      );
    }

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
