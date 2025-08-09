// lib/data/models/queue_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// Queue Entry Model for managing game borrowing queues
class QueueEntry {
  final String id;
  final String userId;
  final String userName;
  final String gameId;
  final String gameTitle;
  final String accountId; // Specific account being queued for
  final String platform;
  final String accountType;
  final int position;
  final DateTime joinedAt;
  final DateTime? estimatedAvailability;
  final double contributionScore; // Priority based on total contributions
  final String status; // 'active', 'cancelled', 'fulfilled'
  final String? memberId; // User's 3-digit member ID for display
  
  QueueEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.gameId,
    required this.gameTitle,
    required this.accountId,
    required this.platform,
    required this.accountType,
    required this.position,
    required this.joinedAt,
    this.estimatedAvailability,
    required this.contributionScore,
    required this.status,
    this.memberId,
  });

  // Calculate days until estimated availability
  int? get daysUntilAvailable {
    if (estimatedAvailability == null) return null;
    final diff = estimatedAvailability!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  // Check if queue entry is active
  bool get isActive => status == 'active';

  // Factory constructor from Firestore document
  factory QueueEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return QueueEntry(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      gameId: data['gameId'] ?? '',
      gameTitle: data['gameTitle'] ?? '',
      accountId: data['accountId'] ?? '',
      platform: data['platform'] ?? '',
      accountType: data['accountType'] ?? '',
      position: data['position'] ?? 0,
      joinedAt: data['joinedAt'] != null
          ? (data['joinedAt'] as Timestamp).toDate()
          : DateTime.now(),
      estimatedAvailability: data['estimatedAvailability'] != null
          ? (data['estimatedAvailability'] as Timestamp).toDate()
          : null,
      contributionScore: (data['contributionScore'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'active',
      memberId: data['memberId'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'gameId': gameId,
      'gameTitle': gameTitle,
      'accountId': accountId,
      'platform': platform,
      'accountType': accountType,
      'position': position,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'estimatedAvailability': estimatedAvailability != null
          ? Timestamp.fromDate(estimatedAvailability!)
          : null,
      'contributionScore': contributionScore,
      'status': status,
      'memberId': memberId,
    };
  }

  // Copy with method for updates
  QueueEntry copyWith({
    String? id,
    String? userId,
    String? userName,
    String? gameId,
    String? gameTitle,
    String? accountId,
    String? platform,
    String? accountType,
    int? position,
    DateTime? joinedAt,
    DateTime? estimatedAvailability,
    double? contributionScore,
    String? status,
    String? memberId,
  }) {
    return QueueEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      gameId: gameId ?? this.gameId,
      gameTitle: gameTitle ?? this.gameTitle,
      accountId: accountId ?? this.accountId,
      platform: platform ?? this.platform,
      accountType: accountType ?? this.accountType,
      position: position ?? this.position,
      joinedAt: joinedAt ?? this.joinedAt,
      estimatedAvailability: estimatedAvailability ?? this.estimatedAvailability,
      contributionScore: contributionScore ?? this.contributionScore,
      status: status ?? this.status,
      memberId: memberId ?? this.memberId,
    );
  }
}

// Queue Summary for displaying queue statistics
class QueueSummary {
  final String gameId;
  final String gameTitle;
  final int totalInQueue;
  final int activeInQueue;
  final DateTime? nextEstimatedAvailability;
  final List<QueueEntry> topEntries; // First few entries for preview

  QueueSummary({
    required this.gameId,
    required this.gameTitle,
    required this.totalInQueue,
    required this.activeInQueue,
    this.nextEstimatedAvailability,
    required this.topEntries,
  });

  // Check if queue is empty
  bool get isEmpty => totalInQueue == 0;

  // Get estimated wait time for new users
  int get estimatedWaitDays {
    if (isEmpty) return 0;
    return totalInQueue * 30; // 30 days per position estimate
  }
}