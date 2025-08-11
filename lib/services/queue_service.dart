// lib/services/queue_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../data/models/queue_model.dart';
import '../data/models/user_model.dart';

class QueueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  // Join queue for a specific game account slot
  Future<Map<String, dynamic>> joinQueue({
    required String userId,
    required String userName,
    required String gameId,
    required String gameTitle,
    required String accountId,
    required String platform,
    required String accountType,
    required double userTotalShares,
    String? memberId,
  }) async {
    try {
      // Check if user is already in queue for this specific slot
      final existingEntry = await _firestore
          .collection('game_queues')
          .where('userId', isEqualTo: userId)
          .where('gameId', isEqualTo: gameId)
          .where('accountId', isEqualTo: accountId)
          .where('platform', isEqualTo: platform)
          .where('accountType', isEqualTo: accountType)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (existingEntry.docs.isNotEmpty) {
        final existingData = existingEntry.docs.first.data();
        return {
          'success': false,
          'message': 'You are already in queue for this slot',
          'position': existingData['position'],
        };
      }

      // Get current active queue for this specific slot - simplified query to avoid index issues
      final queueSnapshot = await _firestore
          .collection('game_queues')
          .where('gameId', isEqualTo: gameId)
          .where('status', isEqualTo: 'active')
          .get();

      // Filter and calculate position based on the specific slot and contribution score priority
      final queueEntries = queueSnapshot.docs
          .map((doc) => doc.data())
          .where((entry) => 
              entry['accountId'] == accountId &&
              entry['platform'] == platform &&
              entry['accountType'] == accountType)
          .toList();
      
      // Sort in memory to avoid complex Firestore queries
      queueEntries.sort((a, b) {
        final aScore = (a['contributionScore'] ?? 0.0).toDouble();
        final bScore = (b['contributionScore'] ?? 0.0).toDouble();
        if (aScore != bScore) {
          return bScore.compareTo(aScore); // Higher score first
        }
        final aTime = (a['joinedAt'] as Timestamp).toDate();
        final bTime = (b['joinedAt'] as Timestamp).toDate();
        return aTime.compareTo(bTime); // Earlier time first if scores equal
      });
      
      int position = 1;
      for (var entry in queueEntries) {
        final entryScore = (entry['contributionScore'] ?? 0.0).toDouble();
        final entryJoinedAt = (entry['joinedAt'] as Timestamp).toDate();
        
        // Higher contribution score gets better position
        // If scores are equal, earlier join time gets better position
        if (entryScore > userTotalShares || 
            (entryScore == userTotalShares && entryJoinedAt.isBefore(DateTime.now()))) {
          position++;
        }
      }

      // Calculate estimated availability
      final estimatedAvailability = _calculateEstimatedAvailability(position);
      
      // Create queue entry
      final queueEntry = QueueEntry(
        id: _uuid.v4(),
        userId: userId,
        userName: userName,
        gameId: gameId,
        gameTitle: gameTitle,
        accountId: accountId,
        platform: platform,
        accountType: accountType,
        position: position,
        joinedAt: DateTime.now(),
        estimatedAvailability: estimatedAvailability,
        contributionScore: userTotalShares,
        status: 'active',
        memberId: memberId,
      );

      // Add to queue
      await _firestore.collection('game_queues').add(queueEntry.toFirestore());

      // Update positions for entries that should be after this one
      await _updateQueuePositions(gameId, accountId, platform, accountType);

      return {
        'success': true,
        'message': 'Successfully joined queue',
        'position': position,
        'estimatedDays': estimatedAvailability.difference(DateTime.now()).inDays,
      };
    } catch (e) {
      print('Error joining queue: $e');
      return {
        'success': false,
        'message': 'Failed to join queue: $e',
      };
    }
  }

  // Leave queue (cancel queue entry)
  Future<Map<String, dynamic>> leaveQueue({
    required String userId,
    required String gameId,
    required String accountId,
    required String platform,
    required String accountType,
  }) async {
    try {
      // Find user's queue entry
      final queueEntryQuery = await _firestore
          .collection('game_queues')
          .where('userId', isEqualTo: userId)
          .where('gameId', isEqualTo: gameId)
          .where('accountId', isEqualTo: accountId)
          .where('platform', isEqualTo: platform)
          .where('accountType', isEqualTo: accountType)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (queueEntryQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'Queue entry not found',
        };
      }

      // Update status to cancelled
      final entryDoc = queueEntryQuery.docs.first;
      await entryDoc.reference.update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Update positions for remaining queue entries
      await _updateQueuePositions(gameId, accountId, platform, accountType);

      return {
        'success': true,
        'message': 'Successfully left queue',
      };
    } catch (e) {
      print('Error leaving queue: $e');
      return {
        'success': false,
        'message': 'Failed to leave queue: $e',
      };
    }
  }

  // Get user's queue position for a specific slot
  Future<Map<String, dynamic>> getUserQueuePosition({
    required String userId,
    required String gameId,
    required String accountId,
    required String platform,
    required String accountType,
  }) async {
    try {
      final queueEntryQuery = await _firestore
          .collection('game_queues')
          .where('userId', isEqualTo: userId)
          .where('gameId', isEqualTo: gameId)
          .where('accountId', isEqualTo: accountId)
          .where('platform', isEqualTo: platform)
          .where('accountType', isEqualTo: accountType)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (queueEntryQuery.docs.isEmpty) {
        return {
          'inQueue': false,
          'message': 'Not in queue',
        };
      }

      final queueEntry = QueueEntry.fromFirestore(queueEntryQuery.docs.first);
      
      return {
        'inQueue': true,
        'position': queueEntry.position,
        'estimatedDays': queueEntry.daysUntilAvailable ?? 0,
        'joinedAt': queueEntry.joinedAt,
        'queueId': queueEntry.id,
      };
    } catch (e) {
      print('Error getting user queue position: $e');
      return {
        'inQueue': false,
        'error': 'Failed to get queue position: $e',
      };
    }
  }

  // Get queue summary for a game slot
  Future<QueueSummary> getQueueSummary({
    required String gameId,
    required String gameTitle,
    required String accountId,
    required String platform,
    required String accountType,
  }) async {
    try {
      final queueSnapshot = await _firestore
          .collection('game_queues')
          .where('gameId', isEqualTo: gameId)
          .where('accountId', isEqualTo: accountId)
          .where('platform', isEqualTo: platform)
          .where('accountType', isEqualTo: accountType)
          .where('status', isEqualTo: 'active')
          .orderBy('position')
          .limit(5) // Get top 5 for preview
          .get();

      final entries = queueSnapshot.docs
          .map((doc) => QueueEntry.fromFirestore(doc))
          .toList();

      // Get total count
      final totalQuery = await _firestore
          .collection('game_queues')
          .where('gameId', isEqualTo: gameId)
          .where('accountId', isEqualTo: accountId)
          .where('platform', isEqualTo: platform)
          .where('accountType', isEqualTo: accountType)
          .where('status', isEqualTo: 'active')
          .count()
          .get();

      return QueueSummary(
        gameId: gameId,
        gameTitle: gameTitle,
        totalInQueue: totalQuery.count ?? 0,
        activeInQueue: totalQuery.count ?? 0,
        nextEstimatedAvailability: entries.isNotEmpty 
            ? entries.first.estimatedAvailability 
            : null,
        topEntries: entries,
      );
    } catch (e) {
      print('Error getting queue summary: $e');
      return QueueSummary(
        gameId: gameId,
        gameTitle: gameTitle,
        totalInQueue: 0,
        activeInQueue: 0,
        topEntries: [],
      );
    }
  }

  // Process queue when a slot becomes available
  Future<Map<String, dynamic>> processQueueForAvailableSlot({
    required String gameId,
    required String accountId,
    required String platform,
    required String accountType,
  }) async {
    try {
      // Get next person in queue
      final nextInQueueQuery = await _firestore
          .collection('game_queues')
          .where('gameId', isEqualTo: gameId)
          .where('accountId', isEqualTo: accountId)
          .where('platform', isEqualTo: platform)
          .where('accountType', isEqualTo: accountType)
          .where('status', isEqualTo: 'active')
          .orderBy('position')
          .limit(1)
          .get();

      if (nextInQueueQuery.docs.isEmpty) {
        return {
          'success': true,
          'message': 'No one in queue',
          'hasNext': false,
        };
      }

      final nextEntry = QueueEntry.fromFirestore(nextInQueueQuery.docs.first);
      
      // Mark as fulfilled and create borrow request automatically
      await nextInQueueQuery.docs.first.reference.update({
        'status': 'fulfilled',
        'fulfilledAt': FieldValue.serverTimestamp(),
      });

      // Update remaining queue positions
      await _updateQueuePositions(gameId, accountId, platform, accountType);

      return {
        'success': true,
        'message': 'Queue processed successfully',
        'hasNext': true,
        'nextUser': {
          'userId': nextEntry.userId,
          'userName': nextEntry.userName,
          'memberId': nextEntry.memberId,
          'contributionScore': nextEntry.contributionScore,
        },
      };
    } catch (e) {
      print('Error processing queue: $e');
      return {
        'success': false,
        'message': 'Failed to process queue: $e',
        'hasNext': false,
      };
    }
  }

  // Get all user's active queue entries
  Stream<List<QueueEntry>> getUserActiveQueues(String userId) {
    return _firestore
        .collection('game_queues')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .orderBy('joinedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QueueEntry.fromFirestore(doc))
            .toList());
  }

  // Calculate estimated availability based on position
  DateTime _calculateEstimatedAvailability(int position) {
    // Estimate: each person ahead gets 30 days with the game
    // This is a rough estimate, can be refined based on historical data
    final daysEstimate = position * 30;
    return DateTime.now().add(Duration(days: daysEstimate));
  }

  // Update queue positions after someone joins/leaves
  Future<void> _updateQueuePositions(
    String gameId, 
    String accountId, 
    String platform, 
    String accountType,
  ) async {
    try {
      // Get all active queue entries - simplified query
      final queueSnapshot = await _firestore
          .collection('game_queues')
          .where('gameId', isEqualTo: gameId)
          .where('status', isEqualTo: 'active')
          .get();

      // Filter for specific slot in memory
      final filteredDocs = queueSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['accountId'] == accountId &&
               data['platform'] == platform &&
               data['accountType'] == accountType;
      }).toList();

      // Sort by priority in memory
      filteredDocs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aScore = (aData['contributionScore'] ?? 0.0).toDouble();
        final bScore = (bData['contributionScore'] ?? 0.0).toDouble();
        if (aScore != bScore) {
          return bScore.compareTo(aScore); // Higher score first
        }
        final aTime = (aData['joinedAt'] as Timestamp).toDate();
        final bTime = (bData['joinedAt'] as Timestamp).toDate();
        return aTime.compareTo(bTime); // Earlier time first
      });

      final batch = _firestore.batch();
      int position = 1;

      for (var doc in filteredDocs) {
        final estimatedAvailability = _calculateEstimatedAvailability(position);
        
        batch.update(doc.reference, {
          'position': position,
          'estimatedAvailability': Timestamp.fromDate(estimatedAvailability),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        position++;
      }

      await batch.commit();
    } catch (e) {
      print('Error updating queue positions: $e');
    }
  }

  // Get queue statistics for admin dashboard
  Future<Map<String, dynamic>> getQueueStatistics() async {
    try {
      final activeQueuesQuery = await _firestore
          .collection('game_queues')
          .where('status', isEqualTo: 'active')
          .count()
          .get();

      final totalQueuesQuery = await _firestore
          .collection('game_queues')
          .count()
          .get();

      // Get top games by queue length
      final queueSnapshot = await _firestore
          .collection('game_queues')
          .where('status', isEqualTo: 'active')
          .get();

      Map<String, int> gameQueueCounts = {};
      for (var doc in queueSnapshot.docs) {
        final data = doc.data();
        final gameTitle = data['gameTitle'] ?? 'Unknown';
        gameQueueCounts[gameTitle] = (gameQueueCounts[gameTitle] ?? 0) + 1;
      }

      // Sort by queue length
      final topQueuedGames = gameQueueCounts.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'totalActiveQueues': activeQueuesQuery.count ?? 0,
        'totalAllTimeQueues': totalQueuesQuery.count ?? 0,
        'topQueuedGames': topQueuedGames.take(5).map((e) => {
          'gameTitle': e.key,
          'queueLength': e.value,
        }).toList(),
      };
    } catch (e) {
      print('Error getting queue statistics: $e');
      return {
        'totalActiveQueues': 0,
        'totalAllTimeQueues': 0,
        'topQueuedGames': [],
      };
    }
  }

  // Get user's queue entries (for queue management screen)
  Future<List<Map<String, dynamic>>> getUserQueueEntries(String userId) async {
    try {
      final query = await _firestore
          .collection('game_queues')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      final results = query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add document ID
        return data;
      }).toList();

      // Sort by joinedAt in memory
      results.sort((a, b) {
        final aTime = (a['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime); // Descending
      });

      return results;
    } catch (e) {
      print('Error getting user queue entries: $e');
      return [];
    }
  }

  // Get all queue entries (for admin monitoring)
  Future<List<Map<String, dynamic>>> getAllQueueEntries() async {
    try {
      final query = await _firestore
          .collection('game_queues')
          .where('status', isEqualTo: 'active')
          .get();

      List<Map<String, dynamic>> results = [];
      
      // Process each document and fetch user details
      for (var doc in query.docs) {
        final data = doc.data();
        data['id'] = doc.id; // Add document ID
        // Add priority field for UI display
        data['priority'] = data['contributionScore'] ?? 0.0;
        
        // Get detailed user information
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(data['userId'])
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            data['userEmail'] = userData['email'] ?? 'N/A';
            data['userPhone'] = userData['phoneNumber'] ?? userData['phone'] ?? 'N/A';
            data['userTier'] = userData['tier'] ?? 'N/A';
            data['userTotalShares'] = userData['totalShares'] ?? 0;
            data['userFirstName'] = userData['firstName'] ?? '';
            data['userLastName'] = userData['lastName'] ?? '';
            data['userFullName'] = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
            
            // If userName is not set in queue, use full name from user profile
            if ((data['userName'] ?? '').isEmpty) {
              data['userName'] = data['userFullName'].isNotEmpty 
                  ? data['userFullName'] 
                  : userData['name'] ?? 'Unknown User';
            }
          } else {
            // Set defaults if user document doesn't exist
            data['userEmail'] = 'N/A';
            data['userPhone'] = 'N/A';
            data['userTier'] = 'N/A';
            data['userTotalShares'] = 0;
            data['userFullName'] = 'Unknown User';
          }
        } catch (userError) {
          print('Error fetching user details for ${data['userId']}: $userError');
          // Set defaults on error
          data['userEmail'] = 'N/A';
          data['userPhone'] = 'N/A';
          data['userTier'] = 'N/A';
          data['userTotalShares'] = 0;
        }
        
        results.add(data);
      }

      // Sort by priority in memory
      results.sort((a, b) {
        final aScore = (a['contributionScore'] ?? 0.0).toDouble();
        final bScore = (b['contributionScore'] ?? 0.0).toDouble();
        if (aScore != bScore) {
          return bScore.compareTo(aScore); // Higher score first
        }
        final aTime = (a['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return aTime.compareTo(bTime); // Earlier time first if scores equal
      });

      // Limit for performance
      return results.take(50).toList();
    } catch (e) {
      print('Error getting all queue entries: $e');
      return [];
    }
  }

  // Remove from queue by queue ID
  Future<void> removeFromQueue(String queueId) async {
    try {
      final docRef = _firestore.collection('game_queues').doc(queueId);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        throw Exception('Queue entry not found');
      }

      final queueData = docSnapshot.data()!;
      
      // Update status to cancelled
      await docRef.update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Update positions for remaining queue entries
      await _updateQueuePositions(
        queueData['gameId'],
        queueData['accountId'],
        queueData['platform'],
        queueData['accountType'],
      );
    } catch (e) {
      print('Error removing from queue: $e');
      throw Exception('Failed to remove from queue: $e');
    }
  }

  // Get queue information for a specific game slot including return estimate
  Future<Map<String, dynamic>> getSlotQueueInfo({
    required String gameId,
    required String accountId,
    required String platform,
    required String accountType,
  }) async {
    try {
      // Get current borrower information if slot is taken
      Map<String, dynamic>? currentBorrow;
      DateTime? estimatedReturnDate;
      
      // Check if slot is currently borrowed
      final borrowQuery = await _firestore
          .collection('borrow_requests')
          .where('gameId', isEqualTo: gameId)
          .where('accountId', isEqualTo: accountId)
          .where('platform', isEqualTo: platform)
          .where('accountType', isEqualTo: accountType)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();
      
      if (borrowQuery.docs.isNotEmpty) {
        final borrowData = borrowQuery.docs.first.data();
        currentBorrow = borrowData;
        
        // Calculate estimated return date (30 days from approval)
        final approvalDate = (borrowData['approvalDate'] as Timestamp?)?.toDate();
        if (approvalDate != null) {
          estimatedReturnDate = approvalDate.add(Duration(days: 30));
        }
      }
      
      // Get queue count
      final queueCount = await _firestore
          .collection('game_queues')
          .where('gameId', isEqualTo: gameId)
          .where('accountId', isEqualTo: accountId)
          .where('platform', isEqualTo: platform)
          .where('accountType', isEqualTo: accountType)
          .where('status', isEqualTo: 'active')
          .count()
          .get();
      
      return {
        'isBorrowed': currentBorrow != null,
        'currentBorrower': currentBorrow?['userName'],
        'borrowerId': currentBorrow?['userId'],
        'estimatedReturnDate': estimatedReturnDate,
        'daysUntilReturn': estimatedReturnDate != null 
            ? estimatedReturnDate.difference(DateTime.now()).inDays
            : null,
        'queueCount': queueCount.count ?? 0,
        'estimatedWaitDays': (queueCount.count ?? 0) * 30, // 30 days per person
      };
    } catch (e) {
      print('Error getting slot queue info: $e');
      return {
        'isBorrowed': false,
        'queueCount': 0,
      };
    }
  }

  // Auto-create borrow request when user reaches front of queue
  Future<Map<String, dynamic>> createBorrowRequestFromQueue({
    required String queueEntryId,
    required Map<String, dynamic> queueData,
  }) async {
    try {
      // Create borrow request with pending status for admin approval
      final borrowRequest = {
        'userId': queueData['userId'],
        'userName': queueData['userName'],
        'memberId': queueData['memberId'],
        'gameId': queueData['gameId'],
        'gameTitle': queueData['gameTitle'],
        'accountId': queueData['accountId'],
        'platform': queueData['platform'],
        'accountType': queueData['accountType'],
        'gameValue': queueData['gameValue'] ?? 0,
        'borrowValue': queueData['borrowValue'] ?? 0,
        'status': 'pending',
        'fromQueue': true,
        'queueEntryId': queueEntryId,
        'queuePosition': 1, // They were first in line
        'requestDate': FieldValue.serverTimestamp(),
        'autoCreated': true,
        'autoCreatedAt': FieldValue.serverTimestamp(),
      };
      
      final docRef = await _firestore.collection('borrow_requests').add(borrowRequest);
      
      // Update queue entry status
      await _firestore.collection('game_queues').doc(queueEntryId).update({
        'status': 'processing',
        'borrowRequestId': docRef.id,
        'processedAt': FieldValue.serverTimestamp(),
      });
      
      // Send notification to user (implement push notification here)
      // await _notificationService.sendQueueReadyNotification(queueData['userId']);
      
      return {
        'success': true,
        'borrowRequestId': docRef.id,
        'message': 'Borrow request created for user at front of queue',
      };
    } catch (e) {
      print('Error creating borrow request from queue: $e');
      return {
        'success': false,
        'message': 'Failed to create borrow request: $e',
      };
    }
  }

  // Get detailed queue information for admin
  Future<List<Map<String, dynamic>>> getAdminQueueDetails({
    required String gameId,
    String? accountId,
    String? platform,
    String? accountType,
  }) async {
    try {
      Query query = _firestore
          .collection('game_queues')
          .where('gameId', isEqualTo: gameId)
          .where('status', isEqualTo: 'active');
      
      if (accountId != null) {
        query = query.where('accountId', isEqualTo: accountId);
      }
      if (platform != null) {
        query = query.where('platform', isEqualTo: platform);
      }
      if (accountType != null) {
        query = query.where('accountType', isEqualTo: accountType);
      }
      
      final snapshot = await query.get();
      
      List<Map<String, dynamic>> queueDetails = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Get user details
        final userDoc = await _firestore
            .collection('users')
            .doc(data['userId'])
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          data['userEmail'] = userData['email'];
          data['userPhone'] = userData['phoneNumber'];
          data['userTier'] = userData['tier'];
          data['userTotalShares'] = userData['totalShares'];
        }
        
        queueDetails.add(data);
      }
      
      // Sort by position
      queueDetails.sort((a, b) => (a['position'] ?? 999).compareTo(b['position'] ?? 999));
      
      return queueDetails;
    } catch (e) {
      print('Error getting admin queue details: $e');
      return [];
    }
  }

  // Get games with active queues (for admin main queue screen)
  Future<List<Map<String, dynamic>>> getGamesWithQueues() async {
    try {
      final query = await _firestore
          .collection('game_queues')
          .where('status', isEqualTo: 'active')
          .get();

      Map<String, Map<String, dynamic>> gameGroups = {};
      
      for (var doc in query.docs) {
        final data = doc.data();
        final gameId = data['gameId'];
        final gameTitle = data['gameTitle'] ?? 'Unknown Game';
        
        if (!gameGroups.containsKey(gameId)) {
          gameGroups[gameId] = {
            'gameId': gameId,
            'gameTitle': gameTitle,
            'totalQueue': 0,
            'accounts': <String, Map<String, dynamic>>{},
          };
        }
        
        // Group by account and platform
        final accountKey = '${data['accountId']}_${data['platform']}_${data['accountType']}';
        final accountInfo = '${data['platform']?.toUpperCase()} - ${data['accountType']}';
        
        if (!gameGroups[gameId]!['accounts'].containsKey(accountKey)) {
          gameGroups[gameId]!['accounts'][accountKey] = {
            'accountId': data['accountId'],
            'platform': data['platform'],
            'accountType': data['accountType'],
            'displayName': accountInfo,
            'queueCount': 0,
          };
        }
        
        gameGroups[gameId]!['totalQueue']++;
        gameGroups[gameId]!['accounts'][accountKey]['queueCount']++;
      }
      
      final result = gameGroups.values.map((game) {
        game['accountsList'] = (game['accounts'] as Map).values.toList();
        game.remove('accounts');
        return game;
      }).toList();
      
      // Sort by total queue count descending
      result.sort((a, b) => (b['totalQueue'] as int).compareTo(a['totalQueue'] as int));
      
      return result;
    } catch (e) {
      print('Error getting games with queues: $e');
      return [];
    }
  }

  // Reorder queue (admin only)
  Future<Map<String, dynamic>> reorderQueue({
    required String queueEntryId,
    required int newPosition,
    required String gameId,
    required String accountId,
    required String platform,
    required String accountType,
  }) async {
    try {
      // Get all active queue entries for this slot
      final queueSnapshot = await _firestore
          .collection('game_queues')
          .where('gameId', isEqualTo: gameId)
          .where('accountId', isEqualTo: accountId)
          .where('platform', isEqualTo: platform)
          .where('accountType', isEqualTo: accountType)
          .where('status', isEqualTo: 'active')
          .orderBy('position')
          .get();
      
      final batch = _firestore.batch();
      final entries = queueSnapshot.docs;
      
      // Find the entry to move
      final entryToMove = entries.firstWhere((doc) => doc.id == queueEntryId);
      final oldPosition = (entryToMove.data() as Map<String, dynamic>)['position'];
      
      // Reorder entries
      for (var doc in entries) {
        final currentPos = (doc.data() as Map<String, dynamic>)['position'];
        int updatedPos = currentPos;
        
        if (doc.id == queueEntryId) {
          updatedPos = newPosition;
        } else if (oldPosition < newPosition && currentPos > oldPosition && currentPos <= newPosition) {
          updatedPos = currentPos - 1;
        } else if (oldPosition > newPosition && currentPos >= newPosition && currentPos < oldPosition) {
          updatedPos = currentPos + 1;
        }
        
        if (updatedPos != currentPos) {
          batch.update(doc.reference, {
            'position': updatedPos,
            'estimatedAvailability': Timestamp.fromDate(
              DateTime.now().add(Duration(days: updatedPos * 30))
            ),
            'updatedAt': FieldValue.serverTimestamp(),
            'reorderedBy': 'admin',
          });
        }
      }
      
      await batch.commit();
      
      return {
        'success': true,
        'message': 'Queue reordered successfully',
      };
    } catch (e) {
      print('Error reordering queue: $e');
      return {
        'success': false,
        'message': 'Failed to reorder queue: $e',
      };
    }
  }
}