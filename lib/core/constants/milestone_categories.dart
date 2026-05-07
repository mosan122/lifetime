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

MilestoneCategory milestoneCategoryById(String? id) {
  final v = (id ?? '').trim().toLowerCase();
  if (v.isEmpty) return defaultCategories.last; // otros
  return defaultCategories.firstWhere(
    (c) => c.id == v,
    orElse: () => defaultCategories.last,
  );
}

