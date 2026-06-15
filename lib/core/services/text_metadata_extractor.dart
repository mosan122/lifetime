class ExtractedTextMetadata {
  final List<String> mentions;
  final List<String> hashtags;

  const ExtractedTextMetadata({
    required this.mentions,
    required this.hashtags,
  });
}

/// Utility to extract semantic metadata from a free-form text.
///
/// Mentions: "@Name"
/// Hashtags: "#topic"
class TextMetadataExtractor {
  // Keep the regex permissive but avoid matching within email addresses.
  static final _mentionRegExp = RegExp(r'@([A-Za-z0-9_]+)');
  /// Menciones “cerradas”: exige un separador (espacio/salto) tras el nombre.
  /// Evita crear personas con @J, @Jo… mientras se corrige o se borra.
  static final _mentionWithTrailingWhitespaceRegExp =
      RegExp(r'(?<![A-Za-z0-9_])@([A-Za-z0-9_]+)(?=\s)');
  static final _hashtagRegExp = RegExp(r'#([A-Za-z0-9_]+)');

  static ExtractedTextMetadata extract(String text) {
    final mentions = _mentionRegExp
        .allMatches(text)
        .map((m) => m.group(1))
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final hashtags = _hashtagRegExp
        .allMatches(text)
        .map((m) => m.group(1))
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Dedupe while keeping order.
    final uniqueMentions = <String>{};
    final uniqueMentionsOrdered = <String>[];
    for (final m in mentions) {
      if (uniqueMentions.add(m)) uniqueMentionsOrdered.add(m);
    }

    final uniqueHashtags = <String>{};
    final uniqueHashtagsOrdered = <String>[];
    for (final h in hashtags) {
      if (uniqueHashtags.add(h)) uniqueHashtagsOrdered.add(h);
    }

    return ExtractedTextMetadata(
      mentions: uniqueMentionsOrdered,
      hashtags: uniqueHashtagsOrdered,
    );
  }

  /// Igual que [extract] en hashtags; en menciones solo cuenta @Nombre si va
  /// seguido de espacio/salto (p. ej. `@Ana celebramos`). Para guardar hito
  /// sigue usando [extract], que acepta @Nombre al final del texto.
  static ExtractedTextMetadata extractForLiveMentionSync(String text) {
    final mentions = _mentionWithTrailingWhitespaceRegExp
        .allMatches(text)
        .map((m) => m.group(1))
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final hashtags = _hashtagRegExp
        .allMatches(text)
        .map((m) => m.group(1))
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final uniqueMentions = <String>{};
    final uniqueMentionsOrdered = <String>[];
    for (final m in mentions) {
      if (uniqueMentions.add(m)) uniqueMentionsOrdered.add(m);
    }

    final uniqueHashtags = <String>{};
    final uniqueHashtagsOrdered = <String>[];
    for (final h in hashtags) {
      if (uniqueHashtags.add(h)) uniqueHashtagsOrdered.add(h);
    }

    return ExtractedTextMetadata(
      mentions: uniqueMentionsOrdered,
      hashtags: uniqueHashtagsOrdered,
    );
  }
}

