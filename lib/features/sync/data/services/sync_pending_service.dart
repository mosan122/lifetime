import '../../domain/sync_pending_counts.dart';
import '../../../../data/datasources/isar_milestone_datasource.dart';
import '../../../milestones/data/datasources/isar_person_datasource.dart';
import '../../../milestones/data/datasources/isar_relationship_datasource.dart';

/// Cuenta filas locales con [isSynced] == false (cola de sincronización).
class SyncPendingService {
  SyncPendingService(
    this._milestoneDs,
    this._personDs,
    this._relationshipDs,
  );

  final IsarMilestoneDataSource _milestoneDs;
  final IsarPersonDataSource _personDs;
  final IsarRelationshipDataSource _relationshipDs;

  Future<SyncPendingCounts> load() async {
    final results = await Future.wait([
      _milestoneDs.countUnsyncedMilestones(),
      _personDs.countUnsynced(),
      _relationshipDs.countUnsynced(),
      _milestoneDs.countUnsyncedMediaItems(),
    ]);
    return SyncPendingCounts(
      milestones: results[0],
      people: results[1],
      relationships: results[2],
      mediaItems: results[3],
    );
  }
}
