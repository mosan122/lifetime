import '../models/milestone_location_data.dart';
import '../../domain/entities/milestone.dart';
import '../../injection_container.dart';
import '../../features/milestones/data/datasources/isar_saved_location_datasource.dart';

class MilestoneLocationResolver {
  const MilestoneLocationResolver();

  Future<MilestoneLocationData?> resolve(Milestone m) async {
    final id = m.savedLocationId;
    if (id != null) {
      try {
        final ds = sl<IsarSavedLocationDataSource>();
        final saved = await ds.fetchById(id);
        if (saved != null && saved.name.trim().isNotEmpty) {
          return MilestoneLocationData(
            name: saved.name.trim(),
            city: saved.city,
            country: saved.country,
            latitude: saved.latitude,
            longitude: saved.longitude,
          );
        }
      } catch (_) {
        // Fall back to milestone copy.
      }
    }

    final name = (m.locationName ?? '').trim();
    if (name.isEmpty &&
        m.latitude == null &&
        m.longitude == null &&
        (m.locationCity ?? '').trim().isEmpty &&
        (m.locationCountry ?? '').trim().isEmpty) {
      return null;
    }

    return MilestoneLocationData(
      name: name.isEmpty ? 'Ubicación' : name,
      city: (m.locationCity ?? '').trim().isEmpty ? null : m.locationCity!.trim(),
      country:
          (m.locationCountry ?? '').trim().isEmpty ? null : m.locationCountry!.trim(),
      latitude: m.latitude,
      longitude: m.longitude,
    );
  }
}

