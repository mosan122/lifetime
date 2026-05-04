/// Título por defecto cuando el usuario no escribe uno: primeras cinco palabras
/// de la descripción/nota seguidas de "...", o texto fijo si no hay contenido.
String milestoneFallbackTitleFromDescription(String description) {
  final trimmed = description.trim();
  if (trimmed.isEmpty) return 'Recuerdo sin título';

  final words = trimmed
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'Recuerdo sin título';
  if (words.length <= 5) return words.join(' ');
  return '${words.take(5).join(' ')}...';
}
