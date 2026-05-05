import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _AiChatScreenState extends State<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  static const int _maxChars = 500;
  static const String _onboardedKey = 'ai_chat_onboarded';

  bool _isOnboarded = true; // Default true, will check async
  bool _isCheckingOnboard = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KnowledgeProvider>().clearChat();
      _checkOnboardStatus();
    });
  }

  Future<void> _checkOnboardStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool(_onboardedKey) ?? false;
    if (mounted) {
      setState(() {
        _isOnboarded = onboarded;
        _isCheckingOnboard = false;
      });
      _fadeController.forward();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
    if (mounted) {
      _fadeController.reverse().then((_) {
        if (mounted) {
          setState(() => _isOnboarded = true);
          _fadeController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
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
      appBar: _isCheckingOnboard
          ? null
          : (!_isOnboarded ? _buildGetStartedAppBar() : _buildAppBar()),
      body: _isCheckingOnboard
          ? const SizedBox.shrink()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Consumer<KnowledgeProvider>(
                builder: (context, provider, _) {
                  if (provider.chatMessages.isNotEmpty) {
                    _scrollToBottom();
                  }

                  // Three states: get-started → welcome → chatting
                  if (!_isOnboarded) {
                    return _buildGetStartedView();
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: provider.hasChatHistory
                            ? _buildChatList(provider)
                            : _buildWelcomeView(provider),
                      ),
                      _buildInputBar(provider),
                    ],
                  );
                },
              ),
            ),
    );
  }

  // ─── AppBar for Get-Started state ─────────────────────────────

  PreferredSizeWidget _buildGetStartedAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(AssetPaths.tixcoraColor, width: 30, height: 30),
          ),
        ),
      ),
      title: Text(
        'TixAI',
        style: AppTextStyles.h5.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  // ─── AppBar for Chat state ────────────────────────────────────

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
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(AssetPaths.tixcoraColor, width: 28, height: 28),
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
                      'Start a new conversation? Current chat will be cleared.',
                    ),
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

  // ─── Get Started (First-Time Only) ──────────────────────────────

  Widget _buildGetStartedView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 3),
          // Large tixcora logo
          Image.asset(AssetPaths.chatbot, width: 250, height: 250),
          const SizedBox(height: 16),
          // "Welcome to" — normal text
          Text(
            'Welcome to',
            style: AppTextStyles.h2.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          // "TixAI 👋" — primaryDark color
          Text(
            'TixAI 👋',
            style: AppTextStyles.h2.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 36),
          // Subtitle lines
          Text(
            'Start chatting with TixAI now.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 0),
          Text(
            'You can ask me anything.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 4),
          // "Start Chat" gradient button
          _buildGradientButton(text: 'Start Chat', onTap: _completeOnboarding),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.primary600, AppColors.primary500],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary500.withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: AppTextStyles.button.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Welcome View (Returning User) ──────────────────────────────

  Widget _buildWelcomeView(KnowledgeProvider provider) {
    final suggestions = provider.suggestedQuestions;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Welcome text — Aria-style, clean, no icon
                Text(
                  'Hi, I\'m TixAI',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'I can help you today',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Take a deep breath. I\'m ready when you are.\nChoose what you\'d like to work on:',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                // Suggested questions grid (2×2)
                _buildSuggestionsGrid(suggestions),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionsGrid(List<String> suggestions) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: suggestions.map((text) => _buildSuggestionCard(text)).toList(),
    );
  }

  Widget _buildSuggestionCard(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.secondary200),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
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

  // ─── Input Bar ──────────────────────────────────────────────────

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
                  counterText: '',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap:
                provider.isAiResponding || _textController.text.trim().isEmpty
                ? null
                : () => _sendMessage(_textController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient:
                    _textController.text.trim().isNotEmpty &&
                        !provider.isAiResponding
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary600, AppColors.primary500],
                      )
                    : null,
                color:
                    _textController.text.trim().isEmpty ||
                        provider.isAiResponding
                    ? AppColors.grey300
                    : null,
                borderRadius: BorderRadius.circular(22),
                boxShadow:
                    _textController.text.trim().isNotEmpty &&
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
                color:
                    _textController.text.trim().isNotEmpty &&
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
