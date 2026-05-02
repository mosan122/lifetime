import 'package:flutter/material.dart';

import '../../../milestones/data/datasources/isar_category_datasource.dart';
import '../../../milestones/data/models/local/category_collection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';

class ManageCategoriesPage extends StatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  final _ds = sl<IsarCategoryDataSource>();

  Future<List<CategoryCollection>> _load() async {
    await _ds.ensureSeeded();
    return _ds.fetchAll();
  }

  Future<void> _refresh() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Categorías'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: AppTheme.cream,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final didSave = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppTheme.cream,
            builder: (_) => const _CategoryEditorSheet(),
          );
          if (didSave == true) {
            await _refresh();
          }
        },
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<CategoryCollection>>(
        future: _load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = categories[i];
              return _CategoryTile(
                category: c,
                onChanged: _refresh,
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryCollection category;
  final Future<void> Function() onChanged;

  const _CategoryTile({required this.category, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ds = sl<IsarCategoryDataSource>();
    final icon = _iconByName(category.iconName) ?? Icons.category_outlined;
    final color = Color(category.colorValue);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(
          category.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: category.isSystem
            ? const Text('Sistema')
            : const Text('Personalizada'),
        trailing: PopupMenuButton<String>(
          tooltip: 'Opciones',
          onSelected: (value) async {
            if (value == 'edit') {
              final didSave = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppTheme.cream,
                builder: (_) => _CategoryEditorSheet(initial: category),
              );
              if (didSave == true) {
                await onChanged();
              }
              return;
            }
            if (value == 'delete') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.cream,
                  title: const Text('Borrar categoría'),
                  content: Text('¿Borrar "${category.name}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Borrar',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ds.deleteById(category.id);
                await onChanged();
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            if (!category.isSystem)
              const PopupMenuItem(value: 'delete', child: Text('Borrar')),
          ],
        ),
      ),
    );
  }
}

class _CategoryEditorSheet extends StatefulWidget {
  final CategoryCollection? initial;
  const _CategoryEditorSheet({this.initial});

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final TextEditingController _name;
  late String _iconName;
  late int _colorValue;

  bool get _isEdit => widget.initial != null;
  bool get _isSystem => widget.initial?.isSystem == true;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _iconName = widget.initial?.iconName ?? 'category';
    _colorValue = widget.initial?.colorValue ?? 0xFF9E9E9E;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final ds = sl<IsarCategoryDataSource>();

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? 'Editar categoría' : 'Nueva categoría',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                enabled: !_isSystem,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  filled: true,
                  fillColor: const Color(0xFFFAFAE8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Icono', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              _IconPicker(
                value: _iconName,
                onChanged: (v) => setState(() => _iconName = v),
              ),
              const SizedBox(height: 12),
              Text('Color', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              _ColorPalette(
                value: _colorValue,
                onChanged: (v) => setState(() => _colorValue = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    final name = _name.text.trim();
                    if (name.isEmpty) return;
                    final c = CategoryCollection()
                      ..id = widget.initial?.id ?? 0
                      ..name = name
                      ..iconName = _iconName
                      ..colorValue = _colorValue
                      ..isSystem = widget.initial?.isSystem ?? false;
                    await ds.upsert(c);
                    if (!context.mounted) return;
                    Navigator.pop(context, true);
                  },
                  child: Text(_isEdit ? 'Guardar' : 'Crear'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _IconPicker({required this.value, required this.onChanged});

  static const _icons = <String, IconData>{
    'category': Icons.category_outlined,
    'cake': Icons.cake_outlined,
    'favorite': Icons.favorite_outline,
    'child_care': Icons.child_care_outlined,
    'star': Icons.star_outline,
    'celebration': Icons.celebration_outlined,
    'photo': Icons.photo_outlined,
    'travel': Icons.flight_takeoff_outlined,
    'home': Icons.home_outlined,
    'work': Icons.work_outline,
    'school': Icons.school_outlined,
    'pets': Icons.pets_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _icons.entries.map((e) {
        final isSel = e.key == value;
        return ChoiceChip(
          selected: isSel,
          onSelected: (_) => onChanged(e.key),
          label: Icon(e.value, size: 20),
          selectedColor: AppTheme.navy.withValues(alpha: 0.12),
          backgroundColor: AppTheme.navy.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSel ? AppTheme.navy : Colors.transparent,
            ),
          ),
        );
      }).toList(),
    );
  }

  static IconData? iconByName(String name) => _icons[name];
}

class _ColorPalette extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _ColorPalette({required this.value, required this.onChanged});

  static const _palette = <int>[
    0xFF9E9E9E, // gray
    0xFF90A4AE, // blue gray
    0xFF4DB6AC, // teal
    0xFF64B5F6, // blue
    0xFF81C784, // green
    0xFFAED581, // light green
    0xFFFFD54F, // amber
    0xFFFFB74D, // orange
    0xFFE57373, // red
    0xFFF06292, // pink
    0xFFBA68C8, // purple
    0xFF7986CB, // indigo
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _palette.map((c) {
        final isSel = c == value;
        return InkWell(
          onTap: () => onChanged(c),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Color(c),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSel ? Colors.black87 : Colors.black12,
                width: isSel ? 2 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

IconData? _iconByName(String name) => _IconPicker.iconByName(name);

