// lib/services/contribution_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
// Import game_model with prefix to avoid Platform conflict
import '../data/models/game_model.dart' as game_models;
import '../data/models/user_model.dart';
import 'suspension_service.dart';

// Main service class for handling contributions
class ContributionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();
  final SuspensionService _suspensionService = SuspensionService();

  // Helper method to calculate borrow limit based on shares
  int _calculateBorrowLimit(int totalShares, int fundShares) {
    // Based on BRD: Borrow limit increases with contributions
    // 0-4 shares: 1 borrow
    // 5-9 shares: 2 borrows
    // 10-14 shares: 3 borrows
    // 15+ shares with 5+ fund shares: 5 borrows (VIP)
    // 15-19 shares: 4 borrows
    // 20+ shares: 5 borrows

    if (totalShares >= 15 && fundShares >= 5) {
      return 5; // VIP status
    } else if (totalShares >= 20) {
      return 5;
    } else if (totalShares >= 15) {
      return 4;
    } else if (totalShares >= 10) {
      return 3;
    } else if (totalShares >= 5) {
      return 2;
    } else {
      return 1;
    }
  }

  // Submit a new contribution request
  Future<Map<String, dynamic>> submitContribution({
    required String userId,
    required String userName,
    required String gameTitle,
    required List<String> includedTitles,
    required List<game_models.Platform> platforms,
    required List<game_models.AccountType> sharingOptions,
    required double gameValue,
    required String email,
    required String password,
    String? edition,
    String? region,
    String? coverImageUrl,
    String? description,
    String? existingGameId, // NEW: ID of existing game to add account to
    bool isFullAccount = false, // NEW: Flag for full account handling
  }) async {
    try {
      // Create contribution request document
      final requestData = {
        'userId': userId,
        'userName': userName,
        'gameTitle': gameTitle,
        'includedTitles': includedTitles,
        'platforms': platforms.map((p) => p.value).toList(),
        'sharingOptions': sharingOptions.map((a) => a.value).toList(),
        'gameValue': gameValue,
        'credentials': {
          'email': email,
          'password': password,
        },
        'edition': edition ?? 'Standard',
        'region': region ?? 'US',
        'coverImageUrl': coverImageUrl,
        'description': description,
        'status': 'pending',
        'type': 'game_account',
        'submittedAt': FieldValue.serverTimestamp(),
        'existingGameId': existingGameId, // Store reference to existing game
        'isFullAccount': isFullAccount, // Flag for special handling
      };

      await _firestore.collection('contribution_requests').add(requestData);

      // Update user contribution activity and check for VIP promotion
      await _suspensionService.updateLastContribution(userId);
      await _suspensionService.checkAndPromoteToVIP(userId);

      return {
        'success': true,
        'message': existingGameId != null 
            ? 'Contribution submitted! Your account will be added to the existing game after approval.'
            : 'Contribution submitted successfully! Waiting for admin approval.',
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

      // Update user contribution activity and check for VIP promotion
      await _suspensionService.updateLastContribution(userId);
      await _suspensionService.checkAndPromoteToVIP(userId);

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

  // Get rejected contributions (for admin)
  Stream<QuerySnapshot> getRejectedContributions() {
    return _firestore
        .collection('contribution_requests')
        .where('status', isEqualTo: 'rejected')
        .snapshots();
  }

  // Get user's contributions
  Stream<QuerySnapshot> getUserContributions(String userId) {
    return _firestore
        .collection('contribution_requests')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  // Get user's pending contributions
  Stream<QuerySnapshot> getUserPendingContributions(String userId) {
    return _firestore
        .collection('contribution_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Get user's approved contributions
  Stream<QuerySnapshot> getUserApprovedContributions(String userId) {
    return _firestore
        .collection('contribution_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
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
      final gameTitle = data['gameTitle'];
      final userId = data['userId'];
      final gameValue = (data['gameValue'] ?? 0).toDouble();

      // Parse platforms and sharing options
      final platforms = (data['platforms'] as List<dynamic>)
          .map((p) => game_models.Platform.fromString(p.toString()))
          .toList();

      final sharingOptions = (data['sharingOptions'] as List<dynamic>)
          .map((a) => game_models.AccountType.fromString(a.toString()))
          .toList();

      // Generate account ID
      final accountId = _uuid.v4();

      // Create slots based on platform and sharing option combinations
      Map<String, dynamic> slots = {};
      for (var platform in platforms) {
        for (var accountType in sharingOptions) {
          final slotKey = '${platform.value}_${accountType.value}';
          slots[slotKey] = {
            'platform': platform.value,
            'accountType': accountType.value,
            'status': game_models.SlotStatus.available.value,
            'borrowerId': null,
            'borrowerName': null,
            'borrowDate': null,
            'expectedReturnDate': null,
          };
        }
      }

      // Check if game already exists
      final gameQuery = await _firestore
          .collection('games')
          .where('title', isEqualTo: gameTitle)
          .limit(1)
          .get();

      if (gameQuery.docs.isNotEmpty) {
        // Game exists - add new account to existing game
        final gameDoc = gameQuery.docs.first;
        final gameData = gameDoc.data();

        // Get existing accounts array or create new one
        List<dynamic> accounts = gameData['accounts'] ?? [];

        // Add new account (use DateTime.now() instead of serverTimestamp in array)
        accounts.add({
          'accountId': accountId,
          'contributorId': data['userId'],
          'contributorName': data['userName'],
          'platforms': platforms.map((p) => p.value).toList(),
          'sharingOptions': sharingOptions.map((a) => a.value).toList(),
          'slots': slots,
          'credentials': data['credentials'],
          'gameValue': gameValue,
          'edition': data['edition'] ?? 'standard',
          'region': data['region'] ?? 'US',
          'dateAdded': Timestamp.fromDate(DateTime.now()),
        });

        // Update game document
        batch.update(gameDoc.reference, {
          'accounts': accounts,
          'totalAccounts': accounts.length,
          'availableAccounts': FieldValue.increment(1),
          'totalValue': FieldValue.increment(gameValue),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new game with first account
        final gameId = _uuid.v4();
        final gameData = {
          'gameId': gameId,
          'title': gameTitle,
          'includedTitles': data['includedTitles'] ?? [gameTitle],
          'coverImageUrl': data['coverImageUrl'],
          'description': data['description'],
          'lenderTier': 'member', // Member contributed games
          'accounts': [{
            'accountId': accountId,
            'contributorId': data['userId'],
            'contributorName': data['userName'],
            'platforms': platforms.map((p) => p.value).toList(),
            'sharingOptions': sharingOptions.map((a) => a.value).toList(),
            'slots': slots,
            'credentials': data['credentials'],
            'gameValue': gameValue,
            'edition': data['edition'] ?? 'standard',
            'region': data['region'] ?? 'US',
            'dateAdded': Timestamp.fromDate(DateTime.now()),
          }],
          'totalAccounts': 1,
          'availableAccounts': 1,
          'totalValue': gameValue,
          'dateAdded': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        };

        batch.set(_firestore.collection('games').doc(gameId), gameData);
      }

      // Update user metrics
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        return {'success': false, 'message': 'User not found'};
      }

      final userData = userDoc.data()!;

      // Calculate share counts based on account types
      double totalShares = 0;
      for (var accountType in sharingOptions) {
        totalShares += accountType.shareValue;
      }

      // Create balance entry for 70% of game value (expires in 90 days)
      final balanceEntryId = _uuid.v4();
      final now = DateTime.now();
      final balanceEntry = {
        'id': balanceEntryId,
        'type': 'borrowValue',
        'amount': gameValue * 0.7,
        'description': 'Contribution: $gameTitle',
        'date': Timestamp.fromDate(now),
        'expiryDate': Timestamp.fromDate(now.add(Duration(days: 90))),
        'isExpired': false,
      };

      // Get existing balance entries
      List<dynamic> balanceEntries = userData['balanceEntries'] ?? [];
      balanceEntries.add(balanceEntry);

      // Calculate new borrow limit based on total shares
      final currentGameShares = (userData['gameShares'] ?? 0).toDouble();
      final currentFundShares = (userData['fundShares'] ?? 0).toDouble();
      final newGameShares = currentGameShares + totalShares;
      final newTotalShares = newGameShares + currentFundShares;

      // Borrow limit calculation based on BRD rules
      int newBorrowLimit = _calculateBorrowLimit(
          newTotalShares.toInt(),
          currentFundShares.toInt()
      );

      // Check for VIP promotion
      bool shouldPromoteToVIP = false;
      String newTier = userData['tier'] ?? 'member';

      if (newTier != 'vip' && newTotalShares >= 15 && currentFundShares >= 5) {
        shouldPromoteToVIP = true;
        newTier = 'vip';
        newBorrowLimit = 5; // VIP gets 5 simultaneous borrows
      }

      // Update user document
      Map<String, dynamic> userUpdates = {
        'stationLimit': FieldValue.increment(gameValue),
        // Don't set remainingStationLimit here - let it be calculated when needed
        'gameShares': newGameShares,
        'totalShares': newTotalShares,
        'borrowLimit': newBorrowLimit,
        'balanceEntries': balanceEntries,
        'lastActivityDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Initialize remainingStationLimit if it doesn't exist
      if (userData['remainingStationLimit'] == null) {
        userUpdates['remainingStationLimit'] = userData['stationLimit'] ?? 0 + gameValue;
      } else {
        // Just increment it like stationLimit
        userUpdates['remainingStationLimit'] = FieldValue.increment(gameValue);
      }

      if (shouldPromoteToVIP) {
        userUpdates['tier'] = 'vip';
        userUpdates['vipPromotionDate'] = FieldValue.serverTimestamp();
      }

      // Add share breakdown updates
      for (var accountType in sharingOptions) {
        String shareKey = 'shares${accountType.value.substring(0, 1).toUpperCase()}${accountType.value.substring(1)}';
        userUpdates[shareKey] = FieldValue.increment(accountType.shareValue);
      }

      batch.update(userRef, userUpdates);

      // Update contribution request status
      batch.update(requestDoc.reference, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin', // You can pass actual admin ID
      });

      // Commit all changes
      await batch.commit();

      // Update user contribution activity and check for VIP promotion
      await _suspensionService.updateLastContribution(userId);
      final vipResult = await _suspensionService.checkAndPromoteToVIP(userId);

      String message = 'Contribution approved successfully!';
      bool wasPromoted = vipResult['success'] == true;
      if (wasPromoted) {
        message += ' User has been promoted to VIP!';
      }

      return {
        'success': true,
        'message': message,
        'vipPromotion': wasPromoted,
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
        return {'success': false, 'message': 'Contribution request not found'};
      }

      final data = requestDoc.data()!;
      final userId = data['userId'];
      final amount = (data['amount'] ?? 0).toDouble();
      final gameTitle = data['gameTitle'];

      // Update user metrics
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        return {'success': false, 'message': 'User not found'};
      }

      final userData = userDoc.data()!;

      // Fund shares count as 1 share each
      final currentFundShares = (userData['fundShares'] ?? 0).toDouble();
      final currentGameShares = (userData['gameShares'] ?? 0).toDouble();
      final newFundShares = currentFundShares + 1;
      final newTotalShares = currentGameShares + newFundShares;

      // Calculate new borrow limit based on BRD rules
      int newBorrowLimit = _calculateBorrowLimit(
          newTotalShares.toInt(),
          newFundShares.toInt()
      );

      // Check for VIP promotion
      bool shouldPromoteToVIP = false;
      String newTier = userData['tier'] ?? 'member';

      if (newTier != 'vip' && newTotalShares >= 15 && newFundShares >= 5) {
        shouldPromoteToVIP = true;
        newTier = 'vip';
        newBorrowLimit = 5;
      }

      // Update user document
      Map<String, dynamic> userUpdates = {
        'stationLimit': FieldValue.increment(amount),
        'fundShares': newFundShares,
        'totalShares': newTotalShares,
        'borrowLimit': newBorrowLimit,
        'lastActivityDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (shouldPromoteToVIP) {
        userUpdates['tier'] = 'vip';
        userUpdates['vipPromotionDate'] = FieldValue.serverTimestamp();
      }

      batch.update(userRef, userUpdates);

      // Update contribution request status
      batch.update(requestDoc.reference, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin',
      });

      // TODO: Add fund contribution to games_vault collection if needed

      await batch.commit();

      // Update user contribution activity and check for VIP promotion
      await _suspensionService.updateLastContribution(userId);
      final vipResult = await _suspensionService.checkAndPromoteToVIP(userId);

      String message = 'Fund contribution approved successfully!';
      bool wasPromoted = vipResult['success'] == true;
      if (wasPromoted) {
        message += ' User has been promoted to VIP!';
      }

      return {
        'success': true,
        'message': message,
        'vipPromotion': wasPromoted,
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

  // Get contribution statistics for admin dashboard
  Future<Map<String, dynamic>> getContributionStatistics() async {
    try {
      // Get counts for each status
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
        'pending': pending.count ?? 0,
        'approved': approved.count ?? 0,
        'rejected': rejected.count ?? 0,
        'total': (pending.count ?? 0) + (approved.count ?? 0) + (rejected.count ?? 0),
      };
    } catch (e) {
      print('Error getting contribution statistics: $e');
      return {
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total': 0,
      };
    }
  }
}