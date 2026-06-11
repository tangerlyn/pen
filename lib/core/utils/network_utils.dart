Future<T> withRetry<T>(
  Future<T> Function() action, {
  int maxRetries = 3,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await action();
    } catch (e) {
      attempt++;
      if (attempt >= maxRetries) rethrow;
      await Future.delayed(Duration(seconds: attempt)); // 1초, 2초, 3초
    }
  }
}
