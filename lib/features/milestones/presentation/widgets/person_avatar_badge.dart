import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Clave para [ValueKey] en avatares con archivo: incluye `lastModified` para
/// invalidar la caché de [FileImage] cuando la ruta (`faceImagePath`) no cambia.
String faceImageWidgetCacheKey(String? faceImagePath) {
  if (faceImagePath == null || faceImagePath.trim().isEmpty) {
    return 'face:default';
  }
  final p = faceImagePath.trim();
  try {
    final file = File(p);
    if (!file.existsSync()) return 'face:missing|$p';
    final m = file.lastModifiedSync().millisecondsSinceEpoch;
    return 'face|$p|$m';
  } catch (_) {
    return 'face|$p|err';
  }
}

/// Avatar circular reutilizable (foto en disco o icono de persona).
class PersonCircleAvatar extends StatelessWidget {
  final String? faceImagePath;
  final double diameter;
  final String? semanticLabel;
  final double borderWidth;
  final Color? borderColor;

  const PersonCircleAvatar({
    super.key,
    required this.faceImagePath,
    this.diameter = 44,
    this.semanticLabel,
    this.borderWidth = 0,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasImg = faceImagePath != null &&
        faceImagePath!.isNotEmpty &&
        File(faceImagePath!).existsSync();

    final innerD =
        borderWidth > 0 ? (diameter - 2 * borderWidth).clamp(1.0, diameter) : diameter;

    final inner = ClipOval(
      child: hasImg
          ? Image(
              key: ValueKey<String>(faceImageWidgetCacheKey(faceImagePath)),
              width: innerD,
              height: innerD,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              image: FileImage(File(faceImagePath!)),
            )
          : ColoredBox(
              color: AppTheme.navy.withValues(alpha: 0.10),
              child: SizedBox(
                width: innerD,
                height: innerD,
                child: Icon(
                  Icons.person_outline,
                  color: AppTheme.navy,
                  size: innerD * 0.5,
                ),
              ),
            ),
    );

    final Widget avatar;
    if (borderWidth > 0) {
      avatar = Container(
        width: diameter,
        height: diameter,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? AppTheme.cream,
            width: borderWidth,
          ),
        ),
        child: inner,
      );
    } else {
      avatar = SizedBox(width: diameter, height: diameter, child: inner);
    }

    return Semantics(
      label: semanticLabel,
      child: avatar,
    );
  }
}

class PersonAvatarBadge extends StatelessWidget {
  final String? faceImagePath;
  final String personName;
  final VoidCallback onAssignPhoto;
  final double size;

  const PersonAvatarBadge({
    super.key,
    required this.faceImagePath,
    required this.personName,
    required this.onAssignPhoto,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final hasImg = faceImagePath != null &&
        faceImagePath!.isNotEmpty &&
        File(faceImagePath!).existsSync();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onAssignPhoto,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                PersonCircleAvatar(
                  key: ValueKey<String>(
                    faceImageWidgetCacheKey(faceImagePath),
                  ),
                  faceImagePath: faceImagePath,
                  diameter: size,
                  semanticLabel: personName,
                ),
                if (!hasImg)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppTheme.navy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add,
                          size: 12, color: AppTheme.cream),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: size + 16,
          child: Text(
            personName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}
