import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/asset_paths.dart';
import '../providers/knowledge_provider.dart';
import '../widgets/chat_bubble.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  static const int _maxChars = 500;

  // Suggested questions for the welcome state
  static const List<Map<String, dynamic>> _suggestedQuestions = [
    {
      'icon': Icons.confirmation_number_outlined,
      'text': 'How to create a new ticket?',
    },
    {
      'icon': Icons.lock_reset_outlined,
      'text': 'How to reset my password?',
    },
    {
      'icon': Icons.category_outlined,
      'text': 'What ticket categories are available?',
    },
    {
      'icon': Icons.help_outline,
      'text': 'How to use the knowledge base?',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Reset chat when screen opens (no persistence as per user preference)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KnowledgeProvider>().clearChat();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    context.read<KnowledgeProvider>().sendMessage(text.trim());
    _textController.clear();
    setState(() {});
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: _buildAppBar(),
      body: Consumer<KnowledgeProvider>(
        builder: (context, provider, _) {
          // Scroll to bottom whenever messages change
          if (provider.chatMessages.isNotEmpty) {
            _scrollToBottom();
          }

          return Column(
            children: [
              Expanded(
                child: provider.hasChatHistory
                    ? _buildChatList(provider)
                    : _buildWelcomeView(),
              ),
              _buildInputBar(provider),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        color: AppColors.textPrimary,
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo icon
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              AssetPaths.tixcoraColor,
              width: 28,
              height: 28,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'TixAI',
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        Consumer<KnowledgeProvider>(
          builder: (context, provider, _) {
            if (!provider.hasChatHistory) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 22),
              color: AppColors.textSecondary,
              tooltip: 'New Chat',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('New Chat'),
                    content: const Text(
                        'Start a new conversation? Current chat will be cleared.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          provider.clearChat();
                        },
                        child: Text(
                          'Clear',
                          style: TextStyle(color: AppColors.error500),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ─── Welcome / Get Started View ─────────────────────────────────

  Widget _buildWelcomeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Logo
          Image.asset(
            AssetPaths.tixcoraColor,
            width: 72,
            height: 72,
          ),
          const SizedBox(height: 28),
          // Welcome text
          Text(
            'Welcome back',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'How may I help you today?',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 40),
          // Suggested questions grid (2x2)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: _suggestedQuestions.length,
            itemBuilder: (context, index) {
              final q = _suggestedQuestions[index];
              return _buildSuggestionCard(
                icon: q['icon'] as IconData,
                text: q['text'] as String,
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard({
    required IconData icon,
    required String text,
  }) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.neutral50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.secondary200.withAlpha(120)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary500),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Chat List ──────────────────────────────────────────────────

  Widget _buildChatList(KnowledgeProvider provider) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: provider.chatMessages.length,
      itemBuilder: (context, index) {
        final message = provider.chatMessages[index];
        return ChatBubble(
          message: message,
          onRetry: message.isError ? () => provider.retryLastMessage() : null,
        );
      },
    );
  }

  // ─── Input Bar ─────────────────────────────────────────────────

  Widget _buildInputBar(KnowledgeProvider provider) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 12,
        bottom: 12 + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.neutral50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? AppColors.primary400
                      : AppColors.secondary200,
                ),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: 3,
                minLines: 1,
                maxLength: _maxChars,
                textInputAction: TextInputAction.newline,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask me anything...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.grey400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  counterText: '', // Hide default counter
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: provider.isAiResponding ||
                    _textController.text.trim().isEmpty
                ? null
                : () => _sendMessage(_textController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _textController.text.trim().isNotEmpty &&
                        !provider.isAiResponding
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary600, AppColors.primary500],
                      )
                    : null,
                color: _textController.text.trim().isEmpty ||
                        provider.isAiResponding
                    ? AppColors.grey300
                    : null,
                borderRadius: BorderRadius.circular(22),
                boxShadow: _textController.text.trim().isNotEmpty &&
                        !provider.isAiResponding
                    ? [
                        BoxShadow(
                          color: AppColors.primary500.withAlpha(40),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                color: _textController.text.trim().isNotEmpty &&
                        !provider.isAiResponding
                    ? AppColors.white
                    : AppColors.grey500,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
