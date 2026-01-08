class HomeMockData {
  // Ticket Statistics (matching Figma design)
  static const int allTicketsCount = 10;
  static const int openCount = 1;
  static const int inProgressCount = 3;
  static const int resolvedCount = 6;

  // Recent Tickets (mock data with new format)
  static final List<Map<String, dynamic>> recentTickets = [
    {
      'id': 'TIK-2024-001',
      'title': 'Laptop Won\'t Boot',
      'status': 'Open',
      'category': 'Hardware',
      'priority': 'high',
      'description': 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
      'timeAgo': '1 hours ago',
      'createdAt': DateTime(2025, 3, 15),
    },
    {
      'id': 'TIK-2024-002',
      'title': 'Laptop Won\'t Boot',
      'status': 'In Progress',
      'category': 'Hardware',
      'priority': 'medium',
      'description': 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
      'timeAgo': '1 hours ago',
      'createdAt': DateTime(2025, 3, 15),
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
