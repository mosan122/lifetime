import 'package:flutter/material.dart';

/// Iconos Material para grupos personalizados (asignación estable por id).
const List<IconData> kCustomGroupIcons = [
  Icons.star_outline,
  Icons.sports_soccer,
  Icons.music_note_outlined,
  Icons.menu_book_outlined,
  Icons.directions_bike_outlined,
  Icons.pets_outlined,
  Icons.celebration_outlined,
  Icons.volunteer_activism_outlined,
  Icons.palette_outlined,
  Icons.flight_takeoff_outlined,
  Icons.local_cafe_outlined,
  Icons.hiking_outlined,
];

IconData? builtinGroupIcon(String groupId) {
  switch (groupId) {
    case 'grp_builtin_family':
      return Icons.family_restroom_outlined;
    case 'grp_builtin_best_friends':
      return Icons.favorite_outline;
    case 'grp_builtin_friends':
      return Icons.people_outline;
    case 'grp_builtin_work':
      return Icons.work_outline;
    case 'grp_builtin_school':
      return Icons.school_outlined;
    case 'grp_builtin_neighbors':
      return Icons.home_work_outlined;
    case 'grp_builtin_other':
      return Icons.more_horiz;
    default:
      return null;
  }
}

/// Icono visual del grupo: predefinidos por id; personalizados por hash estable.
IconData groupIconFor(String groupId) {
  final builtin = builtinGroupIcon(groupId);
  if (builtin != null) return builtin;
  final idx = groupId.hashCode.abs() % kCustomGroupIcons.length;
  return kCustomGroupIcons[idx];
}
