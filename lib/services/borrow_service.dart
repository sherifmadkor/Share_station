// lib/services/borrow_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
// Import with prefix to avoid conflicts
import '../data/models/game_model.dart' as game_models;
import '../data/models/user_model.dart';
import 'suspension_service.dart';
import 'queue_service.dart';
import 'points_service.dart';
import 'referral_service.dart';
import 'metrics_service.dart';

class BorrowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();
  final SuspensionService _suspensionService = SuspensionService();
  final QueueService _queueService = QueueService();
  final PointsService _pointsService = PointsService();
  final ReferralService _referralService = ReferralService();
  final MetricsService _metricsService = MetricsService();

  // RESERVATION WINDOW & COOLDOWN METHODS

  // Get next Thursday date (reservation window)
  DateTime getNextThursday([DateTime? from]) {
    final now = from ?? DateTime.now();
    final daysUntilThursday = (DateTime.thursday - now.weekday) % 7;
    final nextThursday = now.add(Duration(days: daysUntilThursday == 0 ? 7 : daysUntilThursday));
    return DateTime(nextThursday.year, nextThursday.month, nextThursday.day, 0, 0, 0);
  }

  // Check if today is reservation window (Thursday)
  bool isReservationWindow() {
    return DateTime.now().weekday == DateTime.thursday;
  }

  // Check if borrow window is open (admin controlled)
  Future<bool> isBorrowWindowOpen() async {
    try {
      final doc = await _firestore
          .collection('settings')
          .doc('borrow_window')
          .get();
      
      if (doc.exists) {
        return doc.data()?['isOpen'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking borrow window status: $e');
      return false;
    }
  }

  // Check if user is in cooldown period
  bool isUserInCooldown(Map<String, dynamic> userData) {
    final coolDownEndDate = userData['coolDownEndDate'];
    if (coolDownEndDate == null) return false;
    
    final coolDownEnd = (coolDownEndDate as Timestamp).toDate();
    return coolDownEnd.isAfter(DateTime.now());
  }

  // Calculate actual borrow value based on account type
  double calculateActualBorrowValue(double gameValue, String accountType) {
    switch (accountType.toLowerCase()) {
      case 'secondary':
        return gameValue * 0.75; // 75% for secondary accounts
      case 'psplus':
      case 'ps_plus':
        return gameValue * 2.0; // 200% for PS Plus accounts
      case 'primary':
      case 'full':
      default:
        return gameValue; // 100% for primary/full accounts
    }
  }

  // Get reservation window status for UI
  Future<Map<String, dynamic>> getReservationWindowStatus() async {
    final now = DateTime.now();
    final isThursday = now.weekday == DateTime.thursday;
    final nextThursday = getNextThursday();
    final daysUntilThursday = nextThursday.difference(now).inDays;
    final isBorrowWindowOpenStatus = await isBorrowWindowOpen();

    return {
      'isReservationWindow': isThursday,
      'isBorrowWindowOpen': isBorrowWindowOpenStatus,
      'nextThursday': nextThursday,
      'daysUntilThursday': daysUntilThursday,
      'canSubmitRequests': isThursday && isBorrowWindowOpenStatus,
    };
  }

  // Get user's cooldown status
  Future<Map<String, dynamic>> getUserCooldownStatus(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return {'error': 'User not found'};
      }

      final userData = userDoc.data()!;
      final coolDownEndDate = userData['coolDownEndDate'];
      final coolDownEligible = userData['coolDownEligible'] ?? true;

      if (coolDownEndDate == null) {
        return {
          'inCooldown': false,
          'cooldownEligible': coolDownEligible,
          'message': coolDownEligible ? 'No cooldown' : 'Cooldown eligible but not active',
        };
      }

      final coolDownEnd = (coolDownEndDate as Timestamp).toDate();
      final now = DateTime.now();
      final inCooldown = coolDownEnd.isAfter(now);

      if (inCooldown) {
        final daysRemaining = coolDownEnd.difference(now).inDays;
        final hoursRemaining = coolDownEnd.difference(now).inHours % 24;
        
        return {
          'inCooldown': true,
          'cooldownEligible': false,
          'cooldownEndDate': coolDownEnd,
          'daysRemaining': daysRemaining,
          'hoursRemaining': hoursRemaining,
          'message': 'Cooldown active until ${coolDownEnd.day}/${coolDownEnd.month}/${coolDownEnd.year}',
        };
      } else {
        return {
          'inCooldown': false,
          'cooldownEligible': true,
          'message': 'Cooldown expired, eligible for borrowing',
        };
      }
    } catch (e) {
      return {'error': 'Failed to get cooldown status: $e'};
    }
  }

  // Submit a borrow request
  Future<Map<String, dynamic>> submitBorrowRequest({
    required String userId,
    required String userName,
    required String gameId,
    required String gameTitle,
    required String accountId,
    required game_models.Platform platform,
    required game_models.AccountType accountType,
    required double borrowValue,// This is the game's value
    required String memberId,
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

      // Check if borrow window is open (admin control)
      final isBorrowWindowOpenStatus = await isBorrowWindowOpen();
      if (!isBorrowWindowOpenStatus) {
        return {
          'success': false,
          'message': 'Borrowing is currently disabled. Please try again when the borrow window is open.',
        };
      }

      // Check reservation window (Thursday only for most users)
      final isReservationDay = isReservationWindow();
      final coolDownEligible = userData['coolDownEligible'] ?? true;
      
      if (!isReservationDay && !coolDownEligible) {
        final nextThursday = getNextThursday();
        final daysUntilThursday = nextThursday.difference(DateTime.now()).inDays;
        return {
          'success': false,
          'message': 'You can only submit borrow requests on Thursdays. Next reservation window is in $daysUntilThursday days.',
        };
      }

      // Check cooldown status
      if (isUserInCooldown(userData)) {
        final coolDownEndDate = userData['coolDownEndDate'] as Timestamp;
        final coolDownEnd = coolDownEndDate.toDate();
        final daysRemaining = coolDownEnd.difference(DateTime.now()).inDays;
        return {
          'success': false,
          'message': 'You are in cooldown period. You can borrow again on ${coolDownEnd.day}/${coolDownEnd.month} (${daysRemaining} days).',
        };
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

      // Update user activity
      await _suspensionService.checkAndApplySuspensions();

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

      // Calculate actual borrow value based on account type
      final gameValue = (data['gameValue'] ?? data['borrowValue']).toDouble();
      final accountTypeStr = data['accountType'].toString();
      final actualBorrowValue = calculateActualBorrowValue(gameValue, accountTypeStr);

      // Update request status
      batch.update(requestDoc.reference, {
        'status': 'approved',
        'approvalDate': FieldValue.serverTimestamp(),
        'approvedBy': 'admin', // You can pass actual admin ID
        'actualBorrowValue': actualBorrowValue,
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

      // Update user metrics with actual borrow value and cooldown
      final nextThursday = getNextThursday();
      
      batch.update(userRef, {
        'currentBorrows': FieldValue.increment(borrowCount),
        'totalBorrowsCount': FieldValue.increment(1),
        'remainingStationLimit': FieldValue.increment(-actualBorrowValue),
        'netBorrowings': FieldValue.increment(actualBorrowValue),
        'points': FieldValue.increment(actualBorrowValue.round()), // 1 point per LE
        'expensePoints': FieldValue.increment(actualBorrowValue.round()),
        'lastActivityDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Set cooldown until next Thursday (reservation window)
        'coolDownEligible': false,
        'coolDownEndDate': Timestamp.fromDate(nextThursday),
      });

      // Update contributor's lending metrics
      if (contributorId != null && contributorId != data['userId']) {
        final contributorRef = _firestore.collection('users').doc(contributorId);
        batch.update(contributorRef, {
          'netLending': FieldValue.increment(actualBorrowValue),
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
        'gameValue': data['gameValue'] ?? data['borrowValue'], // Original game value
        'borrowValue': actualBorrowValue, // Calculated borrow value
        'status': 'active',
        'borrowDate': FieldValue.serverTimestamp(),
        'expectedReturnDate': Timestamp.fromDate(
          DateTime.now().add(Duration(days: 30)),
        ),
      };

      batch.set(_firestore.collection('borrow_history').doc(), historyData);

      await batch.commit();

      // Award points for spending (using points service for proper logging)
      await _pointsService.awardSpendingPoints(
        userId: data['userId'],
        amountSpent: actualBorrowValue,
        description: 'Borrowing: ${data['gameTitle']}',
      );

      // Process referral earnings for this transaction
      await _referralService.processActivityReferralEarnings(
        userId: data['userId'],
        transactionAmount: actualBorrowValue,
        activityType: 'borrow',
        activityDescription: 'Game borrowing: ${data['gameTitle']}',
      );

      // Get user data for metrics processing
      final borrowerDoc = await _firestore.collection('users').doc(data['userId']).get();
      final borrowerData = borrowerDoc.exists ? borrowerDoc.data()! : {};

      // Process metrics
      await _metricsService.processBorrowMetrics(
        borrowerId: data['userId'],
        lenderId: contributorId,
        borrowerTier: borrowerData['tier'] ?? 'member',
        lenderTier: 'member', // Assuming member-contributed games
        borrowValue: actualBorrowValue,
        freeborrowingsRemaining: borrowerData['freeborrowings'] ?? 0,
      );

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

      // Update average hold period metrics
      await _metricsService.updateAverageHoldPeriod(
        userId: data['userId'],
        daysHeld: holdPeriod,
      );

      // Process queue for the newly available slot
      await _queueService.processQueueForAvailableSlot(
        gameId: data['gameId'],
        accountId: data['accountId'],
        platform: data['platform'],
        accountType: data['accountType'],
      );

      // Update user activity
      await _suspensionService.updateLastContribution(data['userId']);

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