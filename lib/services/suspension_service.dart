// lib/services/suspension_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class SuspensionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check all users for suspension based on contribution inactivity
  Future<Map<String, dynamic>> checkAndApplySuspensions() async {
    try {
      int suspendedCount = 0;
      int checkedCount = 0;

      // Get all active members (exclude VIP and Admin)
      final usersQuery = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'active')
          .where('tier', whereIn: ['member', 'client', 'user'])
          .get();

      final batch = _firestore.batch();
      final now = DateTime.now();

      for (var doc in usersQuery.docs) {
        checkedCount++;
        final userData = doc.data();

        // Get last CONTRIBUTION date (not general activity)
        DateTime? lastContribution;
        if (userData['lastContributionDate'] != null) {
          lastContribution = (userData['lastContributionDate'] as Timestamp).toDate();
        } else if (userData['joinDate'] != null && userData['totalShares'] == 0) {
          // If user never contributed, use join date
          lastContribution = (userData['joinDate'] as Timestamp).toDate();
        } else {
          continue; // Skip if no dates available
        }

        final daysSinceContribution = now.difference(lastContribution).inDays;

        // Apply suspension if 180 days (6 months) without contributions
        if (daysSinceContribution >= 180) {
          await _applySuspensionBatch(batch, doc.id, userData);
          suspendedCount++;
        }
      }

      // Commit all suspensions
      if (suspendedCount > 0) {
        await batch.commit();
      }

      return {
        'success': true,
        'message': 'Suspension check completed',
        'checked': checkedCount,
        'suspended': suspendedCount,
        'timestamp': FieldValue.serverTimestamp(),
      };
    } catch (e) {
      print('Error checking suspensions: $e');
      return {
        'success': false,
        'message': 'Failed to check suspensions: $e',
      };
    }
  }

  // Apply suspension to a single user
  Future<void> _applySuspensionBatch(
      WriteBatch batch,
      String userId,
      Map<String, dynamic> userData
      ) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      // Store pre-suspension data for potential reactivation
      final preSuspensionData = {
        'stationLimit': userData['stationLimit'] ?? 0,
        'remainingStationLimit': userData['remainingStationLimit'] ?? 0,
        'points': userData['points'] ?? 0,
        'balanceEntries': userData['balanceEntries'] ?? [],
        'borrowLimit': userData['borrowLimit'] ?? 1,
        'gameShares': userData['gameShares'] ?? 0,
        'fundShares': userData['fundShares'] ?? 0,
        'totalShares': userData['totalShares'] ?? 0,
        'borrowValue': userData['borrowValue'] ?? 0,
        'sellValue': userData['sellValue'] ?? 0,
        'refunds': userData['refunds'] ?? 0,
        'referralEarnings': userData['referralEarnings'] ?? 0,
      };

      // Calculate expired balance (all non-cash-in balances)
      double expiredAmount = 0;
      expiredAmount += (userData['borrowValue'] ?? 0).toDouble();
      expiredAmount += (userData['sellValue'] ?? 0).toDouble();
      expiredAmount += (userData['refunds'] ?? 0).toDouble();
      expiredAmount += (userData['referralEarnings'] ?? 0).toDouble();

      // Apply suspension: zero out non-cash-in balance, points, station limit, etc.
      batch.update(userRef, {
        'status': 'suspended',
        'suspensionDate': FieldValue.serverTimestamp(),
        'suspensionReason': 'No contributions for 180 days',
        'preSuspensionData': preSuspensionData,
        // Zero out metrics as per BRD
        'stationLimit': 0,
        'remainingStationLimit': 0,
        'points': 0,
        'borrowLimit': 0,
        'currentBorrows': 0,
        'freeborrowings': 0,
        // Clear non-cash-in balance entries
        'balanceEntries': [],
        'borrowValue': 0,
        'sellValue': 0,
        'refunds': 0,
        'referralEarnings': 0,
        'expiredBalance': FieldValue.increment(expiredAmount),
        // Reset share counts to 0 during suspension
        'gameShares': 0,
        'fundShares': 0,
        'totalShares': 0,
      });

      // Mark user's contributed games as suspended
      final gamesQuery = await _firestore
          .collection('games')
          .get();

      for (var gameDoc in gamesQuery.docs) {
        final gameData = gameDoc.data();
        if (gameData['accounts'] != null) {
          final accounts = gameData['accounts'] as List<dynamic>;
          bool hasUserAccount = false;

          for (var account in accounts) {
            if (account['contributorId'] == userId) {
              hasUserAccount = true;
              break;
            }
          }

          if (hasUserAccount) {
            batch.update(gameDoc.reference, {
              'hasSuspendedContributor': true,
              'suspendedContributorIds': FieldValue.arrayUnion([userId]),
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // Log suspension event
      final suspensionLogRef = _firestore.collection('suspension_logs').doc();
      batch.set(suspensionLogRef, {
        'userId': userId,
        'memberId': userData['memberId'],
        'userName': userData['name'],
        'suspensionDate': FieldValue.serverTimestamp(),
        'lastContributionDate': userData['lastContributionDate'],
        'expiredBalance': expiredAmount,
        'preSuspensionData': preSuspensionData,
      });
    } catch (e) {
      print('Error applying suspension for user $userId: $e');
    }
  }

  // Reactivate a suspended account (called when user makes new contribution)
  Future<Map<String, dynamic>> reactivateAccount(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        return {'success': false, 'message': 'User not found'};
      }

      final userData = userDoc.data()!;

      if (userData['status'] != 'suspended') {
        return {'success': false, 'message': 'User is not suspended'};
      }

      final preSuspensionData = userData['preSuspensionData'] as Map<String, dynamic>? ?? {};

      // Restore pre-suspension values (except balance and points as per BRD)
      await userRef.update({
        'status': 'active',
        'suspensionDate': null,
        'suspensionReason': null,
        'stationLimit': preSuspensionData['stationLimit'] ?? 0,
        'remainingStationLimit': preSuspensionData['remainingStationLimit'] ?? 0,
        'borrowLimit': preSuspensionData['borrowLimit'] ?? 1,
        'gameShares': preSuspensionData['gameShares'] ?? 0,
        'fundShares': preSuspensionData['fundShares'] ?? 0,
        'totalShares': preSuspensionData['totalShares'] ?? 0,
        'lastContributionDate': FieldValue.serverTimestamp(), // Update contribution date
        'lastActivityDate': FieldValue.serverTimestamp(),
        'preSuspensionData': null,
        'reactivationDate': FieldValue.serverTimestamp(),
      });

      // Reactivate user's games
      final gamesQuery = await _firestore
          .collection('games')
          .where('suspendedContributorIds', arrayContains: userId)
          .get();

      final batch = _firestore.batch();
      for (var doc in gamesQuery.docs) {
        batch.update(doc.reference, {
          'suspendedContributorIds': FieldValue.arrayRemove([userId]),
        });

        // Check if any other contributors are suspended
        final updatedSuspendedIds = (doc.data()['suspendedContributorIds'] as List<dynamic>? ?? [])
            .where((id) => id != userId)
            .toList();

        if (updatedSuspendedIds.isEmpty) {
          batch.update(doc.reference, {
            'hasSuspendedContributor': false,
          });
        }
      }

      await batch.commit();

      // Log reactivation event
      await _firestore.collection('reactivation_logs').add({
        'userId': userId,
        'memberId': userData['memberId'],
        'userName': userData['name'],
        'reactivationDate': FieldValue.serverTimestamp(),
        'suspensionDate': userData['suspensionDate'],
      });

      return {
        'success': true,
        'message': 'Account reactivated successfully',
      };
    } catch (e) {
      print('Error reactivating account: $e');
      return {
        'success': false,
        'message': 'Failed to reactivate account: $e',
      };
    }
  }

  // Get suspension status for a user based on contributions
  Future<Map<String, dynamic>> getSuspensionStatus(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return {
          'status': 'unknown',
          'message': 'User not found',
        };
      }

      final userData = userDoc.data()!;
      final status = userData['status'] ?? 'active';

      if (status == 'suspended') {
        return {
          'status': 'suspended',
          'suspensionDate': userData['suspensionDate'],
          'suspensionReason': userData['suspensionReason'],
          'canReactivate': true,
          'message': 'Account suspended due to inactivity. Make a contribution to reactivate.',
        };
      }

      // Check if at risk of suspension
      final tier = userData['tier'] ?? 'member';
      if (tier == 'vip' || tier == 'admin') {
        return {
          'status': 'active',
          'atRisk': false,
          'message': 'VIP and Admin accounts cannot be suspended',
        };
      }

      // Check last contribution date
      DateTime? lastContribution;
      if (userData['lastContributionDate'] != null) {
        lastContribution = (userData['lastContributionDate'] as Timestamp).toDate();
      } else if (userData['joinDate'] != null && (userData['totalShares'] ?? 0) == 0) {
        // If user never contributed, use join date
        lastContribution = (userData['joinDate'] as Timestamp).toDate();
      }

      if (lastContribution == null) {
        return {
          'status': 'active',
          'atRisk': false,
          'message': 'Unable to determine contribution history',
        };
      }

      final daysSinceContribution = DateTime.now().difference(lastContribution).inDays;
      final daysUntilSuspension = 180 - daysSinceContribution;

      String riskLevel;
      if (daysUntilSuspension > 60) {
        riskLevel = 'low';
      } else if (daysUntilSuspension > 30) {
        riskLevel = 'medium';
      } else if (daysUntilSuspension > 0) {
        riskLevel = 'high';
      } else {
        riskLevel = 'critical';
      }

      return {
        'status': 'active',
        'atRisk': daysUntilSuspension <= 60,
        'riskLevel': riskLevel,
        'daysUntilSuspension': daysUntilSuspension > 0 ? daysUntilSuspension : 0,
        'daysSinceContribution': daysSinceContribution,
        'lastContribution': lastContribution.toIso8601String(),
        'message': daysUntilSuspension <= 30
            ? 'Warning: Account will be suspended in $daysUntilSuspension days without contribution'
            : 'Account in good standing',
      };
    } catch (e) {
      print('Error getting suspension status: $e');
      return {
        'status': 'error',
        'message': 'Failed to get suspension status: $e',
      };
    }
  }

  // Update last contribution date (call this when user makes a contribution)
  Future<void> updateLastContribution(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastContributionDate': FieldValue.serverTimestamp(),
        'lastActivityDate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last contribution: $e');
    }
  }

  // Update last login (for tracking but not suspension)
  Future<void> updateLastLogin(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastLoginDate': FieldValue.serverTimestamp(),
        'lastActivityDate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last login: $e');
    }
  }

  // Check VIP promotion eligibility and auto-promote
  Future<Map<String, dynamic>> checkAndPromoteToVIP(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        return {'success': false, 'message': 'User not found'};
      }

      final userData = userDoc.data()!;
      final currentTier = userData['tier'] ?? 'member';

      // Skip if already VIP or Admin
      if (currentTier == 'vip' || currentTier == 'admin') {
        return {
          'success': false,
          'message': 'User is already VIP or Admin',
        };
      }

      final totalShares = userData['totalShares'] ?? 0;
      final fundShares = userData['fundShares'] ?? 0;

      // Check VIP requirements: 15 total shares + 5 fund shares
      if (totalShares >= 15 && fundShares >= 5) {
        // Promote to VIP
        await userRef.update({
          'tier': 'vip',
          'vipPromotionDate': FieldValue.serverTimestamp(),
          'borrowLimit': 5, // VIP gets 5 simultaneous borrows
          'canWithdrawBalance': true, // VIP can withdraw balance
          'withdrawalFeePercentage': 20, // 20% fee for VIP withdrawals
        });

        // Log promotion
        await _firestore.collection('vip_promotions').add({
          'userId': userId,
          'memberId': userData['memberId'],
          'userName': userData['name'],
          'promotionDate': FieldValue.serverTimestamp(),
          'totalSharesAtPromotion': totalShares,
          'fundSharesAtPromotion': fundShares,
        });

        return {
          'success': true,
          'message': 'User promoted to VIP successfully',
          'newTier': 'vip',
        };
      }

      return {
        'success': false,
        'message': 'User does not meet VIP requirements',
        'currentShares': totalShares,
        'currentFundShares': fundShares,
        'requiredShares': 15,
        'requiredFundShares': 5,
      };
    } catch (e) {
      print('Error checking VIP promotion: $e');
      return {
        'success': false,
        'message': 'Failed to check VIP promotion: $e',
      };
    }
  }

  // Batch check for VIP promotions (can be called periodically)
  Future<Map<String, dynamic>> batchCheckVIPPromotions() async {
    try {
      int promotedCount = 0;
      int checkedCount = 0;

      // Get all non-VIP, non-Admin active members
      final usersQuery = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'active')
          .where('tier', whereIn: ['member', 'client', 'user'])
          .get();

      for (var doc in usersQuery.docs) {
        checkedCount++;
        final result = await checkAndPromoteToVIP(doc.id);
        if (result['success'] == true) {
          promotedCount++;
        }
      }

      return {
        'success': true,
        'message': 'VIP promotion check completed',
        'checked': checkedCount,
        'promoted': promotedCount,
      };
    } catch (e) {
      print('Error in batch VIP check: $e');
      return {
        'success': false,
        'message': 'Failed batch VIP check: $e',
      };
    }
  }
}