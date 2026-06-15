import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../settings/presentation/pages/edit_person_page.dart';
import '../../data/models/local/person_collection.dart';
import 'person_avatar_badge.dart';
import 'person_relationships_block.dart';

/// Minicarta de detalles al pulsar o mantener un nodo del árbol.
Future<void> showRelationshipTreePersonSheet(
  BuildContext context, {
  required PersonCollection person,
  required String kinshipLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.cream,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final bottom = MediaQuery.paddingOf(sheetContext).bottom;
      final img = person.faceImagePath;
      final hasImg =
          img != null && img.trim().isNotEmpty && File(img).existsSync();

      return Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PersonCircleAvatar(
                  faceImagePath: person.faceImagePath,
                  diameter: 64,
                  semanticLabel: person.name,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kinshipLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                      if (hasImg) const SizedBox(height: 2),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PersonRelationshipsBlock(
              personId: person.id,
              dense: true,
              allowDelete: false,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => EditPersonPage(person: person),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar persona'),
            ),
          ],
        ),
      );
    },
  );
}
