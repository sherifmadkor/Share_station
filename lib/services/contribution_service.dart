// lib/services/contribution_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/contribution_model.dart';
import '../data/models/game_model.dart';
import '../data/models/user_model.dart';

class ContributionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit a new game contribution
  Future<Map<String, dynamic>> submitGameContribution({
    required String contributorId,
    required String contributorName,
    required String contributorMemberId,
    required String gameTitle,
    required String platform,
    required String accountType,
    required double gameValue,
    String? email,
    String? password,
    String? region,
    String? edition,
    String? description,
    List<String>? includedTitles,
  }) async {
    try {
      // Create contribution document
      final contributionData = {
        'type': 'game',
        'status': 'pending',
        'contributorId': contributorId,
        'contributorName': contributorName,
        'contributorMemberId': contributorMemberId,
        'gameTitle': gameTitle,
        'platform': platform,
        'accountType': accountType,
        'gameValue': gameValue,
        'email': email ?? '',
        'password': password ?? '',
        'region': region ?? 'Global',
        'edition': edition ?? 'Standard',
        'description': description ?? '',
        'includedTitles': includedTitles ?? [gameTitle],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add to contributions collection
      await _firestore.collection('contributions').add(contributionData);

      return {
        'success': true,
        'message': 'Game contribution submitted successfully',
      };
    } catch (e) {
      print('Error submitting game contribution: $e');
      return {
        'success': false,
        'message': 'Failed to submit contribution: $e',
      };
    }
  }

  // Submit a new fund contribution
  Future<Map<String, dynamic>> submitFundContribution({
    required String contributorId,
    required String contributorName,
    required String contributorMemberId,
    required double amount,
    required String targetGameTitle,
    required String paymentMethod,
    String? receiptUrl,
  }) async {
    try {
      // Create contribution document
      final contributionData = {
        'type': 'fund',
        'status': 'pending',
        'contributorId': contributorId,
        'contributorName': contributorName,
        'contributorMemberId': contributorMemberId,
        'fundAmount': amount,
        'targetGameTitle': targetGameTitle,
        'paymentMethod': paymentMethod,
        'receiptUrl': receiptUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add to contributions collection
      await _firestore.collection('contributions').add(contributionData);

      return {
        'success': true,
        'message': 'Fund contribution submitted successfully',
      };
    } catch (e) {
      print('Error submitting fund contribution: $e');
      return {
        'success': false,
        'message': 'Failed to submit contribution: $e',
      };
    }
  }

  // Approve a contribution and update user metrics
  Future<Map<String, dynamic>> approveContribution({
    required String contributionId,
    required String approvedBy,
  }) async {
    try {
      // Start a batch write for atomic updates
      final batch = _firestore.batch();

      // Get contribution document
      final contributionDoc = await _firestore
          .collection('contributions')
          .doc(contributionId)
          .get();

      if (!contributionDoc.exists) {
        return {
          'success': false,
          'message': 'Contribution not found',
        };
      }

      final contribution = ContributionModel.fromFirestore(contributionDoc);

      // Check if already processed
      if (contribution.status != ContributionStatus.pending) {
        return {
          'success': false,
          'message': 'Contribution already processed',
        };
      }

      // Update contribution status
      batch.update(contributionDoc.reference, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': approvedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Calculate user metrics impact
      final metricsImpact = contribution.calculateUserMetricsImpact();

      // Update user metrics
      final userRef = _firestore.collection('users').doc(contribution.contributorId);

      if (contribution.type == ContributionType.game) {
        // Update user metrics for game contribution
        batch.update(userRef, {
          'stationLimit': FieldValue.increment(metricsImpact['stationLimit']),
          'remainingStationLimit': FieldValue.increment(metricsImpact['stationLimit']),
          'balance': FieldValue.increment(metricsImpact['balance']),
          'borrowValue': FieldValue.increment(metricsImpact['balance']), // 70% goes to borrow value
          'gameShares': FieldValue.increment(metricsImpact['gameShares']),
          'totalShares': FieldValue.increment(metricsImpact['totalShares']),
          'lastActivityDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Add balance expiry entry (90 days from now)
        final expiryDate = DateTime.now().add(Duration(days: 90));
        batch.update(userRef, {
          'balanceExpiry.game_${contributionId}': Timestamp.fromDate(expiryDate),
        });

        // Create the game in the games collection
        if (contribution.gameValue != null) {
          final gameData = {
            'title': contribution.gameTitle,
            // Corrected Code
            'includedTitles': contribution.includedTitles ?? (contribution.gameTitle != null ? [contribution.gameTitle!] : []),
            'platform': contribution.platform,
            'accountType': contribution.accountType,
            'email': contribution.email,
            'password': contribution.password,
            'region': contribution.region ?? 'Global',
            'edition': contribution.edition ?? 'Standard',
            'description': contribution.description ?? '',
            'contributorId': contribution.contributorId,
            'contributorName': contribution.contributorName,
            'lenderTier': 'member', // Based on user tier
            'gameValue': contribution.gameValue,
            'totalCost': contribution.gameValue,
            'isActive': true,
            'dateAdded': FieldValue.serverTimestamp(),
            'supportedPlatforms': [contribution.platform],
            'sharingOptions': [contribution.accountType],
            'slots': {
              '${contribution.platform}_${contribution.accountType}': {
                'platform': contribution.platform,
                'accountType': contribution.accountType,
                'status': 'available',
                'borrowerId': null,
                'borrowDate': null,
              }
            },
            'totalRevenues': 0,
            'borrowRevenue': 0,
            'totalBorrows': 0,
            'currentBorrows': 0,
            'borrowHistory': [],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          final gameRef = _firestore.collection('games').doc();
          batch.set(gameRef, gameData);
        }
      } else if (contribution.type == ContributionType.fund) {
        // Update user metrics for fund contribution
        batch.update(userRef, {
          'fundShares': FieldValue.increment(metricsImpact['fundShares']),
          'totalShares': FieldValue.increment(metricsImpact['totalShares']),
          'totalFunds': FieldValue.increment(contribution.fundAmount ?? 0),
          'lastActivityDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Fund contributions will be refunded when game is purchased
        // Track this in a separate fund_pools collection
        final fundPoolData = {
          'contributorId': contribution.contributorId,
          'contributorName': contribution.contributorName,
          'amount': contribution.fundAmount,
          'targetGameTitle': contribution.targetGameTitle,
          'status': 'pooled',
          'contributionId': contributionId,
          'createdAt': FieldValue.serverTimestamp(),
        };

        final fundPoolRef = _firestore.collection('fund_pools').doc();
        batch.set(fundPoolRef, fundPoolData);
      }

      // Check for VIP promotion eligibility
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final totalShares = (userData['totalShares'] ?? 0) + metricsImpact['totalShares'];
        final fundShares = (userData['fundShares'] ?? 0) + metricsImpact['fundShares'];
        final currentTier = userData['tier'] ?? 'user';

        // Auto-promote to VIP if eligible
        if (totalShares >= 15 && fundShares >= 5 && currentTier == 'member') {
          batch.update(userRef, {
            'tier': 'vip',
            'borrowLimit': 5,
          });
        }

        // Update borrow limit based on total shares
        int newBorrowLimit = 1;
        if (totalShares >= 15) {
          newBorrowLimit = 4;
        } else if (totalShares >= 9) {
          newBorrowLimit = 3;
        } else if (totalShares >= 4) {
          newBorrowLimit = 2;
        }

        batch.update(userRef, {
          'borrowLimit': newBorrowLimit,
        });
      }

      // Commit all changes
      await batch.commit();

      return {
        'success': true,
        'message': 'Contribution approved successfully',
      };
    } catch (e) {
      print('Error approving contribution: $e');
      return {
        'success': false,
        'message': 'Failed to approve contribution: $e',
      };
    }
  }

  // Reject a contribution
  Future<Map<String, dynamic>> rejectContribution({
    required String contributionId,
    required String rejectedBy,
    required String reason,
  }) async {
    try {
      await _firestore.collection('contributions').doc(contributionId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': rejectedBy,
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Contribution rejected',
      };
    } catch (e) {
      print('Error rejecting contribution: $e');
      return {
        'success': false,
        'message': 'Failed to reject contribution: $e',
      };
    }
  }

  // Get user's contributions
  Stream<List<ContributionModel>> getUserContributions(String userId) {
    return _firestore
        .collection('contributions')
        .where('contributorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ContributionModel.fromFirestore(doc))
        .toList());
  }

  // Get pending contributions (for admin)
  Stream<List<ContributionModel>> getPendingContributions() {
    return _firestore
        .collection('contributions')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ContributionModel.fromFirestore(doc))
        .toList());
  }
}