/// Etiqueta legible para [CloudSyncStatusStore.formatForDisplay].
String formatCloudSyncTimestamp(DateTime utc) {
  final local = utc.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thatDay = DateTime(local.year, local.month, local.day);
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  final time = '$h:$m';
  if (thatDay == today) return 'hoy a las $time';
  final yesterday = today.subtract(const Duration(days: 1));
  if (thatDay == yesterday) return 'ayer a las $time';
  final d = local.day.toString().padLeft(2, '0');
  final mo = local.month.toString().padLeft(2, '0');
  return '$d/$mo/${local.year} a las $time';
}
