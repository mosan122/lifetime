import 'package:flutter/material.dart';

@immutable
class MilestoneCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const MilestoneCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

const List<MilestoneCategory> defaultCategories = [
  MilestoneCategory(
    id: 'familia',
    name: 'familia',
    icon: Icons.family_restroom,
    color: Color(0xFF9575CD),
  ),
  MilestoneCategory(
    id: 'amigos',
    name: 'amigos',
    icon: Icons.group,
    color: Color(0xFF64B5F6),
  ),
  MilestoneCategory(
    id: 'amor',
    name: 'amor',
    icon: Icons.favorite,
    color: Color(0xFFF06292),
  ),
  MilestoneCategory(
    id: 'mascotas',
    name: 'mascotas',
    icon: Icons.pets,
    color: Color(0xFF81C784),
  ),
  MilestoneCategory(
    id: 'viajes',
    name: 'viajes',
    icon: Icons.flight,
    color: Color(0xFF4DB6AC),
  ),
  MilestoneCategory(
    id: 'naturaleza',
    name: 'naturaleza',
    icon: Icons.eco,
    color: Color(0xFFAED581),
  ),
  MilestoneCategory(
    id: 'ocio',
    name: 'ocio',
    icon: Icons.theater_comedy,
    color: Color(0xFFFFB74D),
  ),
  MilestoneCategory(
    id: 'trabajo',
    name: 'trabajo',
    icon: Icons.business_center,
    color: Color(0xFF7986CB),
  ),
  MilestoneCategory(
    id: 'formacion',
    name: 'formacion',
    icon: Icons.school,
    color: Color(0xFF4FC3F7),
  ),
  MilestoneCategory(
    id: 'finanzas',
    name: 'finanzas',
    icon: Icons.account_balance_wallet,
    color: Color(0xFFFFD54F),
  ),
  MilestoneCategory(
    id: 'salud',
    name: 'salud',
    icon: Icons.monitor_heart,
    color: Color(0xFFE57373),
  ),
  MilestoneCategory(
    id: 'deporte',
    name: 'deporte',
    icon: Icons.fitness_center,
    color: Color(0xFF90A4AE),
  ),
  MilestoneCategory(
    id: 'hogar',
    name: 'hogar',
    icon: Icons.home,
    color: Color(0xFFA1887F),
  ),
  MilestoneCategory(
    id: 'gastronomia',
    name: 'gastronomia',
    icon: Icons.restaurant,
    color: Color(0xFFFF8A65),
  ),
  MilestoneCategory(
    id: 'diy',
    name: 'diy',
    icon: Icons.handyman,
    color: Color(0xFFD4E157),
  ),
  MilestoneCategory(
    id: 'nacimiento',
    name: 'nacimiento',
    icon: Icons.child_care,
    color: Color(0xFF81D4FA),
  ),
  MilestoneCategory(
    id: 'defuncion',
    name: 'defuncion',
    icon: Icons.local_florist,
    color: Color(0xFFBDBDBD),
  ),
  MilestoneCategory(
    id: 'otros',
    name: 'otros',
    icon: Icons.category,
    color: Color(0xFFCE93D8),
  ),
];

/// Palette keys used for persisted dynamic categories.
/// Must stay in sync with the pickers and chip renderers.
String iconNameForDefaultCategory(MilestoneCategory c) {
  // Keep this mapping closed & deterministic to avoid dynamic IconData.
  if (c.icon == Icons.family_restroom) return 'family_restroom';
  if (c.icon == Icons.group) return 'group';
  if (c.icon == Icons.favorite) return 'favorite';
  if (c.icon == Icons.pets) return 'pets';
  if (c.icon == Icons.flight) return 'flight';
  if (c.icon == Icons.eco) return 'eco';
  if (c.icon == Icons.theater_comedy) return 'theater_comedy';
  if (c.icon == Icons.business_center) return 'business_center';
  if (c.icon == Icons.school) return 'school';
  if (c.icon == Icons.account_balance_wallet) return 'account_balance_wallet';
  if (c.icon == Icons.monitor_heart) return 'monitor_heart';
  if (c.icon == Icons.fitness_center) return 'fitness_center';
  if (c.icon == Icons.home) return 'home';
  if (c.icon == Icons.restaurant) return 'restaurant';
  if (c.icon == Icons.handyman) return 'handyman';
  if (c.icon == Icons.child_care) return 'child_care';
  if (c.icon == Icons.local_florist) return 'local_florist';
  return 'category';
}

const Map<String, IconData> kCategoryIconPalette = {
  'category': Icons.category_outlined,
  'family_restroom': Icons.family_restroom,
  'group': Icons.group,
  'favorite': Icons.favorite,
  'pets': Icons.pets,
  'flight': Icons.flight,
  'eco': Icons.eco,
  'theater_comedy': Icons.theater_comedy,
  'business_center': Icons.business_center,
  'school': Icons.school,
  'account_balance_wallet': Icons.account_balance_wallet,
  'monitor_heart': Icons.monitor_heart,
  'fitness_center': Icons.fitness_center,
  'home': Icons.home,
  'restaurant': Icons.restaurant,
  'handyman': Icons.handyman,
  'child_care': Icons.child_care,
  'local_florist': Icons.local_florist,
};

MilestoneCategory milestoneCategoryById(String? id) {
  final v = (id ?? '').trim().toLowerCase();
  if (v.isEmpty) return defaultCategories.last; // otros
  return defaultCategories.firstWhere(
    (c) => c.id == v,
    orElse: () => defaultCategories.last,
  );
}

