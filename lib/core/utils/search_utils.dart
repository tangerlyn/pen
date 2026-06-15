// Bigram-based full-text search utilities for Firestore.
// Pre-compute 2-char sliding-window tokens at write time (searchIndex array),
// query with array-contains-any, then client-side AND filter for multi-word queries.
class SearchUtils {
  SearchUtils._();

  static const int _maxBodyChars = 500;
  static const int _maxQueryTokens = 10;

  /// Builds the deduped bigram token list to store in Firestore.
  /// Pass [title] and [body] separately; body is capped at [_maxBodyChars].
  static List<String> buildIndex(String title, String body) {
    final tokens = <String>{};
    _tokenize(title, tokens);
    _tokenize(
      body.length > _maxBodyChars ? body.substring(0, _maxBodyChars) : body,
      tokens,
    );
    return tokens.toList();
  }

  /// Returns the bigram tokens for a search query (max [_maxQueryTokens]).
  /// Used as the value for `arrayContainsAny` in Firestore queries.
  static List<String> queryTokens(String query) {
    final tokens = <String>{};
    _tokenize(query.trim(), tokens);
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

  static void _tokenize(String text, Set<String> out) {
    if (text.isEmpty) return;
    final normalized = text.toLowerCase();
    for (final word in normalized.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      // 1-2 char words: add as-is (no bigram exists or bigram == word)
      if (word.length <= 2) {
        out.add(word);
      }
      // Sliding bigrams
      for (int i = 0; i < word.length - 1; i++) {
        out.add(word.substring(i, i + 2));
      }
    }
  }
}
