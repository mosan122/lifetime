import 'package:flutter/material.dart';

import 'milestone_category_seeds.dart';

export 'milestone_category_seeds.dart';

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

const Map<String, IconData> kCategoryIconPalette = {
  'category': Icons.category_outlined,
  'category_filled': Icons.category,
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
  'celebration': Icons.celebration,
  'volunteer_activism': Icons.volunteer_activism,
  'heart_broken': Icons.heart_broken,
  'moving': Icons.local_shipping,
  'military_tech': Icons.military_tech,
  'cake': Icons.cake,
  'pregnant_woman': Icons.pregnant_woman,
  'flare': Icons.flare,
  'vpn_key': Icons.vpn_key,
  'directions_car': Icons.directions_car,
  'self_improvement': Icons.self_improvement,
  'palette': Icons.palette,
  'beach_access': Icons.beach_access,
  'warning_amber': Icons.warning_amber,
};

/// Categorías por defecto derivadas de [kMilestoneCategorySeeds].
final List<MilestoneCategory> defaultCategories = [
  for (final s in kMilestoneCategorySeeds)
    MilestoneCategory(
      id: s.id,
      name: s.name,
      icon: kCategoryIconPalette[s.iconKey] ?? Icons.category_outlined,
      color: Color(s.colorArgb),
    ),
];

MilestoneCategory milestoneCategoryById(String? id) {
  final v = (id ?? '').trim().toLowerCase();
  if (v.isEmpty) return defaultCategories.last; // otros
  return defaultCategories.firstWhere(
    (c) => c.id == v,
    orElse: () => defaultCategories.last,
  );
}
