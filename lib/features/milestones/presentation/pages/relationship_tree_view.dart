import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/premium_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../domain/models/relationship_tree_member.dart';
import '../bloc/relationship_tree_cubit.dart';
import '../bloc/relationship_tree_state.dart';
import '../widgets/relationship_tree_connection_painter.dart';
import '../widgets/relationship_tree_node.dart';
import '../widgets/relationship_tree_person_sheet.dart';

/// Grafo radial / árbol genealógico interactivo (Premium).
class RelationshipTreeView extends StatelessWidget {
  const RelationshipTreeView({
    super.key,
    required this.personId,
  });

  final String personId;

  @override
  Widget build(BuildContext context) {
    final premium = sl<PremiumService>().isPremium;
    return BlocProvider(
      create: (_) => sl<RelationshipTreeCubit>()..setCenterPerson(personId),
      child: Scaffold(
        backgroundColor: AppTheme.cream,
        appBar: AppBar(
          title: const Text('Árbol genealógico'),
        ),
        body: premium
            ? const RelationshipTreeCanvas()
            : const _RelationshipTreePremiumGate(),
      ),
    );
  }
}

class _RelationshipTreePremiumGate extends StatelessWidget {
  const _RelationshipTreePremiumGate();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 56,
              color: AppTheme.navy.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'El árbol genealógico interactivo está disponible con Premium.',
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

/// Lienzo interactivo del árbol (sin [Scaffold]); reutilizable en pestañas.
class RelationshipTreeCanvas extends StatefulWidget {
  const RelationshipTreeCanvas({super.key});

  @override
  State<RelationshipTreeCanvas> createState() =>
      RelationshipTreeCanvasState();
}

class RelationshipTreeCanvasState extends State<RelationshipTreeCanvas>
    with SingleTickerProviderStateMixin {
  static const double _canvasSize = 2000;
  static const Offset _canvasCenter = Offset(_canvasSize / 2, _canvasSize / 2);
  static const double _orbitRadius = 210;
  static const double _spreadStep = 92;

  final TransformationController _transform = TransformationController();
  late final AnimationController _focusAnim;
  Animation<Matrix4>? _viewportMatrixAnim;

  int _lastFocusGeneration = 0;
  Map<String, Offset> _lerpFromByPersonId = const {};
  bool _initialViewportDone = false;

  @override
  void initState() {
    super.initState();
    _focusAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )
      ..addListener(() {
        final anim = _viewportMatrixAnim;
        if (anim != null) {
          _transform.value = anim.value;
        }
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _lerpFromByPersonId = const {});
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerViewport());
  }

  @override
  void dispose() {
    _focusAnim.dispose();
    _transform.dispose();
    super.dispose();
  }

  Matrix4 _matrixCenteringCanvas({double scale = 1}) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return Matrix4.identity()
        ..translate(-_canvasCenter.dx + 200, -_canvasCenter.dy + 200)
        ..scale(scale);
    }
    final vp = box.size;
    return Matrix4.identity()
      ..translate(
        vp.width / 2 - _canvasCenter.dx * scale,
        vp.height / 2 - _canvasCenter.dy * scale,
      )
      ..scale(scale);
  }

  void _centerViewport({bool animated = false}) {
    final target = _matrixCenteringCanvas();
    if (!animated) {
      _transform.value = target;
      return;
    }
    _viewportMatrixAnim = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(
      CurvedAnimation(parent: _focusAnim, curve: Curves.easeInOutCubic),
    );
    _focusAnim.forward(from: 0);
  }

  Map<String, Offset> _layoutPositions(RelationshipTreeState state) {
    final map = <String, Offset>{};
    void place(List<RelationshipTreeMember> members, _TreeSlot slot) {
      final n = members.length;
      if (n == 0) return;
      for (var i = 0; i < n; i++) {
        final t = n == 1 ? 0.0 : i - (n - 1) / 2;
        final offset = switch (slot) {
          _TreeSlot.parents => Offset(
              _canvasCenter.dx + t * _spreadStep,
              _canvasCenter.dy - _orbitRadius,
            ),
          _TreeSlot.partners => Offset(
              _canvasCenter.dx + _orbitRadius,
              _canvasCenter.dy + t * _spreadStep,
            ),
          _TreeSlot.siblings => Offset(
              _canvasCenter.dx - _orbitRadius,
              _canvasCenter.dy + t * _spreadStep,
            ),
          _TreeSlot.children => Offset(
              _canvasCenter.dx + t * _spreadStep,
              _canvasCenter.dy + _orbitRadius,
            ),
        };
        map[members[i].person.id] = offset;
      }
    }

    place(state.parents, _TreeSlot.parents);
    place(state.partners, _TreeSlot.partners);
    place(state.siblings, _TreeSlot.siblings);
    place(state.children, _TreeSlot.children);
    return map;
  }

  void _onFocusGenerationChanged(RelationshipTreeState state) {
    if (state.focusGeneration == _lastFocusGeneration) return;
    _lastFocusGeneration = state.focusGeneration;
    if (!_initialViewportDone) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerViewport(animated: true);
    });
  }

  Future<void> _onSatelliteTap(
    RelationshipTreeMember member,
    Offset currentCenter,
  ) async {
    setState(() {
      _lerpFromByPersonId = {member.person.id: currentCenter};
    });
    _focusAnim.forward(from: 0);
    await context
        .read<RelationshipTreeCubit>()
        .setCenterPerson(member.person.id);
  }

  void _openPersonSheet(
    BuildContext context, {
    RelationshipTreeMember? member,
    required RelationshipTreeState state,
  }) {
    final person = member?.person ?? state.centerPerson;
    if (person == null) return;
    final label = member?.kinshipLabel ?? '';
    showRelationshipTreePersonSheet(
      context,
      person: person,
      kinshipLabel: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RelationshipTreeCubit, RelationshipTreeState>(
      listener: (context, state) {
        _onFocusGenerationChanged(state);
        if (!_initialViewportDone &&
            state.status == RelationshipTreeStatus.loaded) {
          _initialViewportDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _centerViewport();
          });
        }
      },
      builder: (context, state) {
        if (state.status == RelationshipTreeStatus.error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(state.errorMessage ?? 'Error al cargar el árbol.'),
            ),
          );
        }

        if (state.isLoading && state.centerPerson == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final center = state.centerPerson;
        if (center == null) {
          return const Center(child: Text('Persona no encontrada.'));
        }

        final targetPositions = _layoutPositions(state);

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
                child: AnimatedBuilder(
                  animation: _focusAnim,
                  builder: (context, _) {
                    final t = _focusAnim.isAnimating
                        ? Curves.easeInOutCubic.transform(_focusAnim.value)
                        : 1.0;

                    Offset resolvePosition(String personId, Offset target) {
                      final from = _lerpFromByPersonId[personId];
                      if (from != null && t < 1) {
                        return Offset.lerp(from, target, t)!;
                      }
                      return target;
                    }

                    final centerPos = resolvePosition(
                      center.id,
                      _canvasCenter,
                    );

                    final satelliteCenters = <String, Offset>{};
                    for (final entry in targetPositions.entries) {
                      satelliteCenters[entry.key] =
                          resolvePosition(entry.key, entry.value);
                    }

                    final connections = <RelationshipTreeConnection>[
                      for (final m in [
                        ...state.parents,
                        ...state.partners,
                        ...state.siblings,
                        ...state.children,
                      ])
                        if (satelliteCenters.containsKey(m.person.id))
                          RelationshipTreeConnection(
                            from: centerPos,
                            to: satelliteCenters[m.person.id]!,
                            isPastPartner: m.isPastPartner,
                          ),
                    ];

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          size: const Size(_canvasSize, _canvasSize),
                          painter: RelationshipTreeConnectionPainter(
                            connections: connections,
                          ),
                        ),
                        _positionedNode(
                          center: centerPos,
                          name: center.name,
                          facePath: center.faceImagePath,
                          kinshipLabel: '',
                          isCenter: true,
                          isDimmed: false,
                          onTap: () => _openPersonSheet(context, state: state),
                          onLongPress: () =>
                              _openPersonSheet(context, state: state),
                        ),
                        for (final m in [
                          ...state.parents,
                          ...state.partners,
                          ...state.siblings,
                          ...state.children,
                        ])
                          if (satelliteCenters.containsKey(m.person.id))
                            _positionedNode(
                              center: satelliteCenters[m.person.id]!,
                              name: m.person.name,
                              facePath: m.person.faceImagePath,
                              kinshipLabel: m.kinshipLabel,
                              isDimmed: m.isPastPartner,
                              onTap: () => _onSatelliteTap(
                                m,
                                satelliteCenters[m.person.id]!,
                              ),
                              onDoubleTap: () => _openPersonSheet(
                                context,
                                member: m,
                                state: state,
                              ),
                              onLongPress: () => _openPersonSheet(
                                context,
                                member: m,
                                state: state,
                              ),
                            ),
                      ],
                    );
                  },
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

  Widget _positionedNode({
    required Offset center,
    required String name,
    required String? facePath,
    required String kinshipLabel,
    bool isCenter = false,
    bool isDimmed = false,
    VoidCallback? onTap,
    VoidCallback? onDoubleTap,
    VoidCallback? onLongPress,
  }) {
    const halfW = RelationshipTreeNode.width / 2;
    const topOffset = RelationshipTreeNode.avatarSize / 2;

    return Positioned(
      left: center.dx - halfW,
      top: center.dy - topOffset,
      child: RelationshipTreeNode(
        name: name,
        faceImagePath: facePath,
        kinshipLabel: kinshipLabel,
        isCenter: isCenter,
        isDimmed: isDimmed,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

enum _TreeSlot { parents, partners, siblings, children }
