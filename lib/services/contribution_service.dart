// lib/services/contribution_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../data/models/game_model.dart';
import '../data/models/user_model.dart';

class ContributionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  // Submit a new contribution request
  Future<Map<String, dynamic>> submitContribution({
    required String userId,
    required String userName,
    required String gameTitle,
    required List<String> includedTitles,
    required List<Platform> platforms,
    required List<AccountType> sharingOptions,
    required double gameValue,
    required String email,
    required String password,
    String? edition,
    String? region,
    String? coverImageUrl,
    String? description,
  }) async {
    try {
      // Create contribution request document
      final requestData = {
        'userId': userId,
        'userName': userName,
        'gameTitle': gameTitle,
        'includedTitles': includedTitles,
        'platforms': platforms.map((p) => p.value).toList(), // Using .value
        'sharingOptions': sharingOptions.map((a) => a.value).toList(), // Using .value
        'gameValue': gameValue,
        'credentials': {
          'email': email,
          'password': password,
        },
        'edition': edition ?? 'standard',
        'region': region ?? 'US',
        'coverImageUrl': coverImageUrl,
        'description': description,
        'status': 'pending',
        'type': 'game_account',
        'submittedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('contribution_requests').add(requestData);

      return {
        'success': true,
        'message': 'Contribution submitted successfully! Waiting for admin approval.',
      };
    } catch (e) {
      print('Error submitting contribution: $e');
      return {
        'success': false,
        'message': 'Failed to submit contribution: $e',
      };
    }
  }

  // Submit fund contribution request
  Future<Map<String, dynamic>> submitFundContribution({
    required String userId,
    required String userName,
    required String gameTitle,
    required double amount,
    String? notes,
  }) async {
    try {
      final requestData = {
        'userId': userId,
        'userName': userName,
        'gameTitle': gameTitle,
        'amount': amount,
        'type': 'fund_share',
        'status': 'pending',
        'notes': notes,
        'submittedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('contribution_requests').add(requestData);

      return {
        'success': true,
        'message': 'Fund contribution submitted successfully!',
      };
    } catch (e) {
      print('Error submitting fund contribution: $e');
      return {
        'success': false,
        'message': 'Failed to submit fund contribution: $e',
      };
    }
  }

  // Get all pending contributions (for admin)
  Stream<QuerySnapshot> getPendingContributions() {
    return _firestore
        .collection('contribution_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Get approved contributions (for admin)
  Stream<QuerySnapshot> getApprovedContributions() {
    return _firestore
        .collection('contribution_requests')
        .where('status', isEqualTo: 'approved')
        .snapshots();
  }

  // Get user's contributions
  Stream<QuerySnapshot> getUserContributions(String userId) {
    return _firestore
        .collection('contribution_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  // Approve game account contribution
  Future<Map<String, dynamic>> approveGameContribution(String requestId) async {
    try {
      final batch = _firestore.batch();

      // Get the contribution request
      final requestDoc = await _firestore
          .collection('contribution_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        return {'success': false, 'message': 'Contribution request not found'};
      }

      final data = requestDoc.data()!;

      // Update request status
      batch.update(requestDoc.reference, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin', // TODO: Get actual admin ID
      });

      // Generate unique account ID
      final accountId = _uuid.v4();

      // Create slots based on platforms and sharing options
      Map<String, dynamic> slots = {};
      List<Platform> platforms = (data['platforms'] as List)
          .map((p) => Platform.fromString(p.toString()))
          .toList();
      List<AccountType> sharingOptions = (data['sharingOptions'] as List)
          .map((a) => AccountType.fromString(a.toString()))
          .toList();

      for (var platform in platforms) {
        for (var accountType in sharingOptions) {
          final slotKey = '${platform.value}_${accountType.value}'; // Using .value
          slots[slotKey] = {
            'platform': platform.value, // Using .value
            'accountType': accountType.value, // Using .value
            'status': SlotStatus.available.value, // Using .value
            'borrowerId': null,
            'borrowDate': null,
            'expectedReturnDate': null,
            'reservationDate': null,
            'reservedById': null,
          };
        }
      }

      // Check if game already exists
      final gameQuery = await _firestore
          .collection('games')
          .where('title', isEqualTo: data['gameTitle'])
          .limit(1)
          .get();

      // Create the account object
      final accountData = {
        'accountId': accountId,
        'contributorId': data['userId'],
        'contributorName': data['userName'],
        'platforms': data['platforms'], // Already stored as strings
        'sharingOptions': data['sharingOptions'], // Already stored as strings
        'credentials': data['credentials'],
        'edition': data['edition'] ?? 'standard',
        'region': data['region'] ?? 'US',
        'status': 'available',
        'slots': slots,
        'gameValue': data['gameValue'],
        'dateAdded': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      if (gameQuery.docs.isEmpty) {
        // Create new game entry with this account
        final gameRef = _firestore.collection('games').doc();
        batch.set(gameRef, {
          'gameId': gameRef.id,
          'title': data['gameTitle'],
          'includedTitles': data['includedTitles'] ?? [data['gameTitle']],
          'coverImageUrl': data['coverImageUrl'],
          'description': data['description'],
          'lenderTier': LenderTier.member.value, // Using .value
          'accounts': [accountData], // Array of accounts
          'totalValue': data['gameValue'],
          'totalAccounts': 1,
          'availableAccounts': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Add account to existing game
        final gameDoc = gameQuery.docs.first;
        batch.update(gameDoc.reference, {
          'accounts': FieldValue.arrayUnion([accountData]),
          'totalValue': FieldValue.increment(data['gameValue']),
          'totalAccounts': FieldValue.increment(1),
          'availableAccounts': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update user metrics
      final userRef = _firestore.collection('users').doc(data['userId']);

      // Determine share count based on account types
      double shareCount = 0;
      Map<String, int> shareBreakdown = {};

      for (var accountType in sharingOptions) {
        shareCount += accountType.shareValue; // Using the shareValue getter

        switch (accountType) {
          case AccountType.full:
            shareBreakdown['full'] = (shareBreakdown['full'] ?? 0) + 1;
            break;
          case AccountType.primary:
            shareBreakdown['primary'] = (shareBreakdown['primary'] ?? 0) + 1;
            break;
          case AccountType.secondary:
            shareBreakdown['secondary'] = (shareBreakdown['secondary'] ?? 0) + 1;
            break;
          case AccountType.psPlus:
            shareBreakdown['psplus'] = (shareBreakdown['psplus'] ?? 0) + 1;
            break;
        }
      }

      // Update user document
      batch.update(userRef, {
        'gameShares': FieldValue.increment(shareCount),
        'totalShares': FieldValue.increment(shareCount),
        'shareBreakdown.full': FieldValue.increment(shareBreakdown['full'] ?? 0),
        'shareBreakdown.primary': FieldValue.increment(shareBreakdown['primary'] ?? 0),
        'shareBreakdown.secondary': FieldValue.increment(shareBreakdown['secondary'] ?? 0),
        'shareBreakdown.psplus': FieldValue.increment(shareBreakdown['psplus'] ?? 0),
        'stationLimit': FieldValue.increment(data['gameValue']),
        'remainingStationLimit': FieldValue.increment(data['gameValue']),
        'borrowValue': FieldValue.increment(data['gameValue'] * 0.7), // 70% balance
        'lastActivityDate': FieldValue.serverTimestamp(),
        'coldPeriodDays': 0, // Reset cold period
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Check for VIP promotion
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final totalShares = userData['totalShares'] ?? 0;
        final fundShares = userData['fundShares'] ?? 0;
        final currentTier = userData['tier'] ?? 'member';

        if (totalShares >= 15 && fundShares >= 5 && currentTier == 'member') {
          batch.update(userRef, {
            'tier': UserTier.vip.value, // Using .value
            'promotedToVipAt': FieldValue.serverTimestamp(),
          });
        }

        // Update borrow limit based on total shares
        final newBorrowLimit = UserModel.calculateBorrowLimit(
            totalShares.toInt(),
            UserTier.fromString(currentTier)
        );
        batch.update(userRef, {
          'borrowLimit': newBorrowLimit,
        });
      }

      await batch.commit();

      return {
        'success': true,
        'message': 'Game contribution approved successfully!',
      };
    } catch (e) {
      print('Error approving contribution: $e');
      return {
        'success': false,
        'message': 'Failed to approve contribution: $e',
      };
    }
  }

  // Approve fund contribution
  Future<Map<String, dynamic>> approveFundContribution(String requestId) async {
    try {
      final batch = _firestore.batch();

      // Get the contribution request
      final requestDoc = await _firestore
          .collection('contribution_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        return {'success': false, 'message': 'Fund contribution request not found'};
      }

      final data = requestDoc.data()!;

      // Update request status
      batch.update(requestDoc.reference, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin',
      });

      // Update user metrics
      final userRef = _firestore.collection('users').doc(data['userId']);
      batch.update(userRef, {
        'fundShares': FieldValue.increment(1),
        'totalShares': FieldValue.increment(1),
        'totalFunds': FieldValue.increment(data['amount']),
        'stationLimit': FieldValue.increment(data['amount']),
        'remainingStationLimit': FieldValue.increment(data['amount']),
        'lastActivityDate': FieldValue.serverTimestamp(),
        'coldPeriodDays': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Check if this fund contribution is for a vault game
      if (data['gameTitle'] != null && data['gameTitle'] != '') {
        // Check if vault game exists or create it
        final vaultQuery = await _firestore
            .collection('games')
            .where('title', isEqualTo: data['gameTitle'])
            .where('lenderTier', isEqualTo: LenderTier.gamesVault.value)
            .limit(1)
            .get();

        if (vaultQuery.docs.isNotEmpty) {
          // Add contributor to existing vault game
          final vaultDoc = vaultQuery.docs.first;
          batch.update(vaultDoc.reference, {
            'fundContributors': FieldValue.arrayUnion([data['userId']]),
            'contributorShares.${data['userId']}': FieldValue.increment(data['amount']),
            'totalValue': FieldValue.increment(data['amount']),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Check for VIP promotion
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final totalShares = userData['totalShares'] ?? 0;
        final fundShares = userData['fundShares'] ?? 0;
        final currentTier = userData['tier'] ?? 'member';

        if (totalShares >= 15 && fundShares >= 5 && currentTier == 'member') {
          batch.update(userRef, {
            'tier': UserTier.vip.value, // Using .value
            'promotedToVipAt': FieldValue.serverTimestamp(),
          });
        }

        // Update borrow limit
        final newBorrowLimit = UserModel.calculateBorrowLimit(
            totalShares.toInt(),
            UserTier.fromString(currentTier)
        );
        batch.update(userRef, {
          'borrowLimit': newBorrowLimit,
        });
      }

      await batch.commit();

      return {
        'success': true,
        'message': 'Fund contribution approved successfully!',
      };
    } catch (e) {
      print('Error approving fund contribution: $e');
      return {
        'success': false,
        'message': 'Failed to approve fund contribution: $e',
      };
    }
  }

  // Reject contribution
  Future<Map<String, dynamic>> rejectContribution(
      String requestId,
      String reason,
      ) async {
    try {
      await _firestore.collection('contribution_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': 'admin',
        'rejectionReason': reason,
      });

      return {
        'success': true,
        'message': 'Contribution rejected.',
      };
    } catch (e) {
      print('Error rejecting contribution: $e');
      return {
        'success': false,
        'message': 'Failed to reject contribution: $e',
      };
    }
  }

  // Calculate user scores (C, F, H, E scores)
  Future<void> calculateUserScores(String tier) async {
    try {
      // Get all active users in the tier
      final usersQuery = await _firestore
          .collection('users')
          .where('tier', isEqualTo: tier)
          .where('status', isEqualTo: UserStatus.active.value) // Using .value
          .get();

      final users = usersQuery.docs;

      // Sort by different metrics and assign scores
      // C Score - Total Shares ranking
      users.sort((a, b) => (b['totalShares'] ?? 0).compareTo(a['totalShares'] ?? 0));
      for (int i = 0; i < users.length; i++) {
        await users[i].reference.update({'cScore': i + 1});
      }

      // F Score - Fund Shares ranking
      users.sort((a, b) => (b['totalFunds'] ?? 0).compareTo(a['totalFunds'] ?? 0));
      for (int i = 0; i < users.length; i++) {
        await users[i].reference.update({'fScore': i + 1});
      }

      // H Score - Average Hold Period ranking
      users.sort((a, b) => (b['averageHoldPeriod'] ?? 0).compareTo(a['averageHoldPeriod'] ?? 0));
      for (int i = 0; i < users.length; i++) {
        await users[i].reference.update({'hScore': i + 1});
      }

      // E Score - Net Exchange ranking
      users.sort((a, b) => (b['netExchange'] ?? 0).compareTo(a['netExchange'] ?? 0));
      for (int i = 0; i < users.length; i++) {
        await users[i].reference.update({'eScore': i + 1});
      }

      // Calculate overall score for each user
      for (var user in users) {
        final data = user.data();
        final cScore = data['cScore'] ?? 0;
        final fScore = data['fScore'] ?? 0;
        final hScore = data['hScore'] ?? 0;
        final eScore = data['eScore'] ?? 0;

        final overallScore = (cScore * 0.2) + (fScore * 0.35) +
            (hScore * 0.1) + (eScore * 0.35);

        await user.reference.update({'overallScore': overallScore});
      }
    } catch (e) {
      print('Error calculating scores: $e');
    }
  }

  // Get contribution statistics for dashboard
  Future<Map<String, int>> getContributionStats() async {
    try {
      final pending = await _firestore
          .collection('contribution_requests')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      final approved = await _firestore
          .collection('contribution_requests')
          .where('status', isEqualTo: 'approved')
          .count()
          .get();

      final rejected = await _firestore
          .collection('contribution_requests')
          .where('status', isEqualTo: 'rejected')
          .count()
          .get();

      return {
        'pending': pending.count,
        'approved': approved.count,
        'rejected': rejected.count,
        'total': pending.count + approved.count + rejected.count,
      };
    } catch (e) {
      print('Error getting contribution stats: $e');
      return {
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total': 0,
      };
    }
  }
}