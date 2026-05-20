// AI Chat models for the Knowledge Base AI Assistant

/// Response from POST /knowledge/ask
class AiAskResponse {
  final String message;
  final String answer;
  final int sourceCount;
  final String searchMode;
  final List<AiSource> sources;

  const AiAskResponse({
    required this.message,
    required this.answer,
    required this.sourceCount,
    required this.searchMode,
    required this.sources,
  });

  factory AiAskResponse.fromJson(Map<String, dynamic> json) {
    return AiAskResponse(
      message: json['message'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      sourceCount: json['source_count'] as int? ?? 0,
      searchMode: json['search_mode'] as String? ?? 'fallback',
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => AiSource.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// A source article referenced by the AI in its answer
class AiSource {
  final int id;
  final String title;
  final List<String> tags;

  const AiSource({
    required this.id,
    required this.title,
    this.tags = const [],
  });

  factory AiSource.fromJson(Map<String, dynamic> json) {
    return AiSource(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// Role for chat messages
enum ChatRole { user, assistant }

/// Lightweight reference to a knowledge article that the user mentioned
/// in their question (via @-mention in the input bar). Persisted on the
/// user [AiChatMessage] so the bubble can render tappable chips after send.
class MentionedArticle {
  final int id;
  final String title;

  const MentionedArticle({required this.id, required this.title});
}

/// Local UI model for a single chat message
class AiChatMessage {
  final ChatRole role;
  final String content;
  final List<AiSource> sources;
  final String? searchMode;
  final DateTime timestamp;
  final bool isLoading;
  final bool isError;

  /// Articles the user explicitly mentioned via @-picker for this message.
  /// Only populated for [ChatRole.user] messages.
  final List<MentionedArticle> mentionedArticles;

  const AiChatMessage({
    required this.role,
    required this.content,
    this.sources = const [],
    this.searchMode,
    required this.timestamp,
    this.isLoading = false,
    this.isError = false,
    this.mentionedArticles = const [],
  });

  /// Create a user message, optionally tagged with mentioned articles.
  factory AiChatMessage.user(
    String content, {
    List<MentionedArticle> mentionedArticles = const [],
  }) {
    return AiChatMessage(
      role: ChatRole.user,
      content: content,
      timestamp: DateTime.now(),
      mentionedArticles: mentionedArticles,
    );
  }

  /// Create a loading placeholder for the assistant
  factory AiChatMessage.loading() {
    return AiChatMessage(
      role: ChatRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isLoading: true,
    );
  }

  /// Create an assistant response from API data
  factory AiChatMessage.fromResponse(AiAskResponse response) {
    return AiChatMessage(
      role: ChatRole.assistant,
      content: response.answer,
      sources: response.sources,
      searchMode: response.searchMode,
      timestamp: DateTime.now(),
    );
  }

  /// Create an error message
  factory AiChatMessage.error(String errorMessage) {
    return AiChatMessage(
      role: ChatRole.assistant,
      content: errorMessage,
      timestamp: DateTime.now(),
      isError: true,
    );
  }

  /// Copy with replacement (for replacing loading placeholder)
  AiChatMessage copyWith({
    ChatRole? role,
    String? content,
    List<AiSource>? sources,
    String? searchMode,
    DateTime? timestamp,
    bool? isLoading,
    bool? isError,
    List<MentionedArticle>? mentionedArticles,
  }) {
    return AiChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      sources: sources ?? this.sources,
      searchMode: searchMode ?? this.searchMode,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
      isError: isError ?? this.isError,
      mentionedArticles: mentionedArticles ?? this.mentionedArticles,
    );
  }
}
