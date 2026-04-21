import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _buildActionButton(
                icon: Icons.share_outlined,
                onTap: () => _shareArticle(),
              ),
            ),
          ),
        ],
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
                    color: AppColors.primaryDark,
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
                const SizedBox(height: 24),
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
        // Author icon
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.person_outline,
            size: 16,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Admin',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        _buildDot(),
        Text(
          dateStr,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        _buildDot(),
        Icon(Icons.access_time, size: 13, color: AppColors.grey400),
        const SizedBox(width: 3),
        Text(
          '${article.readTimeMinutes} min read',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: AppColors.grey400,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ─── Content (Simple Markdown-like Rendering) ──────────────────

  Widget _buildContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Heading detection
      if (trimmed.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              trimmed.substring(3),
              style: AppTextStyles.h5.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              trimmed.substring(4),
              style: AppTextStyles.h6.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      // Numbered list
      else if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        final match = RegExp(r'^(\d+)\.\s(.+)').firstMatch(trimmed);
        if (match != null) {
          widgets.add(_buildNumberedItem(match.group(1)!, match.group(2)!));
        }
      }
      // Bullet list
      else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        widgets.add(_buildBulletItem(trimmed.substring(2)));
      }
      // Normal paragraph
      else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              trimmed,
              style: AppTextStyles.bodyLarge.copyWith(
                color: const Color(0xFF334155),
                height: 1.7,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildNumberedItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppColors.primary100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                number,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyLarge.copyWith(
                color: const Color(0xFF334155),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 12, top: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyLarge.copyWith(
                color: const Color(0xFF334155),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tag,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
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

  void _shareArticle() {
    final article = context.read<KnowledgeProvider>().selectedArticle;
    if (article != null) {
      Clipboard.setData(ClipboardData(text: article.title));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Article title copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
