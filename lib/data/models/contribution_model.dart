// lib/data/models/contribution_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum ContributionType {
  game('Game'),
  fund('Fund');

  final String displayName;
  const ContributionType(this.displayName);

  String get value {
    switch (this) {
      case ContributionType.game:
        return 'game';
      case ContributionType.fund:
        return 'fund';
    }
  }

  static ContributionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'game':
        return ContributionType.game;
      case 'fund':
        return ContributionType.fund;
      default:
        return ContributionType.game;
    }
  }
}

enum ContributionStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  final String displayName;
  const ContributionStatus(this.displayName);

  String get value {
    switch (this) {
      case ContributionStatus.pending:
        return 'pending';
      case ContributionStatus.approved:
        return 'approved';
      case ContributionStatus.rejected:
        return 'rejected';
    }
  }

  static ContributionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return ContributionStatus.pending;
      case 'approved':
        return ContributionStatus.approved;
      case 'rejected':
        return ContributionStatus.rejected;
      default:
        return ContributionStatus.pending;
    }
  }
}

class ContributionModel {
  final String id;
  final ContributionType type;
  final ContributionStatus status;

  // Contributor Info
  final String contributorId;
  final String contributorName;
  final String contributorMemberId;

  // Game Contribution Fields
  final String? gameTitle;
  final String? platform;
  final String? accountType;
  final String? email;
  final String? password;
  final String? region;
  final String? edition;
  final double? gameValue;
  final String? description;
  final List<String>? includedTitles;

  // Fund Contribution Fields
  final double? fundAmount;
  final String? paymentMethod;
  final String? receiptUrl;
  final String? targetGameTitle;

  // Status & Tracking
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? approvedBy;
  final String? rejectedBy;
  final String? rejectionReason;

  // Impact on User Metrics (calculated after approval)
  final double? stationLimitImpact;
  final double? balanceImpact;
  final int? shareCountImpact;

  ContributionModel({
    required this.id,
    required this.type,
    required this.status,
    required this.contributorId,
    required this.contributorName,
    required this.contributorMemberId,
    this.gameTitle,
    this.platform,
    this.accountType,
    this.email,
    this.password,
    this.region,
    this.edition,
    this.gameValue,
    this.description,
    this.includedTitles,
    this.fundAmount,
    this.paymentMethod,
    this.receiptUrl,
    this.targetGameTitle,
    required this.createdAt,
    this.approvedAt,
    this.rejectedAt,
    this.approvedBy,
    this.rejectedBy,
    this.rejectionReason,
    this.stationLimitImpact,
    this.balanceImpact,
    this.shareCountImpact,
  });

  // Calculate the impact on user metrics based on contribution type
  Map<String, dynamic> calculateUserMetricsImpact() {
    Map<String, dynamic> impact = {
      'stationLimit': 0.0,
      'balance': 0.0,
      'gameShares': 0,
      'fundShares': 0,
      'totalShares': 0,
    };

    if (type == ContributionType.game && gameValue != null) {
      // Game contribution impact
      impact['stationLimit'] = gameValue!;
      impact['balance'] = gameValue! * 0.7; // 70% to balance
      impact['gameShares'] = 1;
      impact['totalShares'] = 1;

      // Account type multiplier for shares
      switch (accountType?.toLowerCase()) {
        case 'secondary':
          impact['gameShares'] = 0.5;
          impact['totalShares'] = 0.5;
          break;
        case 'psplus':
          impact['gameShares'] = 2;
          impact['totalShares'] = 2;
          break;
      }
    } else if (type == ContributionType.fund && fundAmount != null) {
      // Fund contribution impact
      impact['fundShares'] = (fundAmount! / 100).round(); // 1 share per 100 LE
      impact['totalShares'] = impact['fundShares'];
      // Fund contributions get refunded to balance when game is purchased
    }

    return impact;
  }

  // Factory constructor from Firestore
  factory ContributionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return ContributionModel(
      id: doc.id,
      type: ContributionType.fromString(data['type'] ?? 'game'),
      status: ContributionStatus.fromString(data['status'] ?? 'pending'),
      contributorId: data['contributorId'] ?? '',
      contributorName: data['contributorName'] ?? '',
      contributorMemberId: data['contributorMemberId'] ?? '',
      gameTitle: data['gameTitle'],
      platform: data['platform'],
      accountType: data['accountType'],
      email: data['email'],
      password: data['password'],
      region: data['region'],
      edition: data['edition'],
      gameValue: data['gameValue']?.toDouble(),
      description: data['description'],
      includedTitles: data['includedTitles'] != null
          ? List<String>.from(data['includedTitles'])
          : null,
      fundAmount: data['fundAmount']?.toDouble(),
      paymentMethod: data['paymentMethod'],
      receiptUrl: data['receiptUrl'],
      targetGameTitle: data['targetGameTitle'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      rejectedAt: data['rejectedAt'] != null
          ? (data['rejectedAt'] as Timestamp).toDate()
          : null,
      approvedBy: data['approvedBy'],
      rejectedBy: data['rejectedBy'],
      rejectionReason: data['rejectionReason'],
      stationLimitImpact: data['stationLimitImpact']?.toDouble(),
      balanceImpact: data['balanceImpact']?.toDouble(),
      shareCountImpact: data['shareCountImpact']?.toInt(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.value,
      'status': status.value,
      'contributorId': contributorId,
      'contributorName': contributorName,
      'contributorMemberId': contributorMemberId,
      'gameTitle': gameTitle,
      'platform': platform,
      'accountType': accountType,
      'email': email,
      'password': password,
      'region': region,
      'edition': edition,
      'gameValue': gameValue,
      'description': description,
      'includedTitles': includedTitles,
      'fundAmount': fundAmount,
      'paymentMethod': paymentMethod,
      'receiptUrl': receiptUrl,
      'targetGameTitle': targetGameTitle,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'approvedBy': approvedBy,
      'rejectedBy': rejectedBy,
      'rejectionReason': rejectionReason,
      'stationLimitImpact': stationLimitImpact,
      'balanceImpact': balanceImpact,
      'shareCountImpact': shareCountImpact,
    };
  }
}