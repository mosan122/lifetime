import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
import '../widgets/group_members_preview.dart';
import '../widgets/relationship_tree_person_sheet.dart';

const _kMaxConstellationOrbitMembers = 20;

/// Constelación de un círculo social / grupo (Premium).
class GroupConstellationView extends StatelessWidget {
  const GroupConstellationView({
    super.key,
    required this.groupId,
  });

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GroupGraphCubit>()..loadGroup(groupId),
      child: Scaffold(
        backgroundColor: AppTheme.cream,
        appBar: AppBar(
          title: const Text('Constelación del grupo'),
        ),
        body: const _GroupConstellationCanvas(),
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

        final orbitMembers = state.members.length > _kMaxConstellationOrbitMembers
            ? state.members.take(_kMaxConstellationOrbitMembers).toList()
            : state.members;

        final positions = GroupConstellationLayout.orbitPositions(
          count: orbitMembers.length,
        );

        final connections = <GroupConstellationConnection>[
          for (var i = 0; i < orbitMembers.length; i++)
            GroupConstellationConnection(
              from: _center,
              to: positions[i],
            ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
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
                          for (var i = 0; i < orbitMembers.length; i++)
                            _positionedMemberNode(
                              center: positions[i],
                              member: orbitMembers[i],
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
              ),
            ),
            if (state.members.length > _kMaxConstellationOrbitMembers)
              Material(
                color: AppTheme.cream,
                elevation: 6,
                shadowColor: AppTheme.navy.withValues(alpha: 0.12),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Integrantes (${state.members.length})',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.navy,
                              ),
                        ),
                        const SizedBox(height: 8),
                        GroupMembersPreview(members: state.members),
                      ],
                    ),
                  ),
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
