import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';
import '../../../core/mixins/offline_aware_mixin.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../providers/ticket_provider.dart';
import '../../search/widgets/filter_bottom_sheet.dart';
import '../models/ticket_model.dart';
import '../widgets/ticket_card.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/ticket_card_shimmer.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen>
    with OfflineAwareStateMixin<TicketsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _selectedFilter = 'all';

  // Additional filters from bottom sheet (single-select)
  String? _selectedPriority;
  int? _bottomSheetStatusId;

  static const _pageSize = 10;
  final PagingController<int, Ticket> _pagingController = PagingController(
    firstPageKey: 1,
  );

  // Flag to track if filter has been initialized
  bool _isFilterInitialized = false;



  final List<Map<String, dynamic>> _filterOptions = [
    {'id': 'all', 'label': 'All'},
    {'id': 'open', 'label': 'Open'},
    {'id': 'in_progress', 'label': 'In Progress'},
    {'id': 'pending', 'label': 'Pending'},
    {'id': 'resolved', 'label': 'Resolved'},
    {'id': 'closed', 'label': 'Closed'},
  ];

  @override
  void initState() {
    super.initState();

    // Add page request listener
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ticketProvider = context.read<TicketProvider>();
      ticketProvider.loadStatuses();
      ticketProvider.loadCategories();
      ticketProvider.loadTicketStats();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _pagingController.dispose();
    super.dispose();
  }

  /// Handle connectivity changes via mixin: when we come back online,
  /// refresh the paged ticket list and the stats card.
  @override
  void onConnectionRestored() {
    if (!mounted) return;
    _pagingController.refresh();
    context.read<TicketProvider>().loadTicketStats();
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final ticketProvider = context.read<TicketProvider>();

      // Reset ALL provider filters on first page fetch if not initialized
      // This ensures filters reset when navigating back to this screen
      if (!_isFilterInitialized && pageKey == 1) {
        ticketProvider.setFilterStatusForPaging(null, statusName: null);
        ticketProvider.setFilterPriorityForPaging(null);
        ticketProvider.setSearchQueryForPaging(null);
        _isFilterInitialized = true;
      }

      // Fetch tickets from provider/repository (server-side filtering & search)
      final response = await ticketProvider.fetchTicketsPage(
        page: pageKey,
        limit: _pageSize,
      );

      // Check if widget is still mounted before updating controller
      if (!mounted) return;

      var newItems = response.tickets.toList();

      // Note: We intentionally show ALL tickets (including closed) under
      // the "All" tab. Users can filter by specific status using the chips
      // or bottom sheet when they want to narrow down the list.

      // Determine if this is the last page based on API response
      final isLastPage =
          !response.hasNext || response.tickets.length < _pageSize;

      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      // Check if widget is still mounted before setting error
      if (mounted) {
        _pagingController.error = error;
      }
    }
  }

  /// Get status ID from filter ID
  /// Uses loaded statuses first, falls back to hardcoded mapping if not available
  int? _getStatusIdFromFilterId(
    String filterId,
    TicketProvider ticketProvider,
  ) {
    if (filterId == 'all') return null;

    // Try to find from loaded statuses first
    final statuses = ticketProvider.statuses;
    if (statuses.isNotEmpty) {
      final matchingStatus = statuses.where(
        (s) =>
            s.name.toLowerCase() == filterId.toLowerCase() ||
            s.name.toLowerCase().replaceAll(' ', '_') == filterId.toLowerCase(),
      );
      if (matchingStatus.isNotEmpty) {
        return matchingStatus.first.id;
      }
    }

    // Fallback to hardcoded status mapping (based on typical backend status IDs)
    // This ensures filter works even if statuses haven't loaded yet
    final statusIdMapping = <String, int>{
      'open': 1,
      'in_progress': 2,
      'pending': 3,
      'resolved': 4,
      'closed': 5,
    };

    return statusIdMapping[filterId.toLowerCase()];
  }

  /// Get human-readable status name from filter chip ID
  /// Maps filter IDs (e.g., 'open', 'in_progress') to backend status names
  String? _getStatusNameFromFilterId(String filterId) {
    if (filterId == 'all') return null;
    const nameMapping = <String, String>{
      'open': 'Open',
      'in_progress': 'In Progress',
      'pending': 'Pending',
      'resolved': 'Resolved',
      'closed': 'Closed',
    };
    return nameMapping[filterId.toLowerCase()];
  }

  void _onFilterSelected(String filterId) {
    if (_selectedFilter == filterId) return;

    setState(() {
      _selectedFilter = filterId;
      // Reset bottom sheet status when top chips change
      _bottomSheetStatusId = null;
    });

    final ticketProvider = context.read<TicketProvider>();
    final statusId = _getStatusIdFromFilterId(filterId, ticketProvider);
    // Resolve status name from filter label for offline cache matching
    final statusName = _getStatusNameFromFilterId(filterId);
    ticketProvider.setFilterStatusForPaging(statusId, statusName: statusName);

    // Refresh the list
    _pagingController.refresh();
  }

  void _onSearch(String query) {
    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // Start new debounce timer (500ms delay)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        // Set search query on provider for server-side filtering
        final ticketProvider = context.read<TicketProvider>();
        ticketProvider.setSearchQueryForPaging(
          query.trim().isEmpty ? null : query.trim(),
        );
        // Refresh the list with new search query
        _pagingController.refresh();
      }
    });
  }

  void _navigateToTicketDetail(Ticket ticket) {
    context.push('/tickets/detail', extra: ticket);
  }

  Future<void> _onRefresh() async {
    // Refresh stats
    context.read<TicketProvider>().loadTicketStats();
    // Refresh list
    _pagingController.refresh();
  }

  void _showFilterBottomSheet() {
    final ticketProvider = context.read<TicketProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        statuses: ticketProvider.statuses,
        selectedStatusId: _bottomSheetStatusId,
        selectedPriority: _selectedPriority,
        onApply: (statusId, priority) {
          setState(() {
            _selectedPriority = priority;
            _bottomSheetStatusId = statusId;
          });
          // Set server-side filters on provider
          ticketProvider.setFilterPriorityForPaging(priority);
          // Resolve status name for offline cache matching
          String? statusName;
          if (statusId != null) {
            final match = ticketProvider.statuses.where(
              (s) => s.id == statusId,
            );
            if (match.isNotEmpty) statusName = match.first.name;
          }
          ticketProvider.setFilterStatusForPaging(
            statusId,
            statusName: statusName,
          );
          // Reset top chips to 'all' when bottom sheet overrides status
          if (statusId != null) {
            setState(() {
              _selectedFilter = 'all';
            });
          }
          // Refresh the list with new filters
          _pagingController.refresh();
        },
      ),
    );
  }

  bool get _hasActiveFilters =>
      _selectedPriority != null || _bottomSheetStatusId != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Filter chips
          _buildFilterChips(),

          // Search bar
          _buildSearchBar(),

          // Ticket list
          Expanded(child: _buildTicketList()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: Text(
        'My Tickets',
        style: AppTextStyles.h5.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filterOptions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filterOptions[index];
          final filterId = filter['id'] as String;
          final isSelected = _selectedFilter == filterId;

          return GestureDetector(
            onTap: () => _onFilterSelected(filterId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryDark : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primaryDark : AppColors.grey300,
                  width: 1,
                ),
              ),
              child: Text(
                '${filter['label']}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected ? AppColors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: AppColors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                // Search TextField
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search Tickets...',
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
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: _onSearch,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Filter Button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _hasActiveFilters
                        ? AppColors.primaryDark
                        : AppColors.primary50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _showFilterBottomSheet,
                    icon: Icon(
                      Icons.tune_rounded,
                      color: _hasActiveFilters
                          ? AppColors.white
                          : AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom shadow divider
        Container(
          height: 8,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withAlpha(15), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: PagedListView<int, Ticket>.separated(
            pagingController: _pagingController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            // Pre-render items off-screen for smoother scrolling
            cacheExtent: 500,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            builderDelegate: PagedChildBuilderDelegate<Ticket>(
              // Wrap with RepaintBoundary for better performance
              itemBuilder: (context, ticket, index) => RepaintBoundary(
                child: TicketCard(
                  ticket: ticket,
                  onTap: () => _navigateToTicketDetail(ticket),
                ),
              ),
              firstPageProgressIndicatorBuilder: (context) =>
                  const TicketCardShimmerList(
                    itemCount: 4,
                    padding: EdgeInsets.zero,
                  ),
              newPageProgressIndicatorBuilder: (context) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              noItemsFoundIndicatorBuilder: (context) => _buildEmptyState(
                availableHeight: constraints.maxHeight,
                isSearchResult:
                    _searchController.text.isNotEmpty ||
                    _selectedFilter != 'all',
              ),
              firstPageErrorIndicatorBuilder: (context) => _buildErrorState(
                _pagingController.error?.toString() ?? 'An error occurred',
              ),
              newPageErrorIndicatorBuilder: (context) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Failed to load more',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.error500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            _pagingController.retryLastFailedRequest(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required double availableHeight,
    bool isSearchResult = false,
  }) {
    final bool isStatusFilter = _selectedFilter != 'all';
    final bool hasSearchQuery = _searchController.text.isNotEmpty;

    final Widget emptyWidget;

    if (hasSearchQuery) {
      emptyWidget = const EmptyStateWidget(
        imagePath: 'assets/images/empty-states/empty-two.png',
        title: 'No Results Found',
        description: 'Try a different keyword or check the spelling.',
      );
    } else if (isStatusFilter) {
      emptyWidget = const EmptyStateWidget(
        imagePath: 'assets/images/empty-states/empty-one.png',
        title: 'No Tickets Here',
        description: 'There are no tickets with this status right now.',
      );
    } else {
      emptyWidget = const EmptyStateWidget(
        imagePath: 'assets/images/empty-states/empty-one.png',
        title: 'No Tickets Yet',
        description: 'Create a new ticket to get started.',
      );
    }

    // Subtract PagedListView padding (top: 16, bottom: 100) so Center
    // aligns to the actual visible viewport, not the padded scroll area.
    final contentHeight = availableHeight - 16 - 100;

    return SizedBox(
      height: contentHeight > 0 ? contentHeight : availableHeight,
      child: Center(child: emptyWidget),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error500.withAlpha(150),
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _pagingController.refresh(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
