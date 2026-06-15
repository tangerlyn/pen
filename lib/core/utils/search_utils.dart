// Unigram+Bigram full-text search utilities for Firestore.
// Index stores both single chars (unigrams) and 2-char windows (bigrams).
// Query uses unigrams for 1-char words, bigrams for 2+ char words.
// After Firestore fetch, client-side AND filter removes false positives.
class SearchUtils {
  SearchUtils._();

  static const int _maxBodyChars = 500;
  static const int _maxQueryTokens = 10;

  /// Builds the deduped token list (unigrams + bigrams) to store in Firestore.
  static List<String> buildIndex(String title, String body) {
    final tokens = <String>{};
    _indexTokenize(title, tokens);
    _indexTokenize(
      body.length > _maxBodyChars ? body.substring(0, _maxBodyChars) : body,
      tokens,
    );
    return tokens.toList();
  }

  /// Returns query tokens for `arrayContainsAny` (max [_maxQueryTokens]).
  /// 1-char words → unigram, 2+ char words → bigrams.
  static List<String> queryTokens(String query) {
    final tokens = <String>{};
    _queryTokenize(query.trim(), tokens);
    return tokens.take(_maxQueryTokens).toList();
  }

  /// After Firestore returns candidates, apply strict AND filter:
  /// every whitespace-separated word in [query] must appear as a substring
  /// in [text] (case-insensitive).
  static bool matchesQuery(String text, String query) {
    final lowerText = text.toLowerCase();
    final words = query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    return words.every(lowerText.contains);
  }

  // Index: unigram per char + bigram per pair
  static void _indexTokenize(String text, Set<String> out) {
    if (text.isEmpty) return;
    final normalized = text.toLowerCase();
    for (final word in normalized.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      for (int i = 0; i < word.length; i++) {
        out.add(word[i]); // unigram
        if (i < word.length - 1) {
          out.add(word.substring(i, i + 2)); // bigram
        }
      }
    }
  }

  // Query: 1-char → unigram, 2+ chars → bigrams only (avoids over-broad unigram OR)
  static void _queryTokenize(String text, Set<String> out) {
    if (text.isEmpty) return;
    final normalized = text.toLowerCase();
    for (final word in normalized.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      if (word.length == 1) {
        out.add(word);
      } else {
        for (int i = 0; i < word.length - 1; i++) {
          out.add(word.substring(i, i + 2));
        }
      }
    }
  }
}
