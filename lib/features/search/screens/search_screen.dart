import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../providers/ticket_provider.dart';
import '../../tickets/models/ticket_model.dart';
import '../../tickets/widgets/ticket_card.dart';
import '../services/recent_search_service.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/priority_filter_section.dart';
import '../widgets/recent_searches_section.dart';
import '../widgets/search_results_header.dart';
import '../widgets/search_tips_card.dart';
import '../../../shared/widgets/ticket_card_shimmer.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/circle_icon_button.dart';

enum SearchScreenState { initial, searching, results, empty }

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final RecentSearchService _recentSearchService = RecentSearchService();
  Timer? _debounceTimer;

  // State
  SearchScreenState _screenState = SearchScreenState.initial;
  List<String> _recentSearches = [];
  List<Ticket> _searchResults = [];
  int _totalResults = 0;
  String _lastSearchedQuery = ''; // tracks last completed query to avoid duplicate calls

  // Single-select server-side filters
  int? _selectedStatusId;
  String? _selectedPriority;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    // Handle initial query if provided
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadRecentSearches();

    if (!mounted) return;

    final ticketProvider = context.read<TicketProvider>();
    await ticketProvider.loadStatuses();
  }

  Future<void> _loadRecentSearches() async {
    final searches = await _recentSearchService.getRecentSearches();
    if (mounted) {
      setState(() {
        _recentSearches = searches;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    // Clear all filters when user types a new search
    if (_selectedStatusId != null || _selectedPriority != null) {
      setState(() {
        _selectedStatusId = null;
        _selectedPriority = null;
      });
    }

    if (query.trim().isEmpty) {
      setState(() {
        _screenState = SearchScreenState.initial;
        _searchResults = [];
        _totalResults = 0;
        _lastSearchedQuery = '';
      });
      return;
    }

    // Only show searching state if no results yet for this query
    if (_lastSearchedQuery != query.trim()) {
      setState(() {
        _screenState = SearchScreenState.searching;
      });
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    // Skip duplicate call if same query already completed
    if (trimmedQuery == _lastSearchedQuery &&
        _screenState == SearchScreenState.results) {
      return;
    }

    // Show searching state but keep existing results visible (no flash to empty)
    setState(() {
      _screenState = SearchScreenState.searching;
    });

    // Save to recent searches
    await _recentSearchService.addRecentSearch(trimmedQuery);
    await _loadRecentSearches();

    if (!mounted) return;

    try {
      final ticketProvider = context.read<TicketProvider>();

      // Set server-side filters on provider (all single-select)
      ticketProvider.setFilterStatusForPaging(_selectedStatusId);
      ticketProvider.setSearchQueryForPaging(trimmedQuery);
      ticketProvider.setFilterPriorityForPaging(_selectedPriority);

      // Fetch tickets from API with server-side filters & search
      final response = await ticketProvider.fetchTicketsPage(
        page: 1,
        limit: 20,
      );

      if (mounted) {
        _lastSearchedQuery = trimmedQuery;
        setState(() {
          _searchResults = response.tickets;
          _totalResults = response.total;
          _screenState = response.tickets.isEmpty
              ? SearchScreenState.empty
              : SearchScreenState.results;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _screenState = SearchScreenState.empty;
          _searchResults = [];
          _totalResults = 0;
        });
      }
    }
  }

  void _onRecentSearchTap(String search) {
    _searchController.text = search;
    _performSearch(search);
  }

  Future<void> _onDeleteRecentSearch(String search) async {
    await _recentSearchService.removeRecentSearch(search);
    await _loadRecentSearches();
  }

  Future<void> _onClearAllRecentSearches() async {
    await _recentSearchService.clearAllRecentSearches();
    await _loadRecentSearches();
  }

  void _onPriorityTap(String priority) {
    setState(() {
      // Single-select toggle: tap again to deselect
      _selectedPriority = _selectedPriority == priority ? null : priority;
    });
    // Perform filter search (works with or without text query)
    _performFilterSearch();
  }

  /// Perform search with filters (can work without text query)
  Future<void> _performFilterSearch() async {
    setState(() {
      _screenState = SearchScreenState.searching;
    });

    if (!mounted) return;

    try {
      final ticketProvider = context.read<TicketProvider>();

      // Set server-side filters on provider (all single-select)
      ticketProvider.setFilterStatusForPaging(_selectedStatusId);
      final searchQuery = _searchController.text.trim();
      ticketProvider.setSearchQueryForPaging(
        searchQuery.isNotEmpty ? searchQuery : null,
      );
      ticketProvider.setFilterPriorityForPaging(_selectedPriority);

      // Fetch tickets from API with server-side filters & search
      final response = await ticketProvider.fetchTicketsPage(
        page: 1,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _searchResults = response.tickets;
          _totalResults = response.total;
          _screenState = response.tickets.isEmpty
              ? SearchScreenState.empty
              : SearchScreenState.results;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _screenState = SearchScreenState.empty;
          _searchResults = [];
          _totalResults = 0;
        });
      }
    }
  }

  void _showFilterBottomSheet() {
    final ticketProvider = context.read<TicketProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        statuses: ticketProvider.statuses,
        selectedStatusId: _selectedStatusId,
        selectedPriority: _selectedPriority,
        onApply: (statusId, priority) {
          setState(() {
            _selectedStatusId = statusId;
            _selectedPriority = priority;
          });
          // Re-perform search with new filters
          _performFilterSearch();
        },
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _screenState = SearchScreenState.initial;
      _searchResults = [];
      _totalResults = 0;
    });
    _focusNode.requestFocus();
  }

  void _tryAnotherSearch() {
    _searchController.clear();
    setState(() {
      _screenState = SearchScreenState.initial;
      _selectedStatusId = null;
      _selectedPriority = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar header
            _buildSearchHeader(),

            // Content based on state
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }



  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button with rounded square background (same as detail screen)
          CircleIconButton.back(context),
          const SizedBox(width: 12),

          // Search field
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search tickets...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.grey400,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Icon(
                      Icons.search,
                      color: AppColors.grey400,
                      size: 22,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 46,
                    minHeight: 46,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: Icon(
                            Icons.close,
                            color: AppColors.grey400,
                            size: 20,
                          ),
                        )
                      : null,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 14,
                  ),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _focusNode.unfocus(), // just dismiss keyboard
                textInputAction: TextInputAction.done,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_screenState) {
      case SearchScreenState.initial:
        return _buildInitialContent();
      case SearchScreenState.searching:
        return _buildSearchingContent();
      case SearchScreenState.results:
        return _buildResultsContent();
      case SearchScreenState.empty:
        return _buildEmptyContent();
    }
  }

  Widget _buildInitialContent() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent searches
          RecentSearchesSection(
            recentSearches: _recentSearches,
            onSearchTap: _onRecentSearchTap,
            onDeleteTap: _onDeleteRecentSearch,
            onClearAll: _onClearAllRecentSearches,
          ),

          if (_recentSearches.isNotEmpty) const SizedBox(height: 24),

          // Priority quick-select (server-side filter)
          PriorityFilterSection(
            selectedPriority: _selectedPriority,
            onPriorityTap: _onPriorityTap,
          ),

          const SizedBox(height: 24),

          // Search tips
          const SearchTipsCard(),
        ],
      ),
    );
  }

  Widget _buildSearchingContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // Searching text
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Searching...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary500,
              ),
            ),
          ),

          // Shimmer loading
          const TicketCardShimmerList(itemCount: 3),
        ],
      ),
    );
  }

  Widget _buildResultsContent() {
    final hasActiveFilters =
        _selectedStatusId != null || _selectedPriority != null;

    return Column(
      children: [
        // Results header
        SearchResultsHeader(
          count: _totalResults,
          hasActiveFilters: hasActiveFilters,
          onFilterTap: _showFilterBottomSheet,
        ),

        // Results list
        Expanded(
          child: ListView.separated(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: _searchResults.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ticket = _searchResults[index];
              return TicketCard(
                ticket: ticket,
                onTap: () {
                  context.push('/tickets/detail', extra: ticket);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyContent() {
    final hasActiveFilters =
        _selectedStatusId != null || _selectedPriority != null;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Illustration-based empty state
          EmptyStateWidget(
            imagePath: 'assets/images/empty-states/empty-two.png',
            title: hasActiveFilters
                ? 'No Matching Tickets'
                : 'No Results Found',
            description: hasActiveFilters
                ? 'No tickets match your current filters. Try adjusting them.'
                : 'Try a different keyword or check the spelling.',
          ),
          const SizedBox(height: 24),

          // Try another search button
          OutlinedButton(
            onPressed: _tryAnotherSearch,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: BorderSide(color: AppColors.primaryDark, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Try Another Search',
              style: AppTextStyles.buttonSmall.copyWith(
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
