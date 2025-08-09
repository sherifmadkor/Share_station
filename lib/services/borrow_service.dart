// lib/services/borrow_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
// Import with prefix to avoid conflicts
import '../data/models/game_model.dart' as game_models;
import '../data/models/user_model.dart';

class BorrowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  // Submit a borrow request
  Future<Map<String, dynamic>> submitBorrowRequest({
    required String userId,
    required String userName,
    required String gameId,
    required String gameTitle,
    required String accountId,
    required game_models.Platform platform,
    required game_models.AccountType accountType,
    required double borrowValue, // This is the game's value
  }) async {
    try {
      // Get user data to validate eligibility
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return {'success': false, 'message': 'User not found'};
      }

      final userData = userDoc.data()!;

      // Get user's member ID (3-digit)
      final memberId = userData['memberId'] ?? userData['uid'] ?? userId;

      // Calculate actual borrow value based on account type
      final actualBorrowValue = borrowValue * accountType.borrowMultiplier;

      // Check station limit
      final remainingStationLimit = (userData['remainingStationLimit'] ?? userData['stationLimit'] ?? 0).toDouble();
      if (remainingStationLimit < actualBorrowValue) {
        return {
          'success': false,
          'message': 'Insufficient Station Limit. Required: ${actualBorrowValue.toStringAsFixed(0)} LE, Available: ${remainingStationLimit.toStringAsFixed(0)} LE',
        };
      }

      // Check borrow limit (simultaneous borrows)
      final currentBorrows = (userData['currentBorrows'] ?? 0).toDouble();
      final borrowLimit = (userData['borrowLimit'] ?? 1).toDouble();

      if (currentBorrows >= borrowLimit) {
        return {
          'success': false,
          'message': 'You have reached your borrow limit of ${borrowLimit.toInt()} simultaneous borrows',
        };
      }

      // Check if user is suspended
      final status = userData['status'] ?? 'active';
      if (status == 'suspended') {
        return {
          'success': false,
          'message': 'Your account is suspended. Please contact admin.',
        };
      }

      // Check cooldown status
      final coolDownEndDate = userData['coolDownEndDate'];
      if (coolDownEndDate != null) {
        final coolDownEnd = (coolDownEndDate as Timestamp).toDate();
        if (coolDownEnd.isAfter(DateTime.now())) {
          final daysRemaining = coolDownEnd.difference(DateTime.now()).inDays;
          return {
            'success': false,
            'message': 'You are in cooldown period. You can borrow again in $daysRemaining days.',
          };
        }
      }

      // Create borrow request
      final requestData = {
        'userId': userId,
        'userName': userName,
        'memberId': memberId, // Add member ID for display
        'gameId': gameId,
        'gameTitle': gameTitle,
        'accountId': accountId,
        'platform': platform.value,
        'accountType': accountType.value,
        'gameValue': borrowValue, // Original game value
        'borrowValue': actualBorrowValue, // Calculated borrow value
        'status': 'pending',
        'requestDate': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('borrow_requests').add(requestData);

      return {
        'success': true,
        'message': 'Borrow request submitted successfully! Waiting for admin approval.',
        'requestId': docRef.id,
      };
    } catch (e) {
      print('Error submitting borrow request: $e');
      return {
        'success': false,
        'message': 'Failed to submit borrow request: $e',
      };
    }
  }

  // Get user's active borrows - THIS IS THE MISSING METHOD
  Future<List<Map<String, dynamic>>> getUserActiveBorrows(String userId) async {
    try {
      final query = await _firestore
          .collection('borrow_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting user active borrows: $e');
      return [];
    }
  }

  // Get user's borrow history (all statuses)
  Future<List<Map<String, dynamic>>> getUserBorrowHistory(String userId) async {
    try {
      final query = await _firestore
          .collection('borrow_requests')
          .where('userId', isEqualTo: userId)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting user borrow history: $e');
      return [];
    }
  }

  // Get pending borrow requests (for admin)
  Stream<QuerySnapshot> getPendingBorrowRequests() {
    return _firestore
        .collection('borrow_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Get active borrows (approved and not returned)
  Stream<QuerySnapshot> getActiveBorrows() {
    return _firestore
        .collection('borrow_requests')
        .where('status', isEqualTo: 'approved')
        .snapshots();
  }

  // Get overdue borrows
  Future<List<Map<String, dynamic>>> getOverdueBorrows() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));

      final query = await _firestore
          .collection('borrow_requests')
          .where('status', isEqualTo: 'approved')
          .where('approvalDate', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        // Calculate days overdue
        final approvalDate = (data['approvalDate'] as Timestamp).toDate();
        final daysBorrowed = DateTime.now().difference(approvalDate).inDays;
        data['daysOverdue'] = daysBorrowed - 30;

        return data;
      }).toList();
    } catch (e) {
      print('Error getting overdue borrows: $e');
      return [];
    }
  }

  // Approve borrow request
  Future<Map<String, dynamic>> approveBorrowRequest(String requestId) async {
    try {
      final batch = _firestore.batch();

      // Get the borrow request by document ID
      final requestDoc = await _firestore
          .collection('borrow_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        return {'success': false, 'message': 'Borrow request not found'};
      }

      final data = requestDoc.data()!;

      // Update request status
      batch.update(requestDoc.reference, {
        'status': 'approved',
        'approvalDate': FieldValue.serverTimestamp(),
        'approvedBy': 'admin', // You can pass actual admin ID
      });

      // Update game slot status and get account data
      final gameDoc = await _firestore.collection('games').doc(data['gameId']).get();

      String? contributorId;
      if (gameDoc.exists) {
        final gameData = gameDoc.data()!;
        final accounts = List<Map<String, dynamic>>.from(gameData['accounts'] ?? []);

        // Find the specific account and update its slot
        int accountIndex = accounts.indexWhere((acc) => acc['accountId'] == data['accountId']);
        if (accountIndex == -1) {
          return {'success': false, 'message': 'Account not found in game'};
        }

        final slotKey = '${data['platform']}_${data['accountType']}';

        // Update the slot status in the account
        if (accounts[accountIndex]['slots'] == null) {
          accounts[accountIndex]['slots'] = {};
        }

        accounts[accountIndex]['slots'][slotKey] = {
          'platform': data['platform'],
          'accountType': data['accountType'],
          'status': game_models.SlotStatus.taken.value,
          'borrowerId': data['userId'],
          'borrowerName': data['userName'],
          'borrowDate': Timestamp.fromDate(DateTime.now()),
          'expectedReturnDate': Timestamp.fromDate(
            DateTime.now().add(Duration(days: 30)),
          ),
        };

        // Get contributor ID for lending metrics update
        final accountData = accounts[accountIndex];
        contributorId = accountData['contributorId'];

        // Update the game document with modified accounts array
        batch.update(gameDoc.reference, {
          'accounts': accounts,
          'availableAccounts': FieldValue.increment(-1),
          'currentBorrows': FieldValue.increment(1),
          'totalBorrows': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update user metrics
      final userRef = _firestore.collection('users').doc(data['userId']);

      // Calculate borrow count based on account type
      final accountType = game_models.AccountType.fromString(data['accountType']);
      double borrowCount = accountType.borrowLimitImpact;

      batch.update(userRef, {
        'currentBorrows': FieldValue.increment(borrowCount),
        'totalBorrowsCount': FieldValue.increment(1),
        'remainingStationLimit': FieldValue.increment(-data['borrowValue']),
        'netBorrowings': FieldValue.increment(data['borrowValue']),
        'points': FieldValue.increment(data['borrowValue']), // 1 point per LE
        'expensePoints': FieldValue.increment(data['borrowValue']),
        'lastActivityDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Set cooldown for primary or full account borrows
      if (accountType == game_models.AccountType.primary || accountType == game_models.AccountType.full) {
        batch.update(userRef, {
          'coolDownEligible': false,
          'coolDownEndDate': Timestamp.fromDate(
            DateTime.now().add(Duration(days: 7)), // 7 days cooldown
          ),
        });
      }

      // Update contributor's lending metrics
      if (contributorId != null && contributorId != data['userId']) {
        final contributorRef = _firestore.collection('users').doc(contributorId);
        batch.update(contributorRef, {
          'netLending': FieldValue.increment(data['borrowValue']),
          'totalLendings': FieldValue.increment(1),
        });
      }

      // Create borrow history entry
      final historyData = {
        'requestId': requestId,
        'userId': data['userId'],
        'userName': data['userName'],
        'gameId': data['gameId'],
        'gameTitle': data['gameTitle'],
        'accountId': data['accountId'],
        'platform': data['platform'],
        'accountType': data['accountType'],
        'borrowValue': data['borrowValue'],
        'status': 'active',
        'borrowDate': FieldValue.serverTimestamp(),
        'expectedReturnDate': Timestamp.fromDate(
          DateTime.now().add(Duration(days: 30)),
        ),
      };

      batch.set(_firestore.collection('borrow_history').doc(), historyData);

      await batch.commit();

      return {
        'success': true,
        'message': 'Borrow request approved successfully!',
      };
    } catch (e) {
      print('Error approving borrow request: $e');
      return {
        'success': false,
        'message': 'Failed to approve borrow request: $e',
      };
    }
  }

  // Reject borrow request
  Future<Map<String, dynamic>> rejectBorrowRequest(
      String requestId,
      String reason,
      ) async {
    try {
      // Update by document ID directly
      await _firestore.collection('borrow_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': 'admin',
        'rejectionReason': reason,
      });

      return {
        'success': true,
        'message': 'Borrow request rejected',
      };
    } catch (e) {
      print('Error rejecting borrow request: $e');
      return {
        'success': false,
        'message': 'Failed to reject borrow request: $e',
      };
    }
  }

  // Return borrowed game
  Future<Map<String, dynamic>> returnBorrowedGame(String requestId) async {
    try {
      final batch = _firestore.batch();

      // Get the borrow request
      final requestDoc = await _firestore
          .collection('borrow_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        return {'success': false, 'message': 'Borrow request not found'};
      }

      final data = requestDoc.data()!;

      // Calculate hold period
      final approvalDate = (data['approvalDate'] as Timestamp).toDate();
      final holdPeriod = DateTime.now().difference(approvalDate).inDays;

      // Update request status
      batch.update(requestDoc.reference, {
        'status': 'returned',
        'returnDate': FieldValue.serverTimestamp(),
        'holdPeriod': holdPeriod,
      });

      // Update game slot status
      final gameDoc = await _firestore.collection('games').doc(data['gameId']).get();

      if (gameDoc.exists) {
        final gameData = gameDoc.data()!;
        final accounts = List<Map<String, dynamic>>.from(gameData['accounts'] ?? []);

        int accountIndex = accounts.indexWhere((acc) => acc['accountId'] == data['accountId']);
        if (accountIndex != -1) {
          final slotKey = '${data['platform']}_${data['accountType']}';

          if (accounts[accountIndex]['slots'] != null) {
            accounts[accountIndex]['slots'][slotKey] = {
              'platform': data['platform'],
              'accountType': data['accountType'],
              'status': game_models.SlotStatus.available.value,
              'borrowerId': null,
              'borrowerName': null,
              'borrowDate': null,
              'expectedReturnDate': null,
            };
          }

          batch.update(gameDoc.reference, {
            'accounts': accounts,
            'availableAccounts': FieldValue.increment(1),
            'currentBorrows': FieldValue.increment(-1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Update user metrics
      final userRef = _firestore.collection('users').doc(data['userId']);

      // Calculate borrow count based on account type
      final accountType = game_models.AccountType.fromString(data['accountType']);
      double borrowCount = accountType.borrowLimitImpact;

      // Get current user data to update average hold period
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final totalBorrows = userData['totalBorrowsCount'] ?? 1;
        final currentAverage = (userData['averageHoldPeriod'] ?? 0).toDouble();
        final newAverage = ((currentAverage * (totalBorrows - 1)) + holdPeriod) / totalBorrows;

        batch.update(userRef, {
          'currentBorrows': FieldValue.increment(-borrowCount),
          'remainingStationLimit': FieldValue.increment(data['borrowValue']),
          'averageHoldPeriod': newAverage,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update borrow history
      final historyQuery = await _firestore
          .collection('borrow_history')
          .where('requestId', isEqualTo: requestId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (historyQuery.docs.isNotEmpty) {
        batch.update(historyQuery.docs.first.reference, {
          'status': 'returned',
          'returnDate': FieldValue.serverTimestamp(),
          'holdPeriod': holdPeriod,
        });
      }

      await batch.commit();

      return {
        'success': true,
        'message': 'Game returned successfully!',
      };
    } catch (e) {
      print('Error returning game: $e');
      return {
        'success': false,
        'message': 'Failed to return game: $e',
      };
    }
  }

  // Get borrow statistics for admin dashboard
  Future<Map<String, dynamic>> getBorrowStatistics() async {
    try {
      // Get counts
      final pending = await _firestore
          .collection('borrow_requests')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      final active = await _firestore
          .collection('borrow_requests')
          .where('status', isEqualTo: 'approved')
          .count()
          .get();

      final overdue = await getOverdueBorrows();

      return {
        'pending': pending.count ?? 0,
        'active': active.count ?? 0,
        'overdue': overdue.length,
        'total': (pending.count ?? 0) + (active.count ?? 0),
      };
    } catch (e) {
      print('Error getting borrow statistics: $e');
      return {
        'pending': 0,
        'active': 0,
        'overdue': 0,
        'total': 0,
      };
    }
  }
}