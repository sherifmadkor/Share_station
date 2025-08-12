// lib/services/notification_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send notification to all users about new game funding
  Future<Map<String, dynamic>> notifyNewGameFunding({
    required String gameTitle,
    required String gameId,
    required double targetAmount,
    required double shareValue,
    String? coverImageUrl,
  }) async {
    try {
      // Create notification document
      final notificationDoc = await _firestore.collection('notifications').add({
        'type': 'new_funding',
        'title': 'New Game Funding Started!',
        'body': 'Join the funding for $gameTitle - Share value: ${shareValue.toInt()} LE',
        'data': {
          'gameId': gameId,
          'gameTitle': gameTitle,
          'targetAmount': targetAmount,
          'shareValue': shareValue,
          'coverImageUrl': coverImageUrl,
          'action': 'open_fund_tab',
        },
        'targetAudience': 'all_users',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // Create individual notifications for all active users
      await _createIndividualNotifications(
        notificationId: notificationDoc.id,
        title: 'New Game Funding Started!',
        body: 'Join the funding for $gameTitle - Share value: ${shareValue.toInt()} LE',
        gameId: gameId,
        gameTitle: gameTitle,
      );

      // Push notifications can be added later if needed
      print('Notification sent to ${(await _getActiveUsersCount())} users');

      return {
        'success': true,
        'message': 'Notification sent to all users',
        'notificationId': notificationDoc.id,
      };
    } catch (e) {
      print('Error sending funding notification: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Create individual notification records for users
  Future<void> _createIndividualNotifications({
    required String notificationId,
    required String title,
    required String body,
    required String gameId,
    required String gameTitle,
  }) async {
    try {
      // Get all active users (members, VIPs, clients)
      final usersSnapshot = await _firestore
          .collection('users')
          .where('tier', whereIn: ['member', 'vip', 'client'])
          .where('status', isEqualTo: 'active')
          .get();

      final batch = _firestore.batch();
      
      for (var userDoc in usersSnapshot.docs) {
        final userNotificationRef = _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .doc(notificationId);
        
        batch.set(userNotificationRef, {
          'notificationId': notificationId,
          'title': title,
          'body': body,
          'type': 'new_funding',
          'data': {
            'gameId': gameId,
            'gameTitle': gameTitle,
            'action': 'open_fund_tab',
          },
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('Created individual notifications for ${usersSnapshot.docs.length} users');
    } catch (e) {
      print('Error creating individual notifications: $e');
    }
  }

  // Get active users count for logging
  Future<int> _getActiveUsersCount() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('tier', whereIn: ['member', 'vip', 'client'])
          .where('status', isEqualTo: 'active')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting users count: $e');
      return 0;
    }
  }

  // Get unread notifications count for a user
  Future<int> getUnreadNotificationsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .count()
          .get();
      
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting unread notifications count: $e');
      return 0;
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Get user notifications
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  // Send notification when fund is completed
  Future<void> notifyFundCompleted({
    required String gameTitle,
    required String gameId,
    required List<String> contributorIds,
  }) async {
    try {
      final batch = _firestore.batch();
      
      for (String userId in contributorIds) {
        final notificationRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc();
        
        batch.set(notificationRef, {
          'title': 'Funding Completed!',
          'body': '$gameTitle has been successfully funded and will be purchased soon',
          'type': 'funding_completed',
          'data': {
            'gameId': gameId,
            'gameTitle': gameTitle,
            'action': 'view_game',
          },
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('Sent funding completion notifications to ${contributorIds.length} contributors');
    } catch (e) {
      print('Error sending funding completion notifications: $e');
    }
  }

  // Simple notification initialization (can be expanded later)
  Future<void> initializeNotifications(String userId) async {
    try {
      // Create initial notification settings for user if needed
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notification_settings')
          .doc('preferences')
          .set({
        'funding_notifications': true,
        'completion_notifications': true,
        'general_notifications': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('Notifications initialized for user $userId');
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }
}