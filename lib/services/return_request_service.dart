// lib/services/return_request_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'queue_service.dart';

class ReturnRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final QueueService _queueService = QueueService();

  // Get all pending return requests (for admin) - FIXED
  Stream<QuerySnapshot> getPendingReturnRequests() {
    return _firestore
        .collection('return_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();  // Removed orderBy to avoid index issues
  }

  // Alternative method with error handling
  Stream<List<Map<String, dynamic>>> getPendingReturnRequestsWithData() {
    return _firestore
        .collection('return_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      // Sort in memory after fetching
      final docs = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID to data
        return data;
      }).toList();

      // Sort by createdAt if it exists, otherwise by current time
      docs.sort((a, b) {
        final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate); // Descending order
      });

      return docs;
    });
  }

  // Get return request statistics
  Future<Map<String, dynamic>> getReturnStatistics() async {
    try {
      final pending = await _firestore
          .collection('return_requests')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      final approved = await _firestore
          .collection('return_requests')
          .where('status', isEqualTo: 'approved')
          .count()
          .get();

      final rejected = await _firestore
          .collection('return_requests')
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
      print('Error getting return statistics: $e');
      return {
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total': 0,
      };
    }
  }

  // Approve return request and make slot available again
  Future<Map<String, dynamic>> approveReturnRequest(String returnRequestId) async {
    try {
      final batch = _firestore.batch();

      // Get the return request
      final returnDoc = await _firestore
          .collection('return_requests')
          .doc(returnRequestId)
          .get();

      if (!returnDoc.exists) {
        return {'success': false, 'message': 'Return request not found'};
      }

      final returnData = returnDoc.data()!;
      final borrowId = returnData['borrowId'];
      final gameId = returnData['gameId'];
      final userId = returnData['userId'];
      final borrowValue = (returnData['borrowValue'] ?? 0).toDouble();

      // Get the original borrow request
      final borrowDoc = await _firestore
          .collection('borrow_requests')
          .doc(borrowId)
          .get();

      if (!borrowDoc.exists) {
        return {'success': false, 'message': 'Original borrow request not found'};
      }

      final borrowData = borrowDoc.data()!;

      // Extract account details - handle different field names
      final accountId = borrowData['accountId'] ?? '';
      final platform = borrowData['platform'] ?? 'ps4';
      final accountType = borrowData['accountType'] ?? 'primary';

      // Calculate hold period
      final borrowDate = (borrowData['approvedAt'] as Timestamp?)?.toDate() ??
          (borrowData['approvalDate'] as Timestamp?)?.toDate() ??
          (borrowData['requestDate'] as Timestamp?)?.toDate() ??
          DateTime.now();
      final holdPeriod = DateTime.now().difference(borrowDate).inDays;

      // Update return request status
      batch.update(returnDoc.reference, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin', // You can pass actual admin ID
        'holdPeriod': holdPeriod,
      });

      // Update borrow request to returned
      batch.update(borrowDoc.reference, {
        'status': 'returned',
        'returnedAt': FieldValue.serverTimestamp(),
        'holdPeriod': holdPeriod,
      });

      // Update game slot to make it available again
      int accountIndex = -1; // Declare accountIndex outside the if block
      final gameDoc = await _firestore.collection('games').doc(gameId).get();

      if (gameDoc.exists) {
        final gameData = gameDoc.data()!;
        final accounts = List<Map<String, dynamic>>.from(gameData['accounts'] ?? []);

        // Find the account
        accountIndex = accountId.isNotEmpty
            ? accounts.indexWhere((acc) => acc['accountId'] == accountId)
            : -1;

        if (accountIndex != -1) {
          final slotKey = '${platform}_${accountType}';

          // Reset the slot to available
          if (accounts[accountIndex]['slots'] != null) {
            accounts[accountIndex]['slots'][slotKey] = {
              'platform': platform,
              'accountType': accountType,
              'status': 'available',
              'borrowerId': null,
              'borrowerName': null,
              'borrowDate': null,
              'expectedReturnDate': null,
            };
          }

          // Update game document
          batch.update(gameDoc.reference, {
            'accounts': accounts,
            'availableAccounts': FieldValue.increment(1),
            'currentBorrows': FieldValue.increment(-1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          print('Warning: Account not found in game document for accountId: $accountId');
        }
      }

      // Update user metrics
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        // Calculate borrow count based on account type
        double borrowCount = _getBorrowCountForAccountType(accountType);

        // Update average hold period safely
        final totalBorrows = (userData['totalBorrowsCount'] ?? 1).toInt();
        final currentAverage = (userData['averageHoldPeriod'] ?? 0).toDouble();
        final newAverage = totalBorrows > 1
            ? ((currentAverage * (totalBorrows - 1)) + holdPeriod) / totalBorrows
            : holdPeriod.toDouble();

        batch.update(userRef, {
          'currentBorrows': FieldValue.increment(-borrowCount),
          'remainingStationLimit': FieldValue.increment(borrowValue),
          'averageHoldPeriod': newAverage,
          'lastReturnDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Create a history entry
      batch.set(_firestore.collection('borrow_history').doc(), {
        'borrowId': borrowId,
        'returnRequestId': returnRequestId,
        'gameId': gameId,
        'gameTitle': returnData['gameTitle'] ?? 'Unknown Game',
        'userId': userId,
        'userName': returnData['userName'] ?? 'Unknown User',
        'platform': platform,
        'accountType': accountType,
        'borrowValue': borrowValue,
        'borrowDate': borrowDate,
        'returnDate': FieldValue.serverTimestamp(),
        'holdPeriod': holdPeriod,
        'status': 'returned',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Commit all updates
      await batch.commit();

      // Process queue for the newly available slot (only if we found the account)
      if (accountId.isNotEmpty && accountIndex != -1) {
        await _processQueueForAvailableSlot(gameId, accountId, platform, accountType);
      }

      return {
        'success': true,
        'message': 'Return approved successfully! Game is now available.',
        'holdPeriod': holdPeriod,
      };
    } catch (e) {
      print('Error approving return request: $e');
      return {
        'success': false,
        'message': 'Failed to approve return: $e',
      };
    }
  }

  // Reject return request
  Future<Map<String, dynamic>> rejectReturnRequest(
      String returnRequestId,
      [String reason = 'Rejected by admin']
      ) async {
    try {
      await _firestore.collection('return_requests').doc(returnRequestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': 'admin',
        'rejectionReason': reason,
      });

      return {
        'success': true,
        'message': 'Return request rejected',
      };
    } catch (e) {
      print('Error rejecting return request: $e');
      return {
        'success': false,
        'message': 'Failed to reject return request: $e',
      };
    }
  }

  // Process queue for newly available slot
  Future<void> _processQueueForAvailableSlot(
      String gameId,
      String accountId,
      String platform,
      String accountType,
      ) async {
    try {
      // Use the queue service to process the available slot
      final queueResult = await _queueService.processQueueForAvailableSlot(
        gameId: gameId,
        accountId: accountId,
        platform: platform,
        accountType: accountType,
      );

      if (queueResult['hasNext'] == true) {
        final nextUser = queueResult['nextUser'] as Map<String, dynamic>?;
        
        if (nextUser != null) {
          // Auto-create borrow request for the next person in queue
          final queueEntry = await _firestore
              .collection('game_queues')
              .where('userId', isEqualTo: nextUser['userId'])
              .where('gameId', isEqualTo: gameId)
              .where('status', isEqualTo: 'fulfilled')
              .limit(1)
              .get();
          
          if (queueEntry.docs.isNotEmpty) {
            await _queueService.createBorrowRequestFromQueue(
              queueEntryId: queueEntry.docs.first.id,
              queueData: {
                ...nextUser,
                'gameId': gameId,
                'gameTitle': 'Game Title', // You might want to get this from the game document
                'accountId': accountId,
                'platform': platform,
                'accountType': accountType,
                'gameValue': 0, // You might want to get this from the game document
                'borrowValue': 0, // Calculate based on account type and user tier
              },
            );
          }
        }
      }
    } catch (e) {
      print('Error processing queue: $e');
    }
  }

  // Get all return requests history - FIXED
  Stream<QuerySnapshot> getReturnHistory() {
    return _firestore
        .collection('return_requests')
        .where('status', whereIn: ['approved', 'rejected'])
        .snapshots();  // Removed orderBy to avoid index issues
  }

  // Helper method to get borrow count impact based on account type
  double _getBorrowCountForAccountType(String accountType) {
    switch (accountType.toLowerCase()) {
      case 'primary':
        return 1.0; // Primary accounts count as 1 full borrow
      case 'secondary':
        return 0.5; // Secondary accounts count as 0.5 borrow
      case 'full':
        return 1.0; // Full accounts count as 1 borrow
      case 'psplus':
      case 'ps_plus':
        return 0.5; // PS Plus accounts count as 0.5 borrow
      default:
        return 1.0; // Default to primary if unknown
    }
  }
}