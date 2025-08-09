// lib/services/balance_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../data/models/user_model.dart';

class BalanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  // Add balance entry to user
  Future<Map<String, dynamic>> addBalanceEntry({
    required String userId,
    required String type,
    required double amount,
    required String description,
    bool expires = true,
    int expiryDays = 90,
  }) async {
    try {
      final entry = {
        'id': _uuid.v4(),
        'type': type,
        'amount': amount,
        'description': description,
        'earnedDate': FieldValue.serverTimestamp(),
        'expiryDate': expires 
          ? Timestamp.fromDate(DateTime.now().add(Duration(days: expiryDays)))
          : null,
        'isExpired': false,
      };

      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(userId);

      // Add entry to balanceEntries array and update the corresponding balance field
      batch.update(userRef, {
        'balanceEntries': FieldValue.arrayUnion([entry]),
        type: FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return {
        'success': true,
        'message': 'Balance entry added successfully',
        'entryId': entry['id'],
      };
    } catch (e) {
      print('Error adding balance entry: $e');
      return {
        'success': false,
        'message': 'Failed to add balance entry: $e',
      };
    }
  }

  // Check and expire balances (run daily)
  Future<Map<String, dynamic>> checkAndExpireBalances() async {
    try {
      int checkedCount = 0;
      int expiredCount = 0;
      double totalExpired = 0;
      int usersAffected = 0;

      final batch = _firestore.batch();
      final now = DateTime.now();

      // Get all active users with balance entries
      final usersSnapshot = await _firestore
        .collection('users')
        .where('status', isEqualTo: 'active')
        .get();

      for (var doc in usersSnapshot.docs) {
        checkedCount++;
        final userData = doc.data();
        final balanceEntries = List<Map<String, dynamic>>.from(
          userData['balanceEntries'] ?? []
        );

        if (balanceEntries.isEmpty) continue;

        double userExpiredAmount = 0;
        Map<String, double> expiredByType = {};
        bool hasExpiredEntries = false;

        // Check each balance entry for expiry
        final updatedEntries = balanceEntries.map((entry) {
          // Skip already expired entries
          if (entry['isExpired'] == true) return entry;

          final expiryDate = entry['expiryDate'] as Timestamp?;
          if (expiryDate != null && expiryDate.toDate().isBefore(now)) {
            // Mark as expired
            entry['isExpired'] = true;
            final amount = (entry['amount'] ?? 0).toDouble();
            final type = entry['type'] ?? 'unknown';
            
            userExpiredAmount += amount;
            expiredByType[type] = (expiredByType[type] ?? 0) + amount;
            expiredCount++;
            hasExpiredEntries = true;
          }
          return entry;
        }).toList();

        if (hasExpiredEntries) {
          totalExpired += userExpiredAmount;
          usersAffected++;

          // Prepare update map
          Map<String, dynamic> updateData = {
            'balanceEntries': updatedEntries,
            'expiredBalance': FieldValue.increment(userExpiredAmount),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // Decrement each balance type that expired
          expiredByType.forEach((type, amount) {
            updateData[type] = FieldValue.increment(-amount);
          });

          batch.update(doc.reference, updateData);
        }
      }

      // Commit all changes
      if (usersAffected > 0) {
        await batch.commit();
      }

      return {
        'success': true,
        'checked': checkedCount,
        'expired': expiredCount,
        'totalExpired': totalExpired,
        'usersAffected': usersAffected,
        'message': 'Balance expiry check completed',
      };
    } catch (e) {
      print('Error checking balance expiry: $e');
      return {
        'success': false,
        'message': 'Failed to check balance expiry: $e',
        'checked': 0,
        'expired': 0,
        'totalExpired': 0,
        'usersAffected': 0,
      };
    }
  }

  // Get balance statistics for admin dashboard
  Future<Map<String, dynamic>> getBalanceStatistics() async {
    try {
      final usersSnapshot = await _firestore
        .collection('users')
        .where('status', isEqualTo: 'active')
        .get();

      int totalUsers = 0;
      int usersWithBalance = 0;
      int usersWithExpiringBalance = 0;
      double totalActiveBalance = 0;
      double totalExpiringBalance = 0;
      double totalExpiredBalance = 0;

      final now = DateTime.now();
      final thirtyDaysFromNow = now.add(Duration(days: 30));

      for (var doc in usersSnapshot.docs) {
        totalUsers++;
        final userData = doc.data();
        final balanceEntries = List<Map<String, dynamic>>.from(
          userData['balanceEntries'] ?? []
        );

        if (balanceEntries.isEmpty) continue;

        double userActiveBalance = 0;
        double userExpiringBalance = 0;
        bool hasActiveBalance = false;
        bool hasExpiringBalance = false;

        for (var entry in balanceEntries) {
          final isExpired = entry['isExpired'] == true;
          final expiryDate = entry['expiryDate'] as Timestamp?;
          final amount = (entry['amount'] ?? 0).toDouble();

          if (isExpired) {
            // Skip expired entries (already counted in expiredBalance field)
            continue;
          }

          if (expiryDate == null || expiryDate.toDate().isAfter(now)) {
            userActiveBalance += amount;
            hasActiveBalance = true;

            // Check if expiring within 30 days
            if (expiryDate != null && 
                expiryDate.toDate().isBefore(thirtyDaysFromNow) &&
                expiryDate.toDate().isAfter(now)) {
              userExpiringBalance += amount;
              hasExpiringBalance = true;
            }
          }
        }

        if (hasActiveBalance) {
          usersWithBalance++;
          totalActiveBalance += userActiveBalance;
        }

        if (hasExpiringBalance) {
          usersWithExpiringBalance++;
          totalExpiringBalance += userExpiringBalance;
        }

        totalExpiredBalance += (userData['expiredBalance'] ?? 0).toDouble();
      }

      return {
        'success': true,
        'totalUsers': totalUsers,
        'usersWithBalance': usersWithBalance,
        'usersWithExpiringBalance': usersWithExpiringBalance,
        'totalActiveBalance': totalActiveBalance,
        'totalExpiringBalance': totalExpiringBalance,
        'totalExpiredBalance': totalExpiredBalance,
        'averageActiveBalance': usersWithBalance > 0 
          ? totalActiveBalance / usersWithBalance 
          : 0,
      };
    } catch (e) {
      print('Error getting balance statistics: $e');
      return {
        'success': false,
        'message': 'Failed to get balance statistics: $e',
      };
    }
  }

  // Get user's balance summary
  Future<Map<String, dynamic>> getUserBalanceSummary(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return {'success': false, 'message': 'User not found'};
      }

      final userData = userDoc.data()!;
      final userModel = UserModel.fromFirestore(userDoc);

      return {
        'success': true,
        'activeBalance': userModel.activeBalance,
        'totalBalance': userModel.totalBalance,
        'expiredBalance': userModel.expiredBalance,
        'amountExpiringWithin30Days': userModel.amountExpiringWithin30Days,
        'hasExpiringBalance': userModel.hasExpiringBalance,
        'balanceBreakdown': userModel.balanceBreakdown,
        'activeEntries': userModel.activeBalanceEntries.length,
        'expiringEntries': userModel.expiringBalanceEntries.length,
        'expiredEntries': userModel.expiredBalanceEntries.length,
      };
    } catch (e) {
      print('Error getting user balance summary: $e');
      return {
        'success': false,
        'message': 'Failed to get user balance summary: $e',
      };
    }
  }

  // Manually expire specific balance entries (admin function)
  Future<Map<String, dynamic>> expireBalanceEntry({
    required String userId,
    required String entryId,
    String reason = 'Manual expiry by admin',
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        return {'success': false, 'message': 'User not found'};
      }

      final userData = userDoc.data()!;
      final balanceEntries = List<Map<String, dynamic>>.from(
        userData['balanceEntries'] ?? []
      );

      // Find and expire the specific entry
      bool entryFound = false;
      double expiredAmount = 0;
      String expiredType = '';

      final updatedEntries = balanceEntries.map((entry) {
        if (entry['id'] == entryId && entry['isExpired'] != true) {
          entry['isExpired'] = true;
          entry['expiredReason'] = reason;
          entry['expiredDate'] = Timestamp.fromDate(DateTime.now());
          expiredAmount = (entry['amount'] ?? 0).toDouble();
          expiredType = entry['type'] ?? '';
          entryFound = true;
        }
        return entry;
      }).toList();

      if (!entryFound) {
        return {'success': false, 'message': 'Balance entry not found or already expired'};
      }

      // Update user document
      await userRef.update({
        'balanceEntries': updatedEntries,
        'expiredBalance': FieldValue.increment(expiredAmount),
        expiredType: FieldValue.increment(-expiredAmount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Balance entry expired successfully',
        'expiredAmount': expiredAmount,
        'expiredType': expiredType,
      };
    } catch (e) {
      print('Error expiring balance entry: $e');
      return {
        'success': false,
        'message': 'Failed to expire balance entry: $e',
      };
    }
  }

  // Get users with expiring balance (for notifications)
  Future<List<Map<String, dynamic>>> getUsersWithExpiringBalance({
    int days = 30,
    int limit = 100,
  }) async {
    try {
      final usersSnapshot = await _firestore
        .collection('users')
        .where('status', isEqualTo: 'active')
        .limit(limit)
        .get();

      List<Map<String, dynamic>> usersWithExpiringBalance = [];
      final now = DateTime.now();
      final targetDate = now.add(Duration(days: days));

      for (var doc in usersSnapshot.docs) {
        final userData = doc.data();
        final balanceEntries = List<Map<String, dynamic>>.from(
          userData['balanceEntries'] ?? []
        );

        double expiringAmount = 0;
        List<Map<String, dynamic>> expiringEntries = [];

        for (var entry in balanceEntries) {
          if (entry['isExpired'] == true) continue;

          final expiryDate = entry['expiryDate'] as Timestamp?;
          if (expiryDate != null && 
              expiryDate.toDate().isBefore(targetDate) &&
              expiryDate.toDate().isAfter(now)) {
            expiringAmount += (entry['amount'] ?? 0).toDouble();
            expiringEntries.add({
              'id': entry['id'],
              'type': entry['type'],
              'amount': entry['amount'],
              'description': entry['description'],
              'expiryDate': expiryDate,
              'daysUntilExpiry': expiryDate.toDate().difference(now).inDays,
            });
          }
        }

        if (expiringAmount > 0) {
          usersWithExpiringBalance.add({
            'userId': doc.id,
            'userName': userData['name'],
            'email': userData['email'],
            'memberId': userData['memberId'],
            'expiringAmount': expiringAmount,
            'expiringEntries': expiringEntries,
          });
        }
      }

      return usersWithExpiringBalance;
    } catch (e) {
      print('Error getting users with expiring balance: $e');
      return [];
    }
  }
}