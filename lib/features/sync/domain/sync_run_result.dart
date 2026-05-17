/// Resultado de una pasada de [SyncService.syncData].
class SyncRunResult {
  const SyncRunResult({
    this.skipped = false,
    this.skipReason,
    this.peopleSynced = 0,
    this.peopleFailed = 0,
    this.relationshipsSynced = 0,
    this.relationshipsFailed = 0,
    this.milestonesSynced = 0,
    this.milestonesFailed = 0,
    this.errors = const [],
  });

  final bool skipped;
  final String? skipReason;
  final int peopleSynced;
  final int peopleFailed;
  final int relationshipsSynced;
  final int relationshipsFailed;
  final int milestonesSynced;
  final int milestonesFailed;
  final List<String> errors;

  int get totalSynced =>
      peopleSynced + relationshipsSynced + milestonesSynced;

  int get totalFailed =>
      peopleFailed + relationshipsFailed + milestonesFailed;

  bool get hasErrors => errors.isNotEmpty || totalFailed > 0;

  bool get ok => !skipped && !hasErrors && totalSynced > 0;
}
