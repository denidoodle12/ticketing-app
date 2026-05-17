import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../providers/knowledge_provider.dart';
import '../models/ai_chat_model.dart';
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
  static const int _minChars = 3;
  static const String _onboardedKey = 'ai_chat_onboarded';

  bool _isOnboarded = true;
  bool _isCheckingOnboard = true;

  // Track message count for smart auto-scroll
  int _previousMessageCount = 0;
  bool _shouldForceScroll = false;

  // Real-time offline detection — knowledge endpoints are not cached.
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

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

    // Check initial connectivity
    _isOffline = !ConnectivityService().isConnected;

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KnowledgeProvider>().clearChat();
      _checkOnboardStatus();
    });
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isNowOffline = results.contains(ConnectivityResult.none);
    if (isNowOffline != _isOffline && mounted) {
      setState(() => _isOffline = isNowOffline);
    }
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
    _connectivitySubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// Check if user is near the bottom of the chat list (within 150px)
  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 150;
  }

  /// Scroll to the bottom of the chat list
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      // First: hard-stop any active fling by jumping to max immediately
      _scrollController.jumpTo(maxExtent);
      // Then: smoothly animate to ensure we're truly at bottom
      // (maxExtent might update slightly after jump)
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  /// Smart auto-scroll: only scroll if user is near bottom or just sent a message
  void _smartScrollToBottom(int currentMessageCount) {
    if (currentMessageCount > _previousMessageCount) {
      // New message arrived
      if (_shouldForceScroll || _isNearBottom()) {
        _scrollToBottom();
      }
      _shouldForceScroll = false;
    }
    _previousMessageCount = currentMessageCount;
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    // Guard: don't send while offline. The build flow already shows the
    // offline placeholder, but this is a safety net for the transient
    // moment between connectivity events.
    if (_isOffline) return;
    // #5: Haptic feedback on send
    HapticFeedback.lightImpact();
    _shouldForceScroll = true; // Always scroll after user sends
    context.read<KnowledgeProvider>().sendMessage(text.trim());
    _textController.clear();
    _focusNode.requestFocus(); // Keep focus on input after send
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _isCheckingOnboard
          ? null
          : (_isOffline
              ? _buildOfflineAppBar()
              : (!_isOnboarded ? _buildGetStartedAppBar() : _buildAppBar())),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF0F4FF), // Soft blue-white top
              Color(0xFFF8FAFF), // Very light blue mid
              AppColors.white, // Pure white bottom
            ],
            stops: [0.0, 0.35, 0.7],
          ),
        ),
        child: SafeArea(
          child: _isCheckingOnboard
              ? const SizedBox.shrink()
              : _isOffline
                  ? _buildOfflinePlaceholder()
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: Consumer<KnowledgeProvider>(
                        builder: (context, provider, _) {
                          // Smart auto-scroll: only when new messages arrive & user near bottom
                          if (provider.chatMessages.isNotEmpty) {
                            _smartScrollToBottom(provider.chatMessages.length);
                          }

                          if (!_isOnboarded) {
                            return _buildGetStartedView();
                          }

                          return Column(
                            children: [
                              Expanded(
                                child: provider.hasChatHistory
                                    ? _buildChatArea(provider)
                                    : _buildWelcomeView(provider),
                              ),
                              _buildInputBar(provider),
                            ],
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }

  // ─── Offline state ─────────────────────────────────────────────

  PreferredSizeWidget _buildOfflineAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 76,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(child: _buildBackButton()),
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

  Widget _buildOfflinePlaceholder() {
    return const Center(
      child: OfflineStateWidget(
        title: 'TixAI Unavailable Offline',
        description:
            'AI Assistant requires an active internet connection to answer your questions.',
      ),
    );
  }

  // ─── Rounded back button (matches ticket detail style) ─────────

  Widget _buildBackButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context),
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
          child: const Icon(
            Icons.arrow_back,
            color: AppColors.primaryDark,
            size: 22,
          ),
        ),
      ),
    );
  }

  // ─── AppBar for Get-Started state ─────────────────────────────

  PreferredSizeWidget _buildGetStartedAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
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
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 76,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(child: _buildBackButton()),
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
    );
  }

  // ─── Get Started (First-Time Only) ──────────────────────────────

  Widget _buildGetStartedView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(flex: 3),
          // Chatbot illustration — centered
          Center(
            child: Image.asset(AssetPaths.chatbot, width: 250, height: 250),
          ),
          const SizedBox(height: 16),
          // "Welcome to" — left-aligned
          Text(
            'Welcome to',
            style: AppTextStyles.h2.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          // "TixAI 👋" — primaryDark, left-aligned
          Text(
            'TixAI 👋',
            style: AppTextStyles.h2.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          // Subtitle — left-aligned
          Text(
            'Start chatting with TixAI Assistant now.\nYou can ask me anything about articles.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // "Hi, I'm" — left-aligned
                Text(
                  'Hello,',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                // "TixAI" — primaryDark, left-aligned
                Text(
                  'I\'m TixAI',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'I can help you today',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Take a deep breath. I\'m ready when you are.\nChoose what you\'d like to search for:',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
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

  // ─── Chat Area ──────────────────────────────────────────────────

  Widget _buildChatArea(KnowledgeProvider provider) {
    return _buildChatList(provider);
  }

  Widget _buildChatList(KnowledgeProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Gemini-style dynamic padding:
        // - Large padding when waiting for AI (user msg at top, space for response)
        // - Minimal padding when AI has already responded (no wasted space)
        final messages = provider.chatMessages;
        final isWaitingForAi =
            messages.isNotEmpty &&
            (messages.last.isLoading || messages.last.role == ChatRole.user);
        final bottomPadding = isWaitingForAi
            ? constraints.maxHeight * 0.55
            : 16.0;

        return ListView.builder(
          controller: _scrollController,
          // #2: Dismiss keyboard when user scrolls through chat
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return ChatBubble(
              message: message,
              onRetry: message.isError
                  ? () => provider.retryLastMessage()
                  : null,
            );
          },
        );
      },
    );
  }

  // ─── Input Bar (Gemini-style) ────────────────────────────────────

  Widget _buildInputBar(KnowledgeProvider provider) {
    final trimmedText = _textController.text.trim();
    final canSend = trimmedText.length >= _minChars && !provider.isAiResponding;
    final showMinHint =
        trimmedText.isNotEmpty && trimmedText.length < _minChars;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 140),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.grey300, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withAlpha(15),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Text field — clean, no hover/focus effects
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: null,
                  maxLength: _maxChars,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  mouseCursor: SystemMouseCursors.text,
                  cursorColor: AppColors.primary,
                  onSubmitted: canSend
                      ? (text) => _sendMessage(text)
                      : (_) {
                          _focusNode.requestFocus();
                        },
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: showMinHint
                        ? 'Type at least $_minChars characters'
                        : 'Ask TixAI',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: showMinHint
                          ? AppColors.warning700
                          : AppColors.grey400,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    hoverColor: Colors.transparent,
                    contentPadding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              // Send button — floating circle inside container
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: (canSend || provider.isAiResponding)
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary600,
                              AppColors.primary500,
                            ],
                          )
                        : null,
                    color: (canSend || provider.isAiResponding)
                        ? null
                        : AppColors.grey200,
                    shape: BoxShape.circle,
                  ),
                  child: provider.isAiResponding
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        )
                      : Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canSend
                                ? () => _sendMessage(_textController.text)
                                : null,
                            borderRadius: BorderRadius.circular(19),
                            child: Center(
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                color: canSend
                                    ? AppColors.white
                                    : AppColors.grey400,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
