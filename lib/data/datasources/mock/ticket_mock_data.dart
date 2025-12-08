class MockTicketData {
  // Ticket Statistics
  static const int allTicketsCount = 3;
  static const int openCount = 1;
  static const int inProgressCount = 1;
  static const int resolvedCount = 1;

  // Recent Tickets (mock data)
  static final List<Map<String, dynamic>> recentTickets = [
    {
      'id': 'TIX-202411-001',
      'title': 'Laptop Won\'t Boot',
      'status': 'Open',
      'statusColor': 'blue',
      'timeAgo': '2 hours ago',
      'createdAt': DateTime.now().subtract(const Duration(hours: 2)),
    },
    {
      'id': 'TIX-202411-002',
      'title': 'Network Connection Issues',
      'status': 'In Progress',
      'statusColor': 'amber',
      'timeAgo': 'Yesterday',
      'createdAt': DateTime.now().subtract(const Duration(days: 1)),
    },
    {
      'id': 'TIX-202411-003',
      'title': 'Software Installation Request',
      'status': 'Resolved',
      'statusColor': 'green',
      'timeAgo': '2 days ago',
      'createdAt': DateTime.now().subtract(const Duration(days: 2)),
    },
  ];

  // Greeting based on time
  static String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  // Get formatted date
  static String getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return '${_getDayName(now.weekday)}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  static String _getDayName(int weekday) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return days[weekday - 1];
  }
}
