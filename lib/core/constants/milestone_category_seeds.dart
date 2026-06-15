/// Semilla de una categoría de hito (sin `IconData` ni `Color` de Flutter).
/// Las claves [iconKey] deben existir en `kCategoryIconPalette` de
/// [milestone_categories.dart].
class MilestoneCategorySeed {
  final String id;
  final String name;
  final String iconKey;
  /// Valor ARGB 32 bits (mismo que `Color.value`).
  final int colorArgb;

  const MilestoneCategorySeed({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorArgb,
  });
}

/// Lista canónica de categorías por defecto (orden estable; la última es `otros`).
/// Copia de referencia: `data/default_milestone_categories.json`.
const List<MilestoneCategorySeed> kMilestoneCategorySeeds = [
  MilestoneCategorySeed(
    id: 'familia',
    name: 'familia',
    iconKey: 'family_restroom',
    colorArgb: 0xFF9575CD,
  ),
  MilestoneCategorySeed(
    id: 'amigos',
    name: 'amigos',
    iconKey: 'group',
    colorArgb: 0xFF64B5F6,
  ),
  MilestoneCategorySeed(
    id: 'amor',
    name: 'amor',
    iconKey: 'favorite',
    colorArgb: 0xFFF06292,
  ),
  MilestoneCategorySeed(
    id: 'boda',
    name: 'boda',
    iconKey: 'celebration',
    colorArgb: 0xFFFFB300,
  ),
  MilestoneCategorySeed(
    id: 'relacion_inicio',
    name: 'inicio relación',
    iconKey: 'volunteer_activism',
    colorArgb: 0xFFF48FB1,
  ),
  MilestoneCategorySeed(
    id: 'separacion',
    name: 'separación',
    iconKey: 'heart_broken',
    colorArgb: 0xFF90A4AE,
  ),
  MilestoneCategorySeed(
    id: 'nacimiento',
    name: 'nacimiento',
    iconKey: 'child_care',
    colorArgb: 0xFF81D4FA,
  ),
  MilestoneCategorySeed(
    id: 'embarazo',
    name: 'embarazo',
    iconKey: 'pregnant_woman',
    colorArgb: 0xFFF8BBD0,
  ),
  MilestoneCategorySeed(
    id: 'primeras_veces',
    name: 'primeras veces',
    iconKey: 'flare',
    colorArgb: 0xFFFFF176,
  ),
  MilestoneCategorySeed(
    id: 'defuncion',
    name: 'defunción',
    iconKey: 'local_florist',
    colorArgb: 0xFFBDBDBD,
  ),
  MilestoneCategorySeed(
    id: 'mascotas',
    name: 'mascotas',
    iconKey: 'pets',
    colorArgb: 0xFF81C784,
  ),
  MilestoneCategorySeed(
    id: 'mudanza',
    name: 'mudanza',
    iconKey: 'moving',
    colorArgb: 0xFFA1887F,
  ),
  MilestoneCategorySeed(
    id: 'vivienda',
    name: 'vivienda',
    iconKey: 'vpn_key',
    colorArgb: 0xFF78909C,
  ),
  MilestoneCategorySeed(
    id: 'vehiculo',
    name: 'vehículo',
    iconKey: 'directions_car',
    colorArgb: 0xFF4DD0E1,
  ),
  MilestoneCategorySeed(
    id: 'graduacion',
    name: 'graduación',
    iconKey: 'school',
    colorArgb: 0xFF3949AB,
  ),
  MilestoneCategorySeed(
    id: 'trabajo',
    name: 'trabajo',
    iconKey: 'business_center',
    colorArgb: 0xFF7986CB,
  ),
  MilestoneCategorySeed(
    id: 'jubilacion',
    name: 'jubilación',
    iconKey: 'beach_access',
    colorArgb: 0xFF4FC3F7,
  ),
  MilestoneCategorySeed(
    id: 'logro',
    name: 'logro',
    iconKey: 'military_tech',
    colorArgb: 0xFFFFD54F,
  ),
  MilestoneCategorySeed(
    id: 'creatividad',
    name: 'creatividad',
    iconKey: 'palette',
    colorArgb: 0xFFFF8A65,
  ),
  MilestoneCategorySeed(
    id: 'espiritualidad',
    name: 'crecimiento',
    iconKey: 'self_improvement',
    colorArgb: 0xFFBA68C8,
  ),
  MilestoneCategorySeed(
    id: 'viajes',
    name: 'viajes',
    iconKey: 'flight',
    colorArgb: 0xFF4DB6AC,
  ),
  MilestoneCategorySeed(
    id: 'salud',
    name: 'salud',
    iconKey: 'monitor_heart',
    colorArgb: 0xFFE57373,
  ),
  MilestoneCategorySeed(
    id: 'crisis',
    name: 'crisis',
    iconKey: 'warning_amber',
    colorArgb: 0xFFFF7043,
  ),
  MilestoneCategorySeed(
    id: 'otros',
    name: 'otros',
    iconKey: 'category_filled',
    colorArgb: 0xFFCE93D8,
  ),
];
