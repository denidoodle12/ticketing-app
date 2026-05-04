import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
                      const Icon(Icons.refresh, size: 14, color: AppColors.error700),
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

    // Normal message
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: _isUser
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary600, AppColors.primary500],
              )
            : null,
        color: _isUser ? null : AppColors.neutral100,
        borderRadius: _isUser
            ? BorderRadius.circular(16).copyWith(
                bottomRight: const Radius.circular(4),
              )
            : BorderRadius.circular(16).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
        boxShadow: _isUser
            ? [
                BoxShadow(
                  color: AppColors.primary500.withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        message.content,
        style: AppTextStyles.bodyMedium.copyWith(
          color: _isUser ? AppColors.white : AppColors.textPrimary,
          height: 1.5,
        ),
      ),
    );
  }

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
