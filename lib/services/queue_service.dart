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

      // Get current active queue for this specific slot, ordered by priority
      final queueSnapshot = await _firestore
          .collection('game_queues')
          .where('gameId', isEqualTo: gameId)
          .where('accountId', isEqualTo: accountId)
          .where('platform', isEqualTo: platform)
          .where('accountType', isEqualTo: accountType)
          .where('status', isEqualTo: 'active')
          .orderBy('contributionScore', descending: true)
          .orderBy('joinedAt', descending: false)
          .get();

      // Calculate position based on contribution score priority
      int position = 1;
      final queueEntries = queueSnapshot.docs.map((doc) => doc.data()).toList();
      
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
      // Get all active queue entries ordered by priority
      final queueSnapshot = await _firestore
          .collection('game_queues')
          .where('gameId', isEqualTo: gameId)
          .where('accountId', isEqualTo: accountId)
          .where('platform', isEqualTo: platform)
          .where('accountType', isEqualTo: accountType)
          .where('status', isEqualTo: 'active')
          .orderBy('contributionScore', descending: true)
          .orderBy('joinedAt', descending: false)
          .get();

      final batch = _firestore.batch();
      int position = 1;

      for (var doc in queueSnapshot.docs) {
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
          .orderBy('joinedAt', descending: true)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add document ID
        return data;
      }).toList();
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
          .orderBy('contributionScore', descending: true)
          .orderBy('joinedAt', descending: false)
          .limit(50) // Limit for performance
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add document ID
        // Add priority field for UI display
        data['priority'] = data['contributionScore'] ?? 0.0;
        return data;
      }).toList();
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
}