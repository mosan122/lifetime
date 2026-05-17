import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/premium_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../data/models/local/group_collection.dart';
import '../../data/models/local/person_collection.dart';
import '../bloc/group_graph_cubit.dart';
import '../bloc/group_graph_state.dart';
import '../utils/group_constellation_layout.dart';
import '../widgets/group_constellation_connection_painter.dart';
import '../widgets/group_constellation_milestones_sheet.dart';
import '../widgets/group_constellation_nodes.dart';
import '../widgets/relationship_tree_person_sheet.dart';

/// Constelación de un círculo social / grupo (Premium).
class GroupConstellationView extends StatelessWidget {
  const GroupConstellationView({
    super.key,
    required this.groupId,
  });

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final premium = sl<PremiumService>().isPremium;
    return BlocProvider(
      create: (_) => sl<GroupGraphCubit>()..loadGroup(groupId),
      child: Scaffold(
        backgroundColor: AppTheme.cream,
        appBar: AppBar(
          title: const Text('Constelación del grupo'),
        ),
        body: premium
            ? const _GroupConstellationCanvas()
            : const _GroupConstellationPremiumGate(),
      ),
    );
  }
}

class _GroupConstellationPremiumGate extends StatelessWidget {
  const _GroupConstellationPremiumGate();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bubble_chart_outlined,
              size: 56,
              color: AppTheme.navy.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'La visualización de círculos sociales está disponible con Premium.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.navy,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupConstellationCanvas extends StatefulWidget {
  const _GroupConstellationCanvas();

  @override
  State<_GroupConstellationCanvas> createState() =>
      _GroupConstellationCanvasState();
}

class _GroupConstellationCanvasState extends State<_GroupConstellationCanvas> {
  final TransformationController _transform = TransformationController();
  bool _initialViewportDone = false;

  static const Offset _center = GroupConstellationLayout.canvasCenter;
  static const double _canvasSize = GroupConstellationLayout.canvasSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerViewport());
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _centerViewport() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      _transform.value = Matrix4.identity()
        ..translateByDouble(
          -_center.dx + 200,
          -_center.dy + 200,
          0,
          1,
        );
      return;
    }
    final vp = box.size;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        vp.width / 2 - _center.dx,
        vp.height / 2 - _center.dy,
        0,
        1,
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupGraphCubit, GroupGraphState>(
      listener: (context, state) {
        if (!_initialViewportDone &&
            state.status == GroupGraphStatus.loaded) {
          _initialViewportDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _centerViewport();
          });
        }
      },
      builder: (context, state) {
        if (state.status == GroupGraphStatus.error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(state.errorMessage ?? 'Error al cargar el grupo.'),
            ),
          );
        }

        if (state.isLoading && state.group == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final group = state.group;
        if (group == null) {
          return const Center(child: Text('Grupo no encontrado.'));
        }

        final positions = GroupConstellationLayout.orbitPositions(
          count: state.members.length,
        );

        final connections = <GroupConstellationConnection>[
          for (var i = 0; i < state.members.length; i++)
            GroupConstellationConnection(
              from: _center,
              to: positions[i],
            ),
        ];

        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _transform,
              constrained: false,
              minScale: 0.35,
              maxScale: 3.5,
              boundaryMargin: const EdgeInsets.all(480),
              child: SizedBox(
                width: _canvasSize,
                height: _canvasSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: const Size(_canvasSize, _canvasSize),
                      painter: GroupConstellationConnectionPainter(
                        connections: connections,
                      ),
                    ),
                    _positionedGroupNode(
                      center: _center,
                      group: group,
                      onTap: () => showGroupConstellationMilestonesSheet(
                        context,
                        groupName: group.name,
                        milestones: state.linkedMilestones,
                      ),
                    ),
                    for (var i = 0; i < state.members.length; i++)
                      _positionedMemberNode(
                        center: positions[i],
                        member: state.members[i],
                        groupName: group.name,
                      ),
                  ],
                ),
              ),
            ),
            if (state.isLoading)
              const Positioned(
                top: 12,
                right: 12,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _positionedGroupNode({
    required Offset center,
    required GroupCollection group,
    required VoidCallback onTap,
  }) {
    const halfW = GroupConstellationGroupNode.width / 2;
    const topOffset = GroupConstellationGroupNode.diameter / 2;

    return Positioned(
      left: center.dx - halfW,
      top: center.dy - topOffset,
      child: GroupConstellationGroupNode(
        groupId: group.id,
        name: group.name,
        onTap: onTap,
      ),
    );
  }

  Widget _positionedMemberNode({
    required Offset center,
    required PersonCollection member,
    required String groupName,
  }) {
    const halfW = GroupConstellationMemberNode.width / 2;
    const topOffset = GroupConstellationMemberNode.avatarSize / 2;

    return Positioned(
      left: center.dx - halfW,
      top: center.dy - topOffset,
      child: GroupConstellationMemberNode(
        name: member.name,
        faceImagePath: member.faceImagePath,
        onTap: () => showRelationshipTreePersonSheet(
          context,
          person: member,
          kinshipLabel: groupName,
        ),
      ),
    );
  }
}
