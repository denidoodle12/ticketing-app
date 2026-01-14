import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../providers/ticket_provider.dart';
import '../widgets/ticket_card.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  String _selectedFilter = 'all';

  final List<Map<String, dynamic>> _filterOptions = [
    {'id': 'all', 'label': 'All'},
    {'id': 'open', 'label': 'Open'},
    {'id': 'in_progress', 'label': 'In Progress'},
    {'id': 'pending', 'label': 'Pending'},
    {'id': 'resolved', 'label': 'Resolved'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Load initial data and reset filters
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ticketProvider = context.read<TicketProvider>();
      ticketProvider.loadStatuses();
      // Reset filter and reload tickets
      ticketProvider.resetAndLoadTickets();
      // Reset local state
      _searchController.clear();
      setState(() {
        _selectedFilter = 'all';
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<TicketProvider>().loadMoreTickets();
    }
  }

  void _onFilterSelected(String filterId) {
    setState(() {
      _selectedFilter = filterId;
    });

    final ticketProvider = context.read<TicketProvider>();
    if (filterId == 'all') {
      ticketProvider.setFilterStatus(null);
    } else {
      // Find status ID from loaded statuses
      final statuses = ticketProvider.statuses;
      final matchingStatus = statuses.where(
        (s) => s.name.toLowerCase() == filterId.toLowerCase(),
      );
      if (matchingStatus.isNotEmpty) {
        ticketProvider.setFilterStatus(matchingStatus.first.id);
      }
    }
  }

  void _onSearch(String query) {
    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // Start new debounce timer (500ms delay)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.read<TicketProvider>().setSearchQuery(
          query.trim().isEmpty ? null : query.trim(),
        );
      }
    });
  }

  void _navigateToCreateTicket() {
    context.push('/tickets/create');
  }

  void _navigateToTicketDetail(int ticketId) {
    context.push('/tickets/$ticketId');
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Filter chips
          _buildFilterChips(),

          // Search bar
          _buildSearchBar(),

          // Ticket list
          Expanded(
            child: _buildTicketList(),
          ),
        ],
      ),
      floatingActionButton: isKeyboardVisible ? null : _buildCreateTicketButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
          final isSelected = _selectedFilter == filter['id'];

          return GestureDetector(
            onTap: () => _onFilterSelected(filter['id']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryDark : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primaryDark : AppColors.border,
                  width: 1,
                ),
              ),
              child: Text(
                filter['label'],
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected ? AppColors.white : AppColors.primaryDark,
                  fontWeight: FontWeight.w500,
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
                        hintText: 'Cari ticket',
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
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () {
                      // TODO: Show filter bottom sheet
                    },
                    icon: Icon(
                      Icons.tune_rounded,
                      color: AppColors.primaryDark,
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
              colors: [
                Colors.black.withAlpha(15),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketList() {
    return Consumer<TicketProvider>(
      builder: (context, ticketProvider, child) {
        if (ticketProvider.isTicketsLoading && ticketProvider.tickets.isEmpty) {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(bottom: 80),
            child: const CircularProgressIndicator(),
          );
        }

        if (ticketProvider.ticketsState == TicketState.error &&
            ticketProvider.tickets.isEmpty) {
          return _buildErrorState(ticketProvider.errorMessage ?? 'An error occurred');
        }

        if (ticketProvider.tickets.isEmpty) {
          // Check if there's an active search query or filter
          final hasSearchQuery = ticketProvider.searchQuery != null &&
              ticketProvider.searchQuery!.isNotEmpty;
          final hasFilter = ticketProvider.filterStatusId != null ||
              ticketProvider.filterPriority != null;
          return _buildEmptyState(isSearchResult: hasSearchQuery || hasFilter);
        }

        return RefreshIndicator(
          onRefresh: () => ticketProvider.refreshTickets(),
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: ticketProvider.tickets.length +
                (ticketProvider.hasMoreTickets ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index >= ticketProvider.tickets.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final ticket = ticketProvider.tickets[index];
              return TicketCard(
                ticket: ticket,
                onTap: () => _navigateToTicketDetail(ticket.id),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({bool isSearchResult = false}) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSearchResult ? Icons.search_off_rounded : Icons.confirmation_number_outlined,
            size: 64,
            color: AppColors.textSecondary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            isSearchResult ? 'No data available' : 'No tickets yet',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearchResult
                ? 'Try searching with different keywords'
                : 'Create a new ticket to get started',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
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
            onPressed: () {
              context.read<TicketProvider>().refreshTickets();
            },
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

  Widget _buildCreateTicketButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 70, right: 4),
      child: FloatingActionButton(
        onPressed: _navigateToCreateTicket,
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 4,
        child: const Icon(
          Icons.add,
          size: 28,
        ),
      ),
    );
  }
}
