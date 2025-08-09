// lib/services/points_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'balance_service.dart';

class PointsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BalanceService _balanceService = BalanceService();

  // Award points for spending (1 point per 1 LE)
  Future<Map<String, dynamic>> awardSpendingPoints({
    required String userId,
    required double amountSpent,
    required String description,
  }) async {
    try {
      final points = amountSpent.round(); // 1 point per 1 LE
      
      await _firestore.collection('users').doc(userId).update({
        'points': FieldValue.increment(points),
        'expensePoints': FieldValue.increment(points),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Log points transaction
      await _firestore.collection('points_history').add({
        'userId': userId,
        'points': points,
        'type': 'spending',
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'amountSpent': amountSpent,
      });

      return {
        'success': true,
        'pointsAwarded': points,
        'message': 'Awarded $points points for spending ${amountSpent.toStringAsFixed(0)} LE',
      };
    } catch (e) {
      print('Error awarding spending points: $e');
      return {
        'success': false,
        'message': 'Failed to award spending points: $e',
      };
    }
  }

  // Monthly top 5 players bonus (50 points each)
  Future<Map<String, dynamic>> awardMonthlyTopPlayersBonus() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 1).subtract(Duration(days: 1));

      // Get top 5 users by borrowing activity this month
      final topUsersSnapshot = await _firestore
          .collection('users')
          .where('tier', whereNotIn: ['admin'])
          .where('status', isEqualTo: 'active')
          .orderBy('totalBorrowsCount', descending: true)
          .limit(5)
          .get();

      if (topUsersSnapshot.docs.isEmpty) {
        return {
          'success': true,
          'message': 'No active users found for monthly bonus',
          'usersAwarded': 0,
        };
      }

      final batch = _firestore.batch();
      final awardedUsers = <Map<String, dynamic>>[];

      for (int i = 0; i < topUsersSnapshot.docs.length; i++) {
        final doc = topUsersSnapshot.docs[i];
        final userData = doc.data();
        final userName = userData['name'] ?? 'Unknown User';
        final totalBorrows = userData['totalBorrowsCount'] ?? 0;

        // Award 50 points
        batch.update(doc.reference, {
          'points': FieldValue.increment(50),
          'bonusPoints': FieldValue.increment(50),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Log bonus
        batch.set(_firestore.collection('points_history').doc(), {
          'userId': doc.id,
          'points': 50,
          'type': 'monthly_bonus',
          'description': 'Top ${i + 1} Player Monthly Bonus - ${now.month}/${now.year}',
          'timestamp': FieldValue.serverTimestamp(),
          'month': now.month,
          'year': now.year,
          'rank': i + 1,
        });

        awardedUsers.add({
          'userId': doc.id,
          'userName': userName,
          'rank': i + 1,
          'totalBorrows': totalBorrows,
        });
      }
      
      await batch.commit();

      return {
        'success': true,
        'message': 'Monthly bonus awarded to ${topUsersSnapshot.docs.length} users',
        'usersAwarded': topUsersSnapshot.docs.length,
        'awardedUsers': awardedUsers,
      };
    } catch (e) {
      print('Error awarding monthly bonus: $e');
      return {
        'success': false,
        'message': 'Failed to award monthly bonus: $e',
      };
    }
  }

  // Redeem points for balance (25 points = 1 LE)
  Future<Map<String, dynamic>> redeemPoints({
    required String userId,
    required int pointsToRedeem,
  }) async {
    try {
      // Validate minimum 25 points and multiples of 25
      if (pointsToRedeem < 25) {
        return {
          'success': false,
          'message': 'Minimum 25 points required for redemption',
        };
      }

      if (pointsToRedeem % 25 != 0) {
        return {
          'success': false,
          'message': 'Points must be redeemed in multiples of 25',
        };
      }
      
      // Max 2500 points (100 LE) per transaction
      if (pointsToRedeem > 2500) {
        return {
          'success': false,
          'message': 'Maximum 2500 points (100 LE) per transaction',
        };
      }
      
      // Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {
          'success': false,
          'message': 'User not found',
        };
      }

      final userData = userDoc.data()!;
      final currentPoints = (userData['points'] ?? 0).toInt();
      
      if (currentPoints < pointsToRedeem) {
        return {
          'success': false,
          'message': 'Insufficient points. You have $currentPoints points, need $pointsToRedeem',
        };
      }
      
      // Calculate LE credit (25 points = 1 LE)
      final leCredit = pointsToRedeem / 25.0;
      
      final batch = _firestore.batch();

      // Update user points
      batch.update(userDoc.reference, {
        'points': FieldValue.increment(-pointsToRedeem),
        'convertedPoints': FieldValue.increment(pointsToRedeem),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log points redemption
      batch.set(_firestore.collection('points_history').doc(), {
        'userId': userId,
        'points': -pointsToRedeem,
        'type': 'redemption',
        'description': 'Points redeemed for $leCredit LE cash-in',
        'timestamp': FieldValue.serverTimestamp(),
        'leCredit': leCredit,
      });

      await batch.commit();
      
      // Add balance entry using balance service
      await _balanceService.addBalanceEntry(
        userId: userId,
        type: 'cashIn',
        amount: leCredit,
        description: 'Points redemption: $pointsToRedeem points',
        expires: false, // Cash-in never expires
      );
      
      return {
        'success': true,
        'message': 'Successfully redeemed $pointsToRedeem points for ${leCredit.toStringAsFixed(0)} LE',
        'pointsRedeemed': pointsToRedeem,
        'leCredited': leCredit,
        'remainingPoints': currentPoints - pointsToRedeem,
      };
    } catch (e) {
      print('Error redeeming points: $e');
      return {
        'success': false,
        'message': 'Failed to redeem points: $e',
      };
    }
  }

  // Get user's points history
  Future<List<Map<String, dynamic>>> getUserPointsHistory(String userId) async {
    try {
      final query = await _firestore
          .collection('points_history')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting points history: $e');
      return [];
    }
  }

  // Get points statistics for admin dashboard
  Future<Map<String, dynamic>> getPointsStatistics() async {
    try {
      // Get total points in circulation
      final usersSnapshot = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'active')
          .get();

      int totalPointsInCirculation = 0;
      int totalConvertedPoints = 0;
      int totalExpensePoints = 0;
      int totalBonusPoints = 0;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        totalPointsInCirculation += ((data['points'] ?? 0) as num).toInt();
        totalConvertedPoints += ((data['convertedPoints'] ?? 0) as num).toInt();
        totalExpensePoints += ((data['expensePoints'] ?? 0) as num).toInt();
        totalBonusPoints += ((data['bonusPoints'] ?? 0) as num).toInt();
      }

      // Get recent points activity
      final recentActivityQuery = await _firestore
          .collection('points_history')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final recentActivity = recentActivityQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      return {
        'totalPointsInCirculation': totalPointsInCirculation,
        'totalConvertedPoints': totalConvertedPoints,
        'totalExpensePoints': totalExpensePoints,
        'totalBonusPoints': totalBonusPoints,
        'recentActivity': recentActivity,
        'totalUsersWithPoints': usersSnapshot.docs.where((doc) => 
          (doc.data()['points'] ?? 0) > 0
        ).length,
      };
    } catch (e) {
      print('Error getting points statistics: $e');
      return {
        'totalPointsInCirculation': 0,
        'totalConvertedPoints': 0,
        'totalExpensePoints': 0,
        'totalBonusPoints': 0,
        'recentActivity': [],
        'totalUsersWithPoints': 0,
      };
    }
  }

  // Get redemption options for UI
  List<Map<String, dynamic>> getRedemptionOptions() {
    return [
      {
        'points': 25,
        'leValue': 1,
        'description': '25 Points → 1 LE',
      },
      {
        'points': 50,
        'leValue': 2,
        'description': '50 Points → 2 LE',
      },
      {
        'points': 125,
        'leValue': 5,
        'description': '125 Points → 5 LE',
      },
      {
        'points': 250,
        'leValue': 10,
        'description': '250 Points → 10 LE',
      },
      {
        'points': 500,
        'leValue': 20,
        'description': '500 Points → 20 LE',
      },
      {
        'points': 1250,
        'leValue': 50,
        'description': '1250 Points → 50 LE',
      },
      {
        'points': 2500,
        'leValue': 100,
        'description': '2500 Points → 100 LE (MAX)',
      },
    ];
  }

  // Check if user is eligible for monthly bonus
  Future<bool> isUserEligibleForMonthlyBonus(String userId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Check if user already received bonus this month
      final bonusQuery = await _firestore
          .collection('points_history')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'monthly_bonus')
          .where('month', isEqualTo: now.month)
          .where('year', isEqualTo: now.year)
          .limit(1)
          .get();

      return bonusQuery.docs.isEmpty;
    } catch (e) {
      print('Error checking monthly bonus eligibility: $e');
      return false;
    }
  }

  // Award custom points (admin function)
  Future<Map<String, dynamic>> awardCustomPoints({
    required String userId,
    required int points,
    required String reason,
    required String adminId,
  }) async {
    try {
      if (points <= 0) {
        return {
          'success': false,
          'message': 'Points must be greater than 0',
        };
      }

      final batch = _firestore.batch();

      // Update user points
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'points': FieldValue.increment(points),
        'bonusPoints': FieldValue.increment(points),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log custom points award
      batch.set(_firestore.collection('points_history').doc(), {
        'userId': userId,
        'points': points,
        'type': 'admin_award',
        'description': 'Admin award: $reason',
        'timestamp': FieldValue.serverTimestamp(),
        'adminId': adminId,
        'reason': reason,
      });

      await batch.commit();

      return {
        'success': true,
        'message': 'Successfully awarded $points points',
        'pointsAwarded': points,
      };
    } catch (e) {
      print('Error awarding custom points: $e');
      return {
        'success': false,
        'message': 'Failed to award custom points: $e',
      };
    }
  }
}