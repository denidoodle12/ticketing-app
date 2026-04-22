/// Utility for cleaning knowledge article content for display.
class ContentUtils {
  ContentUtils._();

  /// Strips all HTML tags and Markdown syntax from content,
  /// returning clean plain text suitable for card previews.
  ///
  /// Uses [replaceAllMapped] for patterns with capture groups,
  /// since Dart's [replaceAll] does NOT support backreferences like `$1`.
  static String stripToPlainText(String content) {
    String text = content;

    // Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Remove Markdown headings (### heading)
    text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');

    // Remove Markdown bold/italic markers — keep inner text
    text = text.replaceAllMapped(
      RegExp(r'\*{1,3}(.+?)\*{1,3}'),
      (m) => m.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'_{1,3}(.+?)_{1,3}'),
      (m) => m.group(1) ?? '',
    );

    // Remove Markdown strikethrough — keep inner text
    text = text.replaceAllMapped(
      RegExp(r'~~(.+?)~~'),
      (m) => m.group(1) ?? '',
    );

    // Remove Markdown links [text](url) → keep text
    text = text.replaceAllMapped(
      RegExp(r'\[(.+?)\]\(.+?\)'),
      (m) => m.group(1) ?? '',
    );

    // Remove Markdown images ![alt](url)
    text = text.replaceAll(RegExp(r'!\[.*?\]\(.+?\)'), '');

    // Remove Markdown list bullets (- item, * item)
    text = text.replaceAll(RegExp(r'^[\-\*]\s+', multiLine: true), '');

    // Remove Markdown ordered list numbers (1. item)
    text = text.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');

    // Remove Markdown blockquote markers (> text)
    text = text.replaceAll(RegExp(r'^>\s*', multiLine: true), '');

    // Remove Markdown horizontal rules
    text = text.replaceAll(RegExp(r'^-{3,}$', multiLine: true), '');

    // Remove Markdown code markers
    text = text.replaceAll(RegExp(r'`{1,3}'), '');

    // Decode common HTML entities
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    // Collapse multiple whitespace/newlines into single space
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    return text.trim();
  }
}
