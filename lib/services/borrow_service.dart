// lib/services/borrow_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../data/models/game_model.dart';
import '../data/models/user_model.dart' hide Platform;

class BorrowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  // Submit a borrow request (by member)
  Future<Map<String, dynamic>> submitBorrowRequest({
    required String userId,
    required String userName,
    required String gameId,
    required String gameTitle,
    required String accountId,
    required Platform platform,
    required AccountType accountType,
    required double borrowValue, // Changed from gameValue to borrowValue
  }) async {
    try {
      // Calculate actual borrow value based on account type
      final actualBorrowValue = borrowValue * accountType.borrowMultiplier;

      // Check user's station limit
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {
          'success': false,
          'message': 'User not found',
        };
      }

      final userData = userDoc.data()!;
      final remainingLimit = userData['remainingStationLimit'] ?? 0;

      if (remainingLimit < actualBorrowValue) {
        return {
          'success': false,
          'message': 'Insufficient Station Limit. You need ${actualBorrowValue} LE but only have ${remainingLimit} LE available.',
        };
      }

      // Check borrow limit
      final currentBorrows = userData['currentBorrows'] ?? 0;
      final borrowLimit = userData['borrowLimit'] ?? 1;

      // Calculate effective borrow count based on account type
      double effectiveBorrowCount = accountType.borrowLimitImpact;

      if (currentBorrows + effectiveBorrowCount > borrowLimit) {
        return {
          'success': false,
          'message': 'You have reached your borrowing limit of $borrowLimit games.',
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
      final requestId = _uuid.v4();
      final requestData = {
        'requestId': requestId,
        'userId': userId,
        'userName': userName,
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

      await _firestore.collection('borrow_requests').add(requestData);

      return {
        'success': true,
        'message': 'Borrow request submitted successfully! Waiting for admin approval.',
        'requestId': requestId,
      };
    } catch (e) {
      print('Error submitting borrow request: $e');
      return {
        'success': false,
        'message': 'Failed to submit borrow request: $e',
      };
    }
  }

  // Get user's active borrows - ADDED METHOD
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

  // Get pending borrow requests (for admin)
  Stream<QuerySnapshot> getPendingBorrowRequests() {
    return _firestore
        .collection('borrow_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestDate', descending: true)
        .snapshots();
  }

  // Get active borrows
  Stream<QuerySnapshot> getActiveBorrows() {
    return _firestore
        .collection('borrow_requests')
        .where('status', isEqualTo: 'approved')
        .orderBy('approvalDate', descending: true)
        .snapshots();
  }

  // Get user's borrow requests (all statuses)
  Stream<QuerySnapshot> getUserBorrowRequests(String userId) {
    return _firestore
        .collection('borrow_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('requestDate', descending: true)
        .snapshots();
  }

  // Get user's borrow history
  Future<List<Map<String, dynamic>>> getUserBorrowHistory(String userId) async {
    try {
      final query = await _firestore
          .collection('borrow_requests')
          .where('userId', isEqualTo: userId)
          .orderBy('requestDate', descending: true)
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

  // Approve borrow request (admin)
  Future<Map<String, dynamic>> approveBorrowRequest(String requestId) async {
    try {
      final batch = _firestore.batch();

      // Get the borrow request
      final requestQuery = await _firestore
          .collection('borrow_requests')
          .where('requestId', isEqualTo: requestId)
          .limit(1)
          .get();

      if (requestQuery.docs.isEmpty) {
        return {'success': false, 'message': 'Borrow request not found'};
      }

      final requestDoc = requestQuery.docs.first;
      final data = requestDoc.data();

      // Update request status
      batch.update(requestDoc.reference, {
        'status': 'approved',
        'approvalDate': FieldValue.serverTimestamp(),
        'approvedBy': 'admin',
        'expectedReturnDate': Timestamp.fromDate(
          DateTime.now().add(Duration(days: 30)), // 30 days borrow period
        ),
      });

      // Update game account slot status
      final gameDoc = await _firestore
          .collection('games')
          .doc(data['gameId'])
          .get();

      if (!gameDoc.exists) {
        return {'success': false, 'message': 'Game not found'};
      }

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
        'status': SlotStatus.taken.value,
        'borrowerId': data['userId'],
        'borrowerName': data['userName'],
        'borrowDate': FieldValue.serverTimestamp(),
        'expectedReturnDate': Timestamp.fromDate(
          DateTime.now().add(Duration(days: 30)),
        ),
      };

      // Update the game document with modified accounts array
      batch.update(gameDoc.reference, {
        'accounts': accounts,
        'availableAccounts': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user metrics
      final userRef = _firestore.collection('users').doc(data['userId']);

      // Calculate borrow count based on account type
      final accountType = AccountType.fromString(data['accountType']);
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
      if (accountType == AccountType.primary || accountType == AccountType.full) {
        batch.update(userRef, {
          'coolDownEligible': false,
          'coolDownEndDate': Timestamp.fromDate(
            DateTime.now().add(Duration(days: 7)), // 7 days cooldown
          ),
        });
      }

      // Update contributor's metrics (lending)
      final accountData = accounts[accountIndex];
      final contributorId = accountData['contributorId'];
      if (contributorId != null && contributorId != data['userId']) {
        final contributorRef = _firestore.collection('users').doc(contributorId);
        batch.update(contributorRef, {
          'netLendings': FieldValue.increment(data['borrowValue']),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Create a borrow history entry
      final borrowHistoryRef = _firestore.collection('borrow_history').doc();
      batch.set(borrowHistoryRef, {
        'borrowId': borrowHistoryRef.id,
        'requestId': requestId,
        'userId': data['userId'],
        'userName': data['userName'],
        'gameId': data['gameId'],
        'gameTitle': data['gameTitle'],
        'accountId': data['accountId'],
        'platform': data['platform'],
        'accountType': data['accountType'],
        'borrowValue': data['borrowValue'],
        'borrowDate': FieldValue.serverTimestamp(),
        'expectedReturnDate': Timestamp.fromDate(
          DateTime.now().add(Duration(days: 30)),
        ),
        'status': 'active',
        'contributorId': contributorId,
      });

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

  // Return a borrowed game
  Future<Map<String, dynamic>> returnBorrowedGame(String requestId) async {
    try {
      final batch = _firestore.batch();

      // Get the borrow request
      final requestQuery = await _firestore
          .collection('borrow_requests')
          .where('requestId', isEqualTo: requestId)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      if (requestQuery.docs.isEmpty) {
        return {'success': false, 'message': 'Active borrow not found'};
      }

      final requestDoc = requestQuery.docs.first;
      final data = requestDoc.data();

      // Calculate hold period
      final borrowDate = (data['approvalDate'] as Timestamp).toDate();
      final holdPeriod = DateTime.now().difference(borrowDate).inDays;

      // Update request status
      batch.update(requestDoc.reference, {
        'status': 'returned',
        'returnDate': FieldValue.serverTimestamp(),
        'holdPeriod': holdPeriod,
      });

      // Update game account slot status
      final gameDoc = await _firestore
          .collection('games')
          .doc(data['gameId'])
          .get();

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
              'status': SlotStatus.available.value,
              'borrowerId': null,
              'borrowerName': null,
              'borrowDate': null,
              'expectedReturnDate': null,
            };
          }

          batch.update(gameDoc.reference, {
            'accounts': accounts,
            'availableAccounts': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Update user metrics
      final userRef = _firestore.collection('users').doc(data['userId']);

      // Calculate borrow count based on account type
      final accountType = AccountType.fromString(data['accountType']);
      double borrowCount = accountType.borrowLimitImpact;

      // Get current user data to update average hold period
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final totalBorrows = userData['totalBorrowsCount'] ?? 1;
        final currentAverage = userData['averageHoldPeriod'] ?? 0;
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

  // Reject borrow request
  Future<Map<String, dynamic>> rejectBorrowRequest(
      String requestId,
      String reason,
      ) async {
    try {
      final requestQuery = await _firestore
          .collection('borrow_requests')
          .where('requestId', isEqualTo: requestId)
          .limit(1)
          .get();

      if (requestQuery.docs.isEmpty) {
        return {'success': false, 'message': 'Borrow request not found'};
      }

      await requestQuery.docs.first.reference.update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': 'admin',
        'rejectionReason': reason,
      });

      return {
        'success': true,
        'message': 'Borrow request rejected.',
      };
    } catch (e) {
      print('Error rejecting borrow request: $e');
      return {
        'success': false,
        'message': 'Failed to reject borrow request: $e',
      };
    }
  }

  // Check if user can borrow (validation)
  Future<Map<String, dynamic>> validateBorrowEligibility(
      String userId,
      double borrowValue,
      AccountType accountType,
      ) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return {'eligible': false, 'reason': 'User not found'};
      }

      final userData = userDoc.data()!;

      // Check suspension
      if (userData['status'] == UserStatus.suspended.value) {
        return {'eligible': false, 'reason': 'Your account is suspended'};
      }

      // Calculate actual borrow value
      final actualBorrowValue = borrowValue * accountType.borrowMultiplier;

      // Check station limit
      final remainingLimit = userData['remainingStationLimit'] ?? 0;
      if (remainingLimit < actualBorrowValue) {
        return {
          'eligible': false,
          'reason': 'Insufficient Station Limit (Need: ${actualBorrowValue} LE, Have: ${remainingLimit} LE)',
        };
      }

      // Check borrow limit
      final currentBorrows = userData['currentBorrows'] ?? 0;
      final borrowLimit = userData['borrowLimit'] ?? 1;

      double effectiveBorrowCount = accountType.borrowLimitImpact;

      if (currentBorrows + effectiveBorrowCount > borrowLimit) {
        return {
          'eligible': false,
          'reason': 'Borrow limit reached ($currentBorrows/$borrowLimit)',
        };
      }

      // Check cooldown
      final coolDownEndDate = userData['coolDownEndDate'];
      if (coolDownEndDate != null) {
        final coolDownEnd = (coolDownEndDate as Timestamp).toDate();
        if (coolDownEnd.isAfter(DateTime.now())) {
          final daysRemaining = coolDownEnd.difference(DateTime.now()).inDays;
          return {
            'eligible': false,
            'reason': 'In cooldown period ($daysRemaining days remaining)',
          };
        }
      }

      // Check if user is a client with free borrowings
      final userTier = UserTier.fromString(userData['tier'] ?? 'user');
      if (userTier == UserTier.client) {
        final freeBorrowings = userData['freeborrowings'] ?? 0;
        return {
          'eligible': true,
          'reason': 'Eligible to borrow',
          'useFreeBorrow': freeBorrowings > 0,
          'freeBorrowingsRemaining': freeBorrowings,
        };
      }

      return {'eligible': true, 'reason': 'Eligible to borrow'};
    } catch (e) {
      print('Error validating borrow eligibility: $e');
      return {'eligible': false, 'reason': 'Error checking eligibility'};
    }
  }

  // Get borrow statistics for dashboard
  Future<Map<String, int>> getBorrowStats() async {
    try {
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

      final returned = await _firestore
          .collection('borrow_requests')
          .where('status', isEqualTo: 'returned')
          .count()
          .get();

      // Safely handle nulls using the ?? operator
      final pendingCount = pending.count ?? 0;
      final activeCount = active.count ?? 0;
      final returnedCount = returned.count ?? 0;

      return {
        'pending': pendingCount,
        'active': activeCount,
        'returned': returnedCount,
        'total': pendingCount + activeCount + returnedCount,
      };
    } catch (e) {
      print('Error getting borrow stats: $e');
      return {
        'pending': 0,
        'active': 0,
        'returned': 0,
        'total': 0,
      };
    }
  }

  // Calculate late fees if applicable
  double calculateLateFees(DateTime expectedReturnDate, double borrowValue) {
    final now = DateTime.now();
    if (now.isAfter(expectedReturnDate)) {
      final daysLate = now.difference(expectedReturnDate).inDays;
      // 5% of borrow value per day late, max 50%
      final feePercentage = (daysLate * 0.05).clamp(0, 0.5);
      return borrowValue * feePercentage;
    }
    return 0;
  }

  // Get overdue borrows (for admin notifications)
  Future<List<Map<String, dynamic>>> getOverdueBorrows() async {
    try {
      final now = DateTime.now();
      final query = await _firestore
          .collection('borrow_requests')
          .where('status', isEqualTo: 'approved')
          .get();

      List<Map<String, dynamic>> overdueBorrows = [];

      for (var doc in query.docs) {
        final data = doc.data();
        if (data['expectedReturnDate'] != null) {
          final expectedReturn = (data['expectedReturnDate'] as Timestamp).toDate();
          if (now.isAfter(expectedReturn)) {
            data['id'] = doc.id;
            data['daysOverdue'] = now.difference(expectedReturn).inDays;
            overdueBorrows.add(data);
          }
        }
      }

      return overdueBorrows;
    } catch (e) {
      print('Error getting overdue borrows: $e');
      return [];
    }
  }
}