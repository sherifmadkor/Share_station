// lib/services/analytics_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Track revenue events
  Future<void> trackRevenue({
    required String type, // 'membership', 'admin_fee', 'client_fee', etc.
    required double amount,
    required String userId,
    String? source, // 'game_sale', 'borrow_fee', etc.
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('revenue_history').add({
        'type': type,
        'amount': amount,
        'userId': userId,
        'source': source,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error tracking revenue: $e');
    }
  }

  // Track membership fee payment
  Future<void> trackMembershipFee({
    required String userId,
    required double membershipFee,
    required String tier, // 'member', 'client', 'vip'
  }) async {
    await trackRevenue(
      type: 'membership',
      amount: membershipFee,
      userId: userId,
      source: 'membership_fee',
      metadata: {
        'tier': tier,
        'fee_type': 'membership',
      },
    );
  }

  // Track client fee payment
  Future<void> trackClientFee({
    required String userId,
    required double clientFee,
  }) async {
    await trackRevenue(
      type: 'client_fee',
      amount: clientFee,
      userId: userId,
      source: 'client_upgrade',
      metadata: {
        'tier': 'client',
        'fee_type': 'client_upgrade',
      },
    );
  }

  // Track admin fee from game sales
  Future<void> trackAdminFee({
    required double adminFee,
    required String source, // 'game_sale', 'selling_fee'
    required String sellerId,
    String? gameId,
    String? gameTitle,
  }) async {
    await trackRevenue(
      type: 'admin_fee',
      amount: adminFee,
      userId: sellerId, // The user who triggered the fee
      source: source,
      metadata: {
        'fee_type': 'admin_commission',
        'gameId': gameId,
        'gameTitle': gameTitle,
      },
    );
  }

  // Track game borrowing statistics
  Future<void> trackGameBorrow({
    required String gameId,
    required String gameTitle,
    required String borrowerId,
    required double borrowValue,
    required String platform,
    required String accountType,
  }) async {
    try {
      // Update game statistics
      await _firestore.collection('games').doc(gameId).update({
        'totalBorrows': FieldValue.increment(1),
        'lastBorrowedAt': FieldValue.serverTimestamp(),
        'totalRevenue': FieldValue.increment(borrowValue),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Track individual borrow event
      await _firestore.collection('borrow_analytics').add({
        'gameId': gameId,
        'gameTitle': gameTitle,
        'borrowerId': borrowerId,
        'borrowValue': borrowValue,
        'platform': platform,
        'accountType': accountType,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error tracking game borrow: $e');
    }
  }

  // Track user activity for analytics
  Future<void> trackUserActivity({
    required String userId,
    required String activityType, // 'login', 'borrow', 'contribute', 'redeem_points'
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('user_activity').add({
        'userId': userId,
        'activityType': activityType,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update user's last activity
      await _firestore.collection('users').doc(userId).update({
        'lastActivityDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error tracking user activity: $e');
    }
  }

  // Get revenue statistics for a date range
  Future<Map<String, dynamic>> getRevenueStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final start = startDate ?? DateTime(now.year, now.month, 1); // Default: start of month
      final end = endDate ?? now;

      var query = _firestore
          .collection('revenue_history')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end));

      final snapshot = await query.get();

      double totalRevenue = 0;
      Map<String, double> revenueByType = {};
      Map<String, int> countByType = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        final type = data['type'] ?? 'unknown';

        totalRevenue += amount;
        revenueByType[type] = (revenueByType[type] ?? 0) + amount;
        countByType[type] = (countByType[type] ?? 0) + 1;
      }

      return {
        'totalRevenue': totalRevenue,
        'revenueByType': revenueByType,
        'countByType': countByType,
        'totalTransactions': snapshot.docs.length,
        'periodStart': start,
        'periodEnd': end,
      };
    } catch (e) {
      print('Error getting revenue stats: $e');
      return {
        'totalRevenue': 0.0,
        'revenueByType': <String, double>{},
        'countByType': <String, int>{},
        'totalTransactions': 0,
      };
    }
  }

  // Get top games by borrows
  Future<List<Map<String, dynamic>>> getTopGamesByBorrows({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('borrow_analytics');

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();

      // Group by game and count borrows
      Map<String, Map<String, dynamic>> gameStats = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final gameId = data['gameId'];
        final gameTitle = data['gameTitle'];
        final borrowValue = (data['borrowValue'] ?? 0.0).toDouble();

        if (gameStats.containsKey(gameId)) {
          gameStats[gameId]!['borrowCount'] += 1;
          gameStats[gameId]!['totalRevenue'] += borrowValue;
        } else {
          gameStats[gameId] = {
            'gameId': gameId,
            'gameTitle': gameTitle,
            'borrowCount': 1,
            'totalRevenue': borrowValue,
          };
        }
      }

      // Sort by borrow count and take top games
      final sortedGames = gameStats.values.toList()
        ..sort((a, b) => b['borrowCount'].compareTo(a['borrowCount']));

      return sortedGames.take(limit).toList();
    } catch (e) {
      print('Error getting top games: $e');
      return [];
    }
  }

  // Get user activity statistics
  Future<Map<String, dynamic>> getUserActivityStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final start = startDate ?? DateTime(now.year, now.month, 1);
      final end = endDate ?? now;

      var query = _firestore
          .collection('user_activity')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end));

      final snapshot = await query.get();

      Map<String, int> activityCounts = {};
      Set<String> activeUsers = {};
      Map<String, Set<String>> dailyActiveUsers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final activityType = data['activityType'] ?? 'unknown';
        final userId = data['userId'];
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final dayKey = '${timestamp.year}-${timestamp.month}-${timestamp.day}';

        activityCounts[activityType] = (activityCounts[activityType] ?? 0) + 1;
        activeUsers.add(userId);
        
        dailyActiveUsers[dayKey] ??= <String>{};
        dailyActiveUsers[dayKey]!.add(userId);
      }

      return {
        'totalActivities': snapshot.docs.length,
        'activityCounts': activityCounts,
        'uniqueActiveUsers': activeUsers.length,
        'dailyActiveUsers': dailyActiveUsers.map((k, v) => MapEntry(k, v.length)),
        'averageDailyActiveUsers': dailyActiveUsers.isEmpty 
            ? 0 
            : dailyActiveUsers.values.map((users) => users.length).reduce((a, b) => a + b) / dailyActiveUsers.length,
      };
    } catch (e) {
      print('Error getting user activity stats: $e');
      return {
        'totalActivities': 0,
        'activityCounts': <String, int>{},
        'uniqueActiveUsers': 0,
        'dailyActiveUsers': <String, int>{},
        'averageDailyActiveUsers': 0.0,
      };
    }
  }
}