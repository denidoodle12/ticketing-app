import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/storage_keys.dart';

class RecentSearchService {
  static const int _maxRecentSearches = 10;

  /// Get list of recent searches
  Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(StorageKeys.recentSearches);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<String>();
    } catch (e) {
      return [];
    }
  }

  /// Add a new search query to recent searches
  /// - Removes duplicates (case-insensitive)
  /// - Limits to 10 items
  /// - Most recent appears first
  Future<void> addRecentSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final searches = await getRecentSearches();

    // Remove existing duplicate (case-insensitive)
    searches.removeWhere(
      (s) => s.toLowerCase() == trimmedQuery.toLowerCase(),
    );

    // Add to beginning
    searches.insert(0, trimmedQuery);

    // Limit to max items
    final limited = searches.take(_maxRecentSearches).toList();

    // Save
    await prefs.setString(StorageKeys.recentSearches, jsonEncode(limited));
  }

  /// Remove a specific search query from recent searches
  Future<void> removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final searches = await getRecentSearches();

    searches.removeWhere(
      (s) => s.toLowerCase() == query.toLowerCase(),
    );

    await prefs.setString(StorageKeys.recentSearches, jsonEncode(searches));
  }

  /// Clear all recent searches
  Future<void> clearAllRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.recentSearches);
  }
}
