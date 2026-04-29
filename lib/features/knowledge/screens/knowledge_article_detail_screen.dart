import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../providers/knowledge_provider.dart';
import '../models/knowledge_article_model.dart';

class KnowledgeArticleDetailScreen extends StatefulWidget {
  final int articleId;

  const KnowledgeArticleDetailScreen({super.key, required this.articleId});

  @override
  State<KnowledgeArticleDetailScreen> createState() =>
      _KnowledgeArticleDetailScreenState();
}

class _KnowledgeArticleDetailScreenState
    extends State<KnowledgeArticleDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KnowledgeProvider>().loadArticleDetail(widget.articleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: AppColors.white,
        toolbarHeight: 68,
        automaticallyImplyLeading: false,
        leadingWidth: 76,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: _buildActionButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: Consumer<KnowledgeProvider>(
        builder: (context, provider, _) {
          if (provider.isArticleLoading) {
            return _buildLoadingState();
          }

          if (provider.articleError != null) {
            return _buildErrorState(provider.articleError!);
          }

          final article = provider.selectedArticle;
          if (article == null) {
            return _buildErrorState('Article not found');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Category badge
                if (article.category != null) _buildCategoryBadge(article),
                const SizedBox(height: 12),
                // Title
                Text(
                  article.title,
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                // Meta info
                _buildMetaRow(article),
                const SizedBox(height: 24),
                // Divider
                Divider(color: AppColors.secondary200, height: 1),
                const SizedBox(height: 12),
                // Content (rendered markdown-like)
                _buildContent(article.content),
                const SizedBox(height: 24),
                // Tags
                if (article.tags.isNotEmpty) ...[
                  _buildTagsSection(article.tags),
                  const SizedBox(height: 24),
                ],
                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Category Badge ────────────────────────────────────────────

  Widget _buildCategoryBadge(KnowledgeArticle article) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        article.category!.name,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  // ─── Meta Row ──────────────────────────────────────────────────

  Widget _buildMetaRow(KnowledgeArticle article) {
    final dateStr = article.createdAt != null
        ? _formatDate(article.createdAt!)
        : 'Unknown date';

    return Row(
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          'Updated $dateStr',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }


  // ─── Content (HTML Rendering for WYSIWYG editor content) ────────

  Widget _buildContent(String content) {
    final htmlContent = _prepareHtmlContent(content);

    return Html(
      data: htmlContent,
      onLinkTap: (url, _, __) async {
        if (url != null) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(14),
          lineHeight: LineHeight(1.7),
          color: const Color(0xFF334155),
        ),
        'p': Style(
          margin: Margins.only(bottom: 12),
          fontSize: FontSize(14),
          lineHeight: LineHeight(1.7),
          color: const Color(0xFF334155),
        ),
        'h1': Style(
          fontSize: FontSize(22),
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          margin: Margins.only(top: 16, bottom: 8),
        ),
        'h2': Style(
          fontSize: FontSize(20),
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          margin: Margins.only(top: 14, bottom: 8),
        ),
        'h3': Style(
          fontSize: FontSize(18),
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          margin: Margins.only(top: 12, bottom: 6),
        ),
        'h4': Style(
          fontSize: FontSize(16),
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          margin: Margins.only(top: 10, bottom: 6),
        ),
        'strong': Style(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        'b': Style(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        'em': Style(
          fontStyle: FontStyle.italic,
        ),
        'i': Style(
          fontStyle: FontStyle.italic,
        ),
        'u': Style(
          textDecoration: TextDecoration.underline,
        ),
        's': Style(
          textDecoration: TextDecoration.lineThrough,
          color: AppColors.grey500,
        ),
        'del': Style(
          textDecoration: TextDecoration.lineThrough,
          color: AppColors.grey500,
        ),
        'a': Style(
          color: AppColors.primary500,
          textDecoration: TextDecoration.underline,
        ),
        'ul': Style(
          margin: Margins.only(bottom: 8),
          padding: HtmlPaddings.only(left: 8),
        ),
        'ol': Style(
          margin: Margins.only(bottom: 8),
          padding: HtmlPaddings.only(left: 8),
        ),
        'li': Style(
          fontSize: FontSize(14),
          lineHeight: LineHeight(1.6),
          color: const Color(0xFF334155),
          margin: Margins.only(bottom: 4),
        ),
        'hr': Style(
          margin: Margins.symmetric(vertical: 16),
          border: Border(
            bottom: BorderSide(color: AppColors.secondary200, width: 1),
          ),
        ),
        'blockquote': Style(
          margin: Margins.only(left: 0, bottom: 12),
          padding: HtmlPaddings.only(left: 12),
          border: Border(
            left: BorderSide(color: AppColors.primary400, width: 3),
          ),
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      },
    );
  }

  /// Converts content to HTML for rendering.
  /// Content from admin can be pure HTML, pure Markdown, or a hybrid.
  /// We always process Markdown patterns so nothing is left unrendered.
  String _prepareHtmlContent(String content) {
    String html = content;

    // ── 1. Blockquotes (> text) — must be done before <p> wrapping ──
    html = html.replaceAllMapped(
      RegExp(r'^>\s*(.+)$', multiLine: true),
      (m) => '<blockquote>${m.group(1)}</blockquote>',
    );

    // ── 2. Headings (### → h3, ## → h2, # → h1) — order matters ──
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

    // ── 3. Horizontal rule (--- or more) ──
    html = html.replaceAllMapped(
      RegExp(r'^-{3,}$', multiLine: true),
      (m) => '<hr>',
    );

    // ── 4. Inline formatting ──

    // Bold + Italic  ***text*** or ___text___
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

    // Italic *text* (but not inside HTML tags)
    html = html.replaceAllMapped(
      RegExp(r'(?<![<\w])\*(.+?)\*(?![>\w])'),
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

    // ── 5. Links [text](url) ──
    html = html.replaceAllMapped(
      RegExp(r'\[(.+?)\]\((.+?)\)'),
      (m) => '<a href="${m.group(2)}">${m.group(1)}</a>',
    );

    // ── 6. Unordered list items (- item or * item at start of line) ──
    html = html.replaceAllMapped(
      RegExp(r'^[\-\*]\s+(.+)$', multiLine: true),
      (m) => '<li>${m.group(1)}</li>',
    );
    // Wrap consecutive <li> in <ul>
    html = html.replaceAllMapped(
      RegExp(r'((?:<li>.+?<\/li>\s*)+)'),
      (m) => '<ul>${m.group(1)}</ul>',
    );

    // ── 7. Ordered list items (1. item) ──
    html = html.replaceAllMapped(
      RegExp(r'^\d+\.\s+(.+)$', multiLine: true),
      (m) => '<oli>${m.group(1)}</oli>',
    );
    html = html.replaceAllMapped(
      RegExp(r'((?:<oli>.+?<\/oli>\s*)+)'),
      (m) {
        final items = m.group(1)!
            .replaceAll('<oli>', '<li>')
            .replaceAll('</oli>', '</li>');
        return '<ol>$items</ol>';
      },
    );

    // ── 8. Wrap plain-text lines in <p> (skip lines already HTML) ──
    final lines = html.split('\n');
    final buffer = StringBuffer();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        buffer.writeln();
      } else if (RegExp(r'^<[a-zA-Z/]').hasMatch(trimmed)) {
        // Already an HTML element
        buffer.writeln(trimmed);
      } else {
        buffer.writeln('<p>$trimmed</p>');
      }
    }

    return buffer.toString();
  }

  // ─── Tags Section ──────────────────────────────────────────────

  Widget _buildTagsSection(List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary100),
              ),
              child: Text(
                tag,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Loading / Error ───────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(60),
        child: CircularProgressIndicator(color: AppColors.primaryDark),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.grey400),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: AppTextStyles.h6.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                context.read<KnowledgeProvider>().loadArticleDetail(
                  widget.articleId,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Reusable action button — matches ticket detail screen style
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.primaryDark, size: 22),
        ),
      ),
    );
  }
}
