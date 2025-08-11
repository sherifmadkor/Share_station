// lib/services/balance_service.dart
// FIXED VERSION - Properly integrates referral earnings into balance

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../data/models/user_model.dart';

class BalanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  // Initialize balance entries for users that don't have them
  Future<void> initializeUserBalanceEntries(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;

      // Check if balanceEntries already exists
      if (userData['balanceEntries'] != null) return;

      List<Map<String, dynamic>> balanceEntries = [];

      // Create entries for existing balance fields
      if ((userData['borrowValue'] ?? 0) > 0) {
        balanceEntries.add({
          'id': _uuid.v4(),
          'type': 'borrowValue',
          'amount': userData['borrowValue'],
          'description': 'Borrow value balance',
          'earnedDate': Timestamp.now(),
          'expiryDate': Timestamp.fromDate(DateTime.now().add(Duration(days: 90))),
          'isExpired': false,
        });
      }

      if ((userData['sellValue'] ?? 0) > 0) {
        balanceEntries.add({
          'id': _uuid.v4(),
          'type': 'sellValue',
          'amount': userData['sellValue'],
          'description': 'Sell value balance',
          'earnedDate': Timestamp.now(),
          'expiryDate': Timestamp.fromDate(DateTime.now().add(Duration(days: 90))),
          'isExpired': false,
        });
      }

      if ((userData['refunds'] ?? 0) > 0) {
        balanceEntries.add({
          'id': _uuid.v4(),
          'type': 'refunds',
          'amount': userData['refunds'],
          'description': 'Refunds balance',
          'earnedDate': Timestamp.now(),
          'expiryDate': Timestamp.fromDate(DateTime.now().add(Duration(days: 90))),
          'isExpired': false,
        });
      }

      // IMPORTANT: Add referral earnings if exists
      if ((userData['referralEarnings'] ?? 0) > 0) {
        balanceEntries.add({
          'id': _uuid.v4(),
          'type': 'referralEarnings',
          'amount': userData['referralEarnings'],
          'description': 'Referral commission earnings',
          'earnedDate': Timestamp.now(),
          'expiryDate': Timestamp.fromDate(DateTime.now().add(Duration(days: 90))),
          'isExpired': false,
        });
      }

      if ((userData['cashIn'] ?? 0) > 0) {
        balanceEntries.add({
          'id': _uuid.v4(),
          'type': 'cashIn',
          'amount': userData['cashIn'],
          'description': 'Cash in balance',
          'earnedDate': Timestamp.now(),
          'expiryDate': null, // Cash in never expires
          'isExpired': false,
        });
      }

      // Update user document with balance entries
      await _firestore.collection('users').doc(userId).update({
        'balanceEntries': balanceEntries,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Initialized balance entries for user $userId with ${balanceEntries.length} entries');
    } catch (e) {
      print('Error initializing balance entries: $e');
    }
  }

  // Add balance entry to user (FIXED to properly update balanceEntries)
  Future<Map<String, dynamic>> addBalanceEntry({
    required String userId,
    required String type,
    required double amount,
    required String description,
    bool expires = true,
    int expiryDays = 90,
  }) async {
    try {
      // First ensure user has balanceEntries array
      await initializeUserBalanceEntries(userId);

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

      print('Added balance entry for user $userId: $type = $amount');

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

  // Calculate total balance from all sources (FIXED VERSION)
  Future<double> calculateUserTotalBalance(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return 0.0;

      final userData = userDoc.data()!;

      // Method 1: Calculate from balanceEntries if exists
      if (userData['balanceEntries'] != null) {
        double total = 0;
        final entries = List<Map<String, dynamic>>.from(userData['balanceEntries']);

        for (var entry in entries) {
          if (entry['isExpired'] != true) {
            final amount = entry['amount'];
            if (amount != null) {
              total += amount is int ? amount.toDouble() : amount;
            }
          }
        }
        return total;
      }

      // Method 2: Fallback to individual fields if no balanceEntries
      double total = 0;

      // Add all balance components including referralEarnings
      total += (userData['borrowValue'] ?? 0).toDouble();
      total += (userData['sellValue'] ?? 0).toDouble();
      total += (userData['refunds'] ?? 0).toDouble();
      total += (userData['referralEarnings'] ?? 0).toDouble(); // IMPORTANT: Include referral earnings
      total += (userData['cashIn'] ?? 0).toDouble();

      // Subtract used and expired balances
      total -= (userData['usedBalance'] ?? 0).toDouble();
      total -= (userData['expiredBalance'] ?? 0).toDouble();

      return total;
    } catch (e) {
      print('Error calculating total balance: $e');
      return 0.0;
    }
  }

  // Fix missing referral earnings in balance entries
  Future<Map<String, dynamic>> fixMissingReferralEarningsInBalance() async {
    try {
      print('=== FIXING MISSING REFERRAL EARNINGS IN BALANCE ===');

      final usersSnapshot = await _firestore
          .collection('users')
          .where('referralEarnings', isGreaterThan: 0)
          .get();

      int fixedCount = 0;
      double totalFixed = 0;

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final referralEarnings = (userData['referralEarnings'] ?? 0).toDouble();

        if (referralEarnings <= 0) continue;

        // Initialize balance entries if missing
        if (userData['balanceEntries'] == null) {
          await initializeUserBalanceEntries(userDoc.id);
          fixedCount++;
          totalFixed += referralEarnings;
          continue;
        }

        // Check if referral earnings entry exists
        final balanceEntries = List<Map<String, dynamic>>.from(userData['balanceEntries']);
        bool hasReferralEntry = balanceEntries.any((entry) =>
        entry['type'] == 'referralEarnings' &&
            entry['isExpired'] != true
        );

        if (!hasReferralEntry && referralEarnings > 0) {
          print('Adding missing referral earnings for user ${userDoc.id}: $referralEarnings LE');

          // Add the missing referral earnings entry
          final entry = {
            'id': _uuid.v4(),
            'type': 'referralEarnings',
            'amount': referralEarnings,
            'description': 'Referral commission earnings (fixed)',
            'earnedDate': Timestamp.now(),
            'expiryDate': Timestamp.fromDate(DateTime.now().add(Duration(days: 90))),
            'isExpired': false,
          };

          await userDoc.reference.update({
            'balanceEntries': FieldValue.arrayUnion([entry]),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          fixedCount++;
          totalFixed += referralEarnings;
        }
      }

      print('Fixed $fixedCount users with total $totalFixed LE in referral earnings');

      return {
        'success': true,
        'fixedCount': fixedCount,
        'totalFixed': totalFixed,
        'message': 'Fixed $fixedCount users with missing referral earnings totaling $totalFixed LE',
      };
    } catch (e) {
      print('Error fixing referral earnings: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Initialize all users without balanceEntries
  Future<Map<String, dynamic>> initializeAllUsersBalanceEntries() async {
    try {
      print('=== INITIALIZING BALANCE ENTRIES FOR ALL USERS ===');

      final usersSnapshot = await _firestore.collection('users').get();
      int initialized = 0;

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();

        // Skip if already has balanceEntries
        if (userData['balanceEntries'] != null) continue;

        print('Initializing balance entries for user ${userDoc.id}');
        await initializeUserBalanceEntries(userDoc.id);
        initialized++;
      }

      print('Initialized balance entries for $initialized users');

      return {
        'success': true,
        'initialized': initialized,
        'message': 'Initialized balance entries for $initialized users',
      };
    } catch (e) {
      print('Error initializing all users: $e');
      return {
        'success': false,
        'message': 'Error: $e',
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

  // Get user's balance summary (FIXED to include referralEarnings)
  Future<Map<String, dynamic>> getUserBalanceSummary(String userId) async {
    try {
      // First ensure user has balance entries
      await initializeUserBalanceEntries(userId);

      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return {'success': false, 'message': 'User not found'};
      }

      final userData = userDoc.data()!;

      // Calculate total balance properly
      final totalBalance = await calculateUserTotalBalance(userId);

      // Get balance breakdown
      final balanceBreakdown = {
        'borrowValue': (userData['borrowValue'] ?? 0).toDouble(),
        'sellValue': (userData['sellValue'] ?? 0).toDouble(),
        'refunds': (userData['refunds'] ?? 0).toDouble(),
        'referralEarnings': (userData['referralEarnings'] ?? 0).toDouble(),
        'cashIn': (userData['cashIn'] ?? 0).toDouble(),
      };

      return {
        'success': true,
        'totalBalance': totalBalance,
        'activeBalance': totalBalance,
        'expiredBalance': (userData['expiredBalance'] ?? 0).toDouble(),
        'balanceBreakdown': balanceBreakdown,
        'hasReferralEarnings': balanceBreakdown['referralEarnings']! > 0,
      };
    } catch (e) {
      print('Error getting user balance summary: $e');
      return {
        'success': false,
        'message': 'Failed to get user balance summary: $e',
      };
    }
  }
}