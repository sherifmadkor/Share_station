// lib/data/models/games_vault_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum VaultGameStatus {
  funding('Funding'),
  funded('Funded'),
  available('Available'),
  soldOut('Sold Out');

  final String displayName;
  const VaultGameStatus(this.displayName);

  String get value => name;

  static VaultGameStatus fromString(String value) {
    return VaultGameStatus.values.firstWhere(
          (e) => e.name == value,
      orElse: () => VaultGameStatus.funding,
    );
  }
}

class GamesVaultModel {
  final String id;
  final String gameTitle;
  final String? coverImageUrl;
  final String? description;

  // Batch information
  final int batchNumber;
  final double targetAmount;
  final double currentFunding;

  // Contributors tracking
  final Map<String, double> contributors; // userId -> amount
  final Map<String, double> contributorShares; // userId -> percentage
  final int totalContributors;

  // Share value tracking
  final double currentShareValue;
  final double minimumShareValue;
  final bool acceptingNewShares;

  // Game details
  final List<String> platforms;
  final List<String> accountTypes;
  final String? gameId; // Reference to actual game once purchased

  // Status
  final VaultGameStatus status;
  final DateTime createdAt;
  final DateTime? fundedAt;
  final DateTime? purchasedAt;

  GamesVaultModel({
    required this.id,
    required this.gameTitle,
    this.coverImageUrl,
    this.description,
    required this.batchNumber,
    required this.targetAmount,
    required this.currentFunding,
    required this.contributors,
    required this.contributorShares,
    required this.totalContributors,
    required this.currentShareValue,
    required this.minimumShareValue,
    required this.acceptingNewShares,
    required this.platforms,
    required this.accountTypes,
    this.gameId,
    required this.status,
    required this.createdAt,
    this.fundedAt,
    this.purchasedAt,
  });

  // Calculate funding percentage
  double get fundingPercentage => (currentFunding / targetAmount) * 100;

  // Check if fully funded
  bool get isFullyFunded => currentFunding >= targetAmount;

  // Get remaining amount needed
  double get remainingAmount => targetAmount - currentFunding;

  // Calculate dynamic share value based on remaining funding
  double get dynamicShareValue {
    // If fixed share value is set, use it
    if (currentShareValue > 0) return currentShareValue;
    
    // Calculate based on remaining amount
    final remaining = remainingAmount;
    if (remaining <= 0) return minimumShareValue;
    
    // Share value decreases as funding increases (assumes 6 shares remaining)
    final baseShare = remaining / 6;
    return baseShare.clamp(minimumShareValue, double.infinity);
  }
  
  // Calculate next share value (decreasing)
  double calculateNextShareValue() {
    final nextValue = currentShareValue - 10;
    return nextValue >= minimumShareValue ? nextValue : minimumShareValue;
  }
  
  // Calculate contributor shares percentages
  Map<String, double> get contributorSharesPercentages {
    if (contributors.isEmpty || currentFunding == 0) return {};
    
    final shares = <String, double>{};
    contributors.forEach((userId, amount) {
      shares[userId] = (amount / currentFunding) * 100;
    });
    return shares;
  }
  
  // Get original contributors (excluding late contributors)
  Map<String, double> get originalContributors {
    final original = <String, double>{};
    contributors.forEach((userId, amount) {
      if (!userId.startsWith('late_')) {
        original[userId] = amount;
      }
    });
    return original;
  }
  
  // Get late contributors only
  Map<String, double> get lateContributors {
    final late = <String, double>{};
    contributors.forEach((userId, amount) {
      if (userId.startsWith('late_')) {
        late[userId] = amount;
      }
    });
    return late;
  }

  factory GamesVaultModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return GamesVaultModel(
      id: doc.id,
      gameTitle: data['gameTitle'] ?? '',
      coverImageUrl: data['coverImageUrl'],
      description: data['description'],
      batchNumber: data['batchNumber'] ?? 1,
      targetAmount: (data['targetAmount'] ?? 0).toDouble(),
      currentFunding: (data['currentFunding'] ?? 0).toDouble(),
      contributors: Map<String, double>.from(
          data['contributors']?.map((k, v) => MapEntry(k, v.toDouble())) ?? {}
      ),
      contributorShares: Map<String, double>.from(
          data['contributorShares']?.map((k, v) => MapEntry(k, v.toDouble())) ?? {}
      ),
      totalContributors: data['totalContributors'] ?? 0,
      currentShareValue: (data['currentShareValue'] ?? 250).toDouble(),
      minimumShareValue: (data['minimumShareValue'] ?? 50).toDouble(),
      acceptingNewShares: data['acceptingNewShares'] ?? true,
      platforms: List<String>.from(data['platforms'] ?? ['PS5']),
      accountTypes: List<String>.from(data['accountTypes'] ?? ['primary']),
      gameId: data['gameId'],
      status: VaultGameStatus.fromString(data['status'] ?? 'funding'),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      fundedAt: data['fundedAt'] != null
          ? (data['fundedAt'] as Timestamp).toDate()
          : null,
      purchasedAt: data['purchasedAt'] != null
          ? (data['purchasedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'gameTitle': gameTitle,
      'coverImageUrl': coverImageUrl,
      'description': description,
      'batchNumber': batchNumber,
      'targetAmount': targetAmount,
      'currentFunding': currentFunding,
      'contributors': contributors,
      'contributorShares': contributorShares,
      'totalContributors': totalContributors,
      'currentShareValue': currentShareValue,
      'minimumShareValue': minimumShareValue,
      'acceptingNewShares': acceptingNewShares,
      'platforms': platforms,
      'accountTypes': accountTypes,
      'gameId': gameId,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'fundedAt': fundedAt != null ? Timestamp.fromDate(fundedAt!) : null,
      'purchasedAt': purchasedAt != null ? Timestamp.fromDate(purchasedAt!) : null,
    };
  }
}