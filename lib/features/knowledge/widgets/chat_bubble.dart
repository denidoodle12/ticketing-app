import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/ai_chat_model.dart';
import 'typing_indicator.dart';

/// A single chat bubble for user or assistant messages
class ChatBubble extends StatelessWidget {
  final AiChatMessage message;
  final VoidCallback? onRetry;

  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
  });

  bool get _isUser => message.role == ChatRole.user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isUser) ...[
            // AI avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary500, AppColors.primary600],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildBubble(context),
                if (!_isUser && message.sources.isNotEmpty && !message.isLoading)
                  _buildSourceChips(context),
              ],
            ),
          ),
          if (_isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    // Loading state
    if (message.isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: const Radius.circular(4),
          ),
        ),
        child: const TypingIndicator(),
      );
    }

    // Error state
    if (message.isError) {
      return Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.error100,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: const Radius.circular(4),
          ),
          border: Border.all(color: AppColors.error500.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.error700),
                const SizedBox(width: 6),
                Text(
                  'Error',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.error700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message.content,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.error700,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.error500.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.error500.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh,
                          size: 14, color: AppColors.error700),
                      const SizedBox(width: 4),
                      Text(
                        'Retry',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.error700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // User message — plain text
    if (_isUser) {
      return Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary600, AppColors.primary500],
          ),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: const Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary500.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.content,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.white,
            height: 1.5,
          ),
        ),
      );
    }

    // AI message — rendered with flutter_html
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(16).copyWith(
          bottomLeft: const Radius.circular(4),
        ),
      ),
      child: _buildRenderedContent(context, message.content),
    );
  }

  // ─── Rendered content using flutter_html ──────────────────────

  Widget _buildRenderedContent(BuildContext context, String rawContent) {
    final html = _prepareAiContent(rawContent);

    return Html(
      data: html,
      onLinkTap: (url, _, __) async {
        if (url == null || url.isEmpty) return;
        try {
          String fixedUrl = url.trim();
          if (!fixedUrl.startsWith('http')) {
            fixedUrl = 'https://$fixedUrl';
          }
          final uri = Uri.parse(fixedUrl);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          try {
            String fixedUrl = url.trim();
            if (!fixedUrl.startsWith('http')) fixedUrl = 'https://$fixedUrl';
            await launchUrl(
              Uri.parse(fixedUrl),
              mode: LaunchMode.inAppBrowserView,
            );
          } catch (_) {}
        }
      },
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(13.5),
          lineHeight: LineHeight(1.6),
          color: AppColors.textPrimary,
        ),
        'p': Style(
          margin: Margins.only(bottom: 8),
          fontSize: FontSize(13.5),
          lineHeight: LineHeight(1.6),
          color: AppColors.textPrimary,
        ),
        'h1': Style(
          fontSize: FontSize(18),
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          margin: Margins.only(top: 12, bottom: 6),
        ),
        'h2': Style(
          fontSize: FontSize(16),
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          margin: Margins.only(top: 10, bottom: 6),
        ),
        'h3': Style(
          fontSize: FontSize(15),
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          margin: Margins.only(top: 8, bottom: 4),
        ),
        'strong': Style(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        'b': Style(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        'em': Style(fontStyle: FontStyle.italic),
        'i': Style(fontStyle: FontStyle.italic),
        'a': Style(
          color: AppColors.primary500,
          textDecoration: TextDecoration.underline,
        ),
        'ul': Style(
          margin: Margins.only(bottom: 8),
          padding: HtmlPaddings.only(left: 4),
        ),
        'ol': Style(
          margin: Margins.only(bottom: 8),
          padding: HtmlPaddings.only(left: 4),
        ),
        'li': Style(
          fontSize: FontSize(13.5),
          lineHeight: LineHeight(1.5),
          color: AppColors.textPrimary,
          margin: Margins.only(bottom: 3),
        ),
        'code': Style(
          backgroundColor: AppColors.grey200,
          color: AppColors.primaryDark,
          fontSize: FontSize(12.5),
          padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
        ),
        'pre': Style(
          backgroundColor: AppColors.grey200,
          padding: HtmlPaddings.all(10),
          margin: Margins.only(bottom: 8),
        ),
        'blockquote': Style(
          margin: Margins.only(left: 0, bottom: 8),
          padding: HtmlPaddings.only(left: 10),
          border: Border(
            left: BorderSide(color: AppColors.primary400, width: 3),
          ),
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      },
    );
  }

  /// Prepares AI content for HTML rendering.
  /// Strips think-blocks (LLM reasoning), converts markdown to HTML.
  String _prepareAiContent(String content) {
    String html = content;

    // ── 0. Strip <think>...</think> blocks (LLM reasoning, not for user) ──
    html = html.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');

    // ── 0b. Strip any leftover standalone <think> or </think> tags ──
    html = html.replaceAll(RegExp(r'</?think>'), '');

    // Trim leading/trailing whitespace after stripping
    html = html.trim();

    // ── 1. Code blocks ```lang\ncode\n``` ──
    html = html.replaceAllMapped(
      RegExp(r'```(\w*)\n([\s\S]*?)```'),
      (m) => '<pre><code>${m.group(2)}</code></pre>',
    );

    // ── 2. Inline code `text` ──
    html = html.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (m) => '<code>${m.group(1)}</code>',
    );

    // ── 3. Blockquotes (> text) ──
    html = html.replaceAllMapped(
      RegExp(r'^>\s*(.+)$', multiLine: true),
      (m) => '<blockquote>${m.group(1)}</blockquote>',
    );

    // ── 4. Headings (### → h3, ## → h2, # → h1) ──
    html = html.replaceAllMapped(
      RegExp(r'^### (.+)$', multiLine: true),
      (m) => '<h3>${m.group(1)}</h3>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^## (.+)$', multiLine: true),
      (m) => '<h2>${m.group(1)}</h2>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^# (.+)$', multiLine: true),
      (m) => '<h1>${m.group(1)}</h1>',
    );

    // ── 5. Horizontal rule (--- or more) ──
    html = html.replaceAllMapped(
      RegExp(r'^-{3,}$', multiLine: true),
      (m) => '<hr>',
    );

    // ── 6. Inline formatting ──
    // Bold + Italic ***text***
    html = html.replaceAllMapped(
      RegExp(r'\*\*\*(.+?)\*\*\*'),
      (m) => '<strong><em>${m.group(1)}</em></strong>',
    );

    // Bold **text**
    html = html.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (m) => '<strong>${m.group(1)}</strong>',
    );

    // Bold __text__
    html = html.replaceAllMapped(
      RegExp(r'__(.+?)__'),
      (m) => '<strong>${m.group(1)}</strong>',
    );

    // Italic *text*
    html = html.replaceAllMapped(
      RegExp(r'(?<![\w<])\*(.+?)\*(?![\w>])'),
      (m) => '<em>${m.group(1)}</em>',
    );

    // Italic _text_
    html = html.replaceAllMapped(
      RegExp(r'(?<!\w)_(.+?)_(?!\w)'),
      (m) => '<em>${m.group(1)}</em>',
    );

    // Strikethrough ~~text~~
    html = html.replaceAllMapped(
      RegExp(r'~~(.+?)~~'),
      (m) => '<del>${m.group(1)}</del>',
    );

    // ── 7. Links [text](url) ──
    html = html.replaceAllMapped(
      RegExp(r'\[(.+?)\]\((.+?)\)'),
      (m) => '<a href="${m.group(2)}">${m.group(1)}</a>',
    );

    // ── 8. Unordered list items (- item or * item at start of line) ──
    html = html.replaceAllMapped(
      RegExp(r'^[\-\*]\s+(.+)$', multiLine: true),
      (m) => '<li>${m.group(1)}</li>',
    );
    html = html.replaceAllMapped(
      RegExp(r'((?:<li>.+?<\/li>\s*)+)'),
      (m) => '<ul>${m.group(1)}</ul>',
    );

    // ── 9. Ordered list items (1. item) ──
    html = html.replaceAllMapped(
      RegExp(r'^\d+\.\s+(.+)$', multiLine: true),
      (m) => '<oli>${m.group(1)}</oli>',
    );
    html = html.replaceAllMapped(RegExp(r'((?:<oli>.+?<\/oli>\s*)+)'), (m) {
      final items = m
          .group(1)!
          .replaceAll('<oli>', '<li>')
          .replaceAll('</oli>', '</li>');
      return '<ol>$items</ol>';
    });

    // ── 10. Wrap plain-text lines in <p> (skip lines already HTML) ──
    final lines = html.split('\n');
    final buffer = StringBuffer();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        buffer.writeln();
      } else if (RegExp(r'^<[a-zA-Z/]').hasMatch(trimmed)) {
        buffer.writeln(trimmed);
      } else {
        buffer.writeln('<p>$trimmed</p>');
      }
    }

    return buffer.toString();
  }

  // ─── Source Chips ──────────────────────────────────────────────

  Widget _buildSourceChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sources',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: message.sources.map((source) {
              return GestureDetector(
                onTap: () {
                  context.push('/knowledge/article', extra: source.id);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.article_outlined,
                          size: 13, color: AppColors.primary600),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          source.title,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
