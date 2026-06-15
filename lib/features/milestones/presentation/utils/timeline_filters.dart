import '../../../../domain/entities/milestone.dart';

/// Filtros activos del timeline (combinación AND entre categorías).
class TimelineFilters {
  const TimelineFilters({
    this.personIds = const {},
    this.locationKeys = const {},
    this.yearMonths = const {},
  });

  static const empty = TimelineFilters();

  final Set<String> personIds;
  final Set<String> locationKeys;
  final Set<(int year, int month)> yearMonths;

  bool get isActive =>
      personIds.isNotEmpty ||
      locationKeys.isNotEmpty ||
      yearMonths.isNotEmpty;

  TimelineFilters copyWith({
    Set<String>? personIds,
    Set<String>? locationKeys,
    Set<(int year, int month)>? yearMonths,
  }) {
    return TimelineFilters(
      personIds: personIds ?? this.personIds,
      locationKeys: locationKeys ?? this.locationKeys,
      yearMonths: yearMonths ?? this.yearMonths,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineFilters &&
          _setEq(personIds, other.personIds) &&
          _setEq(locationKeys, other.locationKeys) &&
          _setEq(yearMonths, other.yearMonths);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(personIds),
        Object.hashAllUnordered(locationKeys),
        Object.hashAllUnordered(yearMonths),
      );
}

bool _setEq<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

/// Clave estable para agrupar hitos por lugar.
String? milestoneLocationKey(Milestone m) {
  final name = (m.locationName ?? '').trim();
  if (name.isEmpty) return null;
  final city = (m.locationCity ?? '').trim();
  final country = (m.locationCountry ?? '').trim();
  return '$name|$city|$country';
}

/// Etiqueta legible del lugar para chips y listas.
String milestoneLocationLabel(Milestone m) {
  final name = (m.locationName ?? '').trim();
  if (name.isEmpty) return '';
  final parts = <String>[
    if ((m.locationCity ?? '').trim().isNotEmpty) m.locationCity!.trim(),
    if ((m.locationCountry ?? '').trim().isNotEmpty) m.locationCountry!.trim(),
  ];
  if (parts.isEmpty) return name;
  return '$name · ${parts.join(', ')}';
}

const _monthNamesEs = <int, String>{
  1: 'Enero',
  2: 'Febrero',
  3: 'Marzo',
  4: 'Abril',
  5: 'Mayo',
  6: 'Junio',
  7: 'Julio',
  8: 'Agosto',
  9: 'Septiembre',
  10: 'Octubre',
  11: 'Noviembre',
  12: 'Diciembre',
};

String formatYearMonthLabel(int year, int month) {
  final monthName = _monthNamesEs[month] ?? month.toString();
  return '$monthName $year';
}

(String key, String label)? yearMonthEntry(int year, int month) {
  if (month < 1 || month > 12) return null;
  return ('$year-${month.toString().padLeft(2, '0')}', formatYearMonthLabel(year, month));
}

(int year, int month)? parseYearMonthKey(String key) {
  final parts = key.split('-');
  if (parts.length != 2) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (y == null || m == null || m < 1 || m > 12) return null;
  return (y, m);
}

List<Milestone> applyTimelineFilters(
  List<Milestone> all,
  TimelineFilters filters,
) {
  if (!filters.isActive) return all;
  return all.where((m) {
    if (filters.personIds.isNotEmpty) {
      if (!m.participantIds.any(filters.personIds.contains)) return false;
    }
    if (filters.locationKeys.isNotEmpty) {
      final key = milestoneLocationKey(m);
      if (key == null || !filters.locationKeys.contains(key)) return false;
    }
    if (filters.yearMonths.isNotEmpty) {
      final ym = (m.eventDate.year, m.eventDate.month);
      if (!filters.yearMonths.contains(ym)) return false;
    }
    return true;
  }).toList();
}

/// Personas que aparecen en al menos un hito.
Set<String> collectParticipantIds(List<Milestone> milestones) {
  final ids = <String>{};
  for (final m in milestones) {
    ids.addAll(m.participantIds.where((id) => id.trim().isNotEmpty));
  }
  return ids;
}

/// Lugares únicos presentes en los hitos (clave → etiqueta).
Map<String, String> collectLocationOptions(List<Milestone> milestones) {
  final map = <String, String>{};
  for (final m in milestones) {
    final key = milestoneLocationKey(m);
    if (key == null) continue;
    map.putIfAbsent(key, () => milestoneLocationLabel(m));
  }
  return map;
}

/// Meses-año únicos presentes en los hitos, ordenados del más reciente al más antiguo.
List<(String key, String label, int year, int month)> collectYearMonthOptions(
  List<Milestone> milestones,
) {
  final seen = <(int, int)>{};
  for (final m in milestones) {
    seen.add((m.eventDate.year, m.eventDate.month));
  }
  final sorted = seen.toList()
    ..sort((a, b) {
      if (a.$1 != b.$1) return b.$1.compareTo(a.$1);
      return b.$2.compareTo(a.$2);
    });
  return [
    for (final (y, mo) in sorted)
      if (yearMonthEntry(y, mo) case final entry?) (entry.$1, entry.$2, y, mo),
  ];
}
