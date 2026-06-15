/// Etiqueta legible para tamaños en bytes (base 1024).
String formatBytes(int bytes) {
  if (bytes < 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final decimals = unit == 0 ? 0 : (value < 10 ? 1 : 0);
  return '${value.toStringAsFixed(decimals)} ${units[unit]}';
}
