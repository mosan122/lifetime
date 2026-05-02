import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

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
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              CircleAvatar(
                radius: size / 2,
                backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
                backgroundImage:
                    hasImg ? FileImage(File(faceImagePath!)) : null,
                child: hasImg
                    ? null
                    : Icon(Icons.person_outline,
                        color: AppTheme.navy, size: size * 0.5),
              ),
              if (!hasImg)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onAssignPhoto,
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
                ),
            ],
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
