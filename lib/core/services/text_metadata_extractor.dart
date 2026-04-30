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
}

