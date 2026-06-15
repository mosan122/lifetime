import 'package:flutter/material.dart';

import '../../../../core/constants/milestone_categories.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/isar_category_datasource.dart';
import '../../data/models/local/category_collection.dart';

/// Chip de categoría que consulta Isar y cae-back a las constantes del
/// sistema cuando la categoría no existe aún en la base de datos local.
///
/// Devuelve [SizedBox.shrink] para la categoría "otros" o id vacío.
class MilestoneCategoryChip extends StatelessWidget {
  const MilestoneCategoryChip({super.key, required this.categoryId});

  final String? categoryId;

  static Future<Map<String, CategoryCollection>>? _cacheFuture;

  static Future<Map<String, CategoryCollection>> _loadCategoryMap() async {
    final ds = sl<IsarCategoryDataSource>();
    await ds.ensureSeeded();
    final all = await ds.fetchAll();
    return {for (final c in all) c.id: c};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _cacheFuture ??= _loadCategoryMap();

    return FutureBuilder<Map<String, CategoryCollection>>(
      future: _cacheFuture,
      builder: (context, snap) {
        final id = (categoryId ?? '').trim().toLowerCase();
        if (id.isEmpty || id == 'otros') return const SizedBox.shrink();

        final db = snap.data?[id];
        final fallback = milestoneCategoryById(categoryId);

        final name = db?.name ?? fallback.name;
        final icon = db != null
            ? (kCategoryIconPalette[db.iconName] ?? Icons.category_outlined)
            : fallback.icon;
        final color = db != null ? Color(db.colorValue) : fallback.color;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                name,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
