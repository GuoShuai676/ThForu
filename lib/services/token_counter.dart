class TokenCounter {
  static int estimateTokens(String text) {
    if (text.isEmpty) return 0;
    final charCount = text.length;
    final cjkCount = RegExp(r'[\u4e00-\u9fff\u3000-\u303f\uff00-\uffef]')
        .allMatches(text)
        .length;
    final nonCjkChars = charCount - cjkCount;
    final wordEstimate = (nonCjkChars / 4).ceil();
    final cjkEstimate = (cjkCount * 1.5).ceil();
    return wordEstimate + cjkEstimate;
  }

  static int estimateMessagesTokens(List<dynamic> messages) {
    int total = 0;
    for (final msg in messages) {
      total += 4;
      final content = msg.content?.toString() ?? '';
      total += estimateTokens(content);
    }
    total += 2;
    return total;
  }
}
