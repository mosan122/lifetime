import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/services/face_cropper_service.dart';
import '../../data/models/local/media_item_embed.dart';
import '../../../../domain/entities/media_item.dart';

class FaceSelection {
  final FaceImageSource source;
  final String? milestoneImagePath;

  const FaceSelection({required this.source, this.milestoneImagePath});
}

Future<FaceSelection?> showFaceSourceBottomSheet({
  required BuildContext context,
  List<MediaItemEmbed>? milestoneMediaItems,
}) {
  final imageItems = milestoneMediaItems
      ?.where((m) => m.mediaType == MediaType.image)
      .toList();
  final hasImages = imageItems != null && imageItems.isNotEmpty;

  return showModalBottomSheet<FaceSelection>(
    context: context,
    backgroundColor: AppTheme.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _FaceSourceSheet(imageItems: hasImages ? imageItems : null),
  );
}

class _FaceSourceSheet extends StatelessWidget {
  final List<MediaItemEmbed>? imageItems;

  const _FaceSourceSheet({this.imageItems});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Foto de perfil', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Cámara',
                    onTap: () => Navigator.pop(
                      context,
                      const FaceSelection(source: FaceImageSource.camera),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Galería',
                    onTap: () => Navigator.pop(
                      context,
                      const FaceSelection(source: FaceImageSource.gallery),
                    ),
                  ),
                ),
              ],
            ),
            if (imageItems != null) ...[
              const SizedBox(height: 20),
              Text('Imágenes del hito', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageItems!.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final item = imageItems![i];
                    final file = File(item.localPath);
                    return GestureDetector(
                      onTap: () => Navigator.pop(
                        context,
                        FaceSelection(
                          source: FaceImageSource.milestoneImage,
                          milestoneImagePath: item.localPath,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: file.existsSync()
                            ? Image.file(file,
                                width: 72, height: 72, fit: BoxFit.cover)
                            : Container(
                                width: 72,
                                height: 72,
                                color: AppTheme.navy.withValues(alpha: 0.10),
                                child: const Icon(Icons.broken_image_outlined,
                                    color: AppTheme.navy),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.navy,
        side: const BorderSide(color: AppTheme.navy),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
