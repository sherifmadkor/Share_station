// lib/data/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// User Tier enum with permissions
enum UserTier {
  admin('Admin'),
  vip('VIP Member'),
  member('Member'),
  client('Client'),
  user('User');

  final String displayName;
  const UserTier(this.displayName);

  String get value {
    switch (this) {
      case UserTier.admin:
        return 'admin';
      case UserTier.vip:
        return 'vip';
      case UserTier.member:
        return 'member';
      case UserTier.client:
        return 'client';
      case UserTier.user:
        return 'user';
    }
  }

  static UserTier fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserTier.admin;
      case 'vip':
        return UserTier.vip;
      case 'member':
        return UserTier.member;
      case 'client':
        return UserTier.client;
      case 'user':
      default:
        return UserTier.user;
    }
  }

  // Permissions and limits
  bool get canWithdrawBalance => this == UserTier.vip;
  bool get isPermanent => this == UserTier.admin || this == UserTier.vip || this == UserTier.member;
  bool get needsRenewal => this == UserTier.client;
  bool get payPerUse => this == UserTier.user;

  // Borrow limits
  int get maxSimultaneousBorrows {
    switch (this) {
      case UserTier.admin:
        return 10; // Admin can borrow more
      case UserTier.vip:
        return 5;
      case UserTier.member:
        return 4; // Based on contributions
      case UserTier.client:
        return 10; // But limited by free borrowings
      case UserTier.user:
        return 1; // Pay per use
    }
  }

  // Subscription fees
  double get subscriptionFee {
    switch (this) {
      case UserTier.admin:
        return 0;
      case UserTier.vip:
        return 0; // Already paid member fee
      case UserTier.member:
        return 1500;
      case UserTier.client:
        return 750;
      case UserTier.user:
        return 0; // Pay per use
    }
  }
}

// Platform preference
enum Platform {
  ps4('PS4'),
  ps5('PS5'),
  both('Both');

  final String displayName;
  const Platform(this.displayName);

  String get value {
    switch (this) {
      case Platform.ps4:
        return 'ps4';
      case Platform.ps5:
        return 'ps5';
      case Platform.both:
        return 'both';
    }
  }

  static Platform fromString(String value) {
    switch (value.toLowerCase()) {
      case 'ps4':
        return Platform.ps4;
      case 'ps5':
        return Platform.ps5;
      case 'both':
      default:
        return Platform.both;
    }
  }
}

// User Status enum
enum UserStatus {
  active('Active'),
  inactive('Inactive'),
  suspended('Suspended'),
  pending('Pending'); // For new registrations awaiting approval

  final String displayName;
  const UserStatus(this.displayName);

  String get value {
    switch (this) {
      case UserStatus.active:
        return 'active';
      case UserStatus.inactive:
        return 'inactive';
      case UserStatus.suspended:
        return 'suspended';
      case UserStatus.pending:
        return 'pending';
    }
  }

  static UserStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return UserStatus.active;
      case 'inactive':
        return UserStatus.inactive;
      case 'suspended':
        return UserStatus.suspended;
      case 'pending':
        return UserStatus.pending;
      default:
        return UserStatus.inactive;
    }
  }

  bool get canBorrow => this == UserStatus.active;
  bool get needsApproval => this == UserStatus.pending;
}

// User Origin (how they joined)
enum UserOrigin {
  admin('Admin'),
  coFounder('Co-Founder'),
  wave1('Wave 1'),
  wave2('Wave 2'),
  wave3('Wave 3'),
  wave4('Wave 4'),
  wave5('Wave 5'),
  referral('Referral'),
  direct('Direct');

  final String displayName;
  const UserOrigin(this.displayName);

  String get value {
    switch (this) {
      case UserOrigin.admin:
        return 'admin';
      case UserOrigin.coFounder:
        return 'coFounder';
      case UserOrigin.wave1:
        return 'wave1';
      case UserOrigin.wave2:
        return 'wave2';
      case UserOrigin.wave3:
        return 'wave3';
      case UserOrigin.wave4:
        return 'wave4';
      case UserOrigin.wave5:
        return 'wave5';
      case UserOrigin.referral:
        return 'referral';
      case UserOrigin.direct:
        return 'direct';
    }
  }

  static UserOrigin fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserOrigin.admin;
      case 'cofounder':
      case 'co-founder':
        return UserOrigin.coFounder;
      case 'wave1':
      case 'wave 1':
        return UserOrigin.wave1;
      case 'wave2':
      case 'wave 2':
        return UserOrigin.wave2;
      case 'wave3':
      case 'wave 3':
        return UserOrigin.wave3;
      case 'wave4':
      case 'wave 4':
        return UserOrigin.wave4;
      case 'wave5':
      case 'wave 5':
        return UserOrigin.wave5;
      case 'referral':
        return UserOrigin.referral;
      case 'direct':
      default:
        return UserOrigin.direct;
    }
  }
}

// Balance Entry for tracking expiry
class BalanceEntry {
  final String id;
  final String type; // 'borrow', 'sell', 'refund', 'referral', 'cashIn'
  final double amount;
  final DateTime earnedDate;
  final DateTime? expiryDate;
  final bool isExpired;
  final String? description;

  BalanceEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.earnedDate,
    this.expiryDate,
    required this.isExpired,
    this.description,
  });

  bool get willExpire => expiryDate != null;

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'earnedDate': Timestamp.fromDate(earnedDate),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'isExpired': isExpired,
      'description': description,
    };
  }

  factory BalanceEntry.fromMap(Map<String, dynamic> map) {
    return BalanceEntry(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      earnedDate: map['earnedDate'] != null
          ? (map['earnedDate'] as Timestamp).toDate()
          : DateTime.now(),
      expiryDate: map['expiryDate'] != null
          ? (map['expiryDate'] as Timestamp).toDate()
          : null,
      isExpired: map['isExpired'] ?? false,
      description: map['description'],
    );
  }
}

// Main User Model
class UserModel {
  // Basic Info
  final String uid;
  final String memberId; // 3-digit ID (100-999)
  final String name;
  final String email;
  final String phoneNumber;
  final Platform platform; // Gaming platform preference
  final String? psId; // PlayStation ID

  // Tier & Status
  final UserTier tier;
  final UserStatus status;
  final DateTime joinDate;
  final DateTime? suspensionDate;
  final UserOrigin origin;

  // Referral Info
  final String? recruiterId;
  final String? recruiterName;
  final List<String> referredUsers; // List of referred user IDs

  // Balance Components (all in LE)
  final double borrowValue; // 70% of game value when others borrow
  final double sellValue; // 90% of sale proceeds
  final double refunds; // From new fund shares
  final double referralEarnings; // 20% of recruit fees
  final double cashIn; // Direct deposits (non-expirable)
  final double usedBalance; // Already spent
  final double expiredBalance; // Expired balance
  final double withdrawalFees; // 20% fee for VIP withdrawals
  final List<BalanceEntry> balanceEntries; // Detailed balance tracking

  // Points System
  final int points; // Current points balance
  final int convertedPoints; // Points already converted to balance
  final int socialGiftPoints; // From social media participation
  final int goodwillPoints; // Top 5 monthly players (50 points each)
  final int expensePoints; // 1 point per 1 LE spent

  // Station Limit & Borrowing
  final double stationLimit; // Max LE value can borrow from vault
  final double remainingStationLimit; // Available to borrow
  final int borrowLimit; // Max simultaneous borrows (based on shares)
  final double currentBorrows; // Current active borrows (can be decimal)
  final int totalBorrowsCount; // Total number of borrows made
  final int freeborrowings; // For clients only (5 per recharge)
  final bool coolDownEligible; // Can participate in Thursday window
  final DateTime? coolDownEndDate; // When cooldown ends

  // Contributions
  final double gameShares; // Can be decimal (secondary = 0.5, PS Plus = 2)
  final double fundShares; // Number of fund contributions
  final double totalShares; // gameShares + fundShares
  final double totalFunds; // Total LE value of fund contributions
  final Map<String, int> shareBreakdown; // full, primary, secondary, psplus counts

  // Activity Metrics
  final DateTime? lastActivityDate;
  final int coldPeriodDays; // Days since last activity
  final double averageHoldPeriod; // Average days games are borrowed

  // Net Metrics
  final double netLendings; // Total value lent to others
  final double netBorrowings; // Total value borrowed
  final double netExchange; // netLendings - netBorrowings

  // Scores (Position rankings among active borrowers)
  final int cScore; // Contribution score (based on totalShares)
  final int fScore; // Fund score (based on totalFunds)
  final int hScore; // Hold period score (based on averageHoldPeriod)
  final int eScore; // Exchange score (based on netExchange)
  final double overallScore; // Weighted: C*0.2 + F*0.35 + H*0.1 + E*0.35

  // Admin specific fields
  final double? adminNetIncome;
  final Map<String, double>? adminRevenueBreakdown;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? additionalData;

  UserModel({
    required this.uid,
    required this.memberId,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.platform,
    this.psId,
    required this.tier,
    required this.status,
    required this.joinDate,
    this.suspensionDate,
    required this.origin,
    this.recruiterId,
    this.recruiterName,
    required this.referredUsers,
    required this.borrowValue,
    required this.sellValue,
    required this.refunds,
    required this.referralEarnings,
    required this.cashIn,
    required this.usedBalance,
    required this.expiredBalance,
    required this.withdrawalFees,
    required this.balanceEntries,
    required this.points,
    required this.convertedPoints,
    required this.socialGiftPoints,
    required this.goodwillPoints,
    required this.expensePoints,
    required this.stationLimit,
    required this.remainingStationLimit,
    required this.borrowLimit,
    required this.currentBorrows,
    required this.totalBorrowsCount,
    required this.freeborrowings,
    required this.coolDownEligible,
    this.coolDownEndDate,
    required this.gameShares,
    required this.fundShares,
    required this.totalShares,
    required this.totalFunds,
    required this.shareBreakdown,
    this.lastActivityDate,
    required this.coldPeriodDays,
    required this.averageHoldPeriod,
    required this.netLendings,
    required this.netBorrowings,
    required this.netExchange,
    required this.cScore,
    required this.fScore,
    required this.hScore,
    required this.eScore,
    required this.overallScore,
    this.adminNetIncome,
    this.adminRevenueBreakdown,
    required this.createdAt,
    required this.updatedAt,
    this.additionalData,
  });

  // Calculate total balance
  double get totalBalance {
    return borrowValue + sellValue + refunds + referralEarnings + cashIn
        - usedBalance - expiredBalance - withdrawalFees;
  }

  // Calculate withdrawable balance (VIP only, with 20% fee)
  double get withdrawableBalance {
    if (tier != UserTier.vip) return 0;
    return totalBalance * 0.8; // After 20% fee
  }

  // Check if eligible for VIP promotion
  bool get isEligibleForVIP {
    return totalShares >= 15 && fundShares >= 5 && tier == UserTier.member;
  }

  // Calculate borrow limit based on total shares
  static int calculateBorrowLimit(int totalShares, UserTier tier) {
    if (tier == UserTier.vip) return 5;
    if (tier == UserTier.client) return 10; // But limited by free borrowings
    if (tier == UserTier.admin) return 10;

    // For members based on shares
    if (totalShares < 4) return 1;
    if (totalShares < 9) return 2;
    if (totalShares < 15) return 3;
    return 4;
  }

  // Check if suspension is due (6 months inactivity)
  bool get shouldBeSuspended {
    if (tier == UserTier.vip || tier == UserTier.admin) return false;
    if (lastActivityDate == null) return false;

    final daysSinceActivity = DateTime.now().difference(lastActivityDate!).inDays;
    return daysSinceActivity >= 180; // 6 months
  }

  // Check if can borrow
  bool get canBorrow {
    if (status != UserStatus.active) return false;
    if (currentBorrows >= borrowLimit) return false;
    if (remainingStationLimit <= 0) return false;
    if (coolDownEndDate != null && DateTime.now().isBefore(coolDownEndDate!)) {
      return false; // In cooldown period
    }
    return true;
  }

  // Check if client needs renewal
  bool get needsRenewal {
    return tier == UserTier.client && totalBorrowsCount >= 10;
  }

  // Get days until suspension
  int? get daysUntilSuspension {
    if (tier == UserTier.vip || tier == UserTier.admin) return null;
    if (lastActivityDate == null) return null;

    final daysSinceActivity = DateTime.now().difference(lastActivityDate!).inDays;
    final daysRemaining = 180 - daysSinceActivity;
    return daysRemaining > 0 ? daysRemaining : 0;
  }

  // BALANCE MANAGEMENT HELPER METHODS

  // Get active (non-expired) balance entries
  List<BalanceEntry> get activeBalanceEntries {
    return balanceEntries.where((entry) => 
      !entry.isExpired && 
      (entry.expiryDate == null || entry.expiryDate!.isAfter(DateTime.now()))
    ).toList();
  }

  // Get balance entries that will expire soon (within 30 days)
  List<BalanceEntry> get expiringBalanceEntries {
    final thirtyDaysFromNow = DateTime.now().add(Duration(days: 30));
    return balanceEntries.where((entry) => 
      !entry.isExpired && 
      entry.expiryDate != null &&
      entry.expiryDate!.isBefore(thirtyDaysFromNow) &&
      entry.expiryDate!.isAfter(DateTime.now())
    ).toList();
  }

  // Get expired balance entries
  List<BalanceEntry> get expiredBalanceEntries {
    return balanceEntries.where((entry) => 
      entry.isExpired || 
      (entry.expiryDate != null && entry.expiryDate!.isBefore(DateTime.now()))
    ).toList();
  }

  // Calculate balance by type from active entries
  double getBalanceByType(String type) {
    return activeBalanceEntries
      .where((entry) => entry.type == type)
      .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  // Get detailed balance breakdown
  Map<String, double> get balanceBreakdown {
    return {
      'borrowValue': getBalanceByType('borrowValue'),
      'sellValue': getBalanceByType('sellValue'),
      'refunds': getBalanceByType('refunds'),
      'referralEarnings': getBalanceByType('referralEarnings'),
      'cashIn': getBalanceByType('cashIn'),
      'expired': expiredBalance,
      'used': usedBalance,
      'withdrawalFees': withdrawalFees,
      'total': totalBalance,
    };
  }

  // Calculate total active balance (from active entries only)
  double get activeBalance {
    return activeBalanceEntries.fold(0.0, (sum, entry) => sum + entry.amount);
  }

  // Get balance entries expiring within specified days
  List<BalanceEntry> getBalanceEntriesExpiringWithin(int days) {
    final targetDate = DateTime.now().add(Duration(days: days));
    return balanceEntries.where((entry) => 
      !entry.isExpired && 
      entry.expiryDate != null &&
      entry.expiryDate!.isBefore(targetDate) &&
      entry.expiryDate!.isAfter(DateTime.now())
    ).toList();
  }

  // Check if user has any expiring balance within 30 days
  bool get hasExpiringBalance {
    return expiringBalanceEntries.isNotEmpty;
  }

  // Get total amount expiring within 30 days
  double get amountExpiringWithin30Days {
    return expiringBalanceEntries.fold(0.0, (sum, entry) => sum + entry.amount);
  }

  // Factory constructor from Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Helper to parse dates
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    // Parse balance entries
    List<BalanceEntry> entries = [];
    if (data['balanceEntries'] != null) {
      for (var entry in data['balanceEntries']) {
        entries.add(BalanceEntry.fromMap(entry));
      }
    }

    return UserModel(
      uid: doc.id,
      memberId: data['memberId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phoneNumber: data['phoneNumber']?.toString() ?? '',
      platform: Platform.fromString(data['platform']?.toString() ?? 'both'),
      psId: data['psId']?.toString(),
      tier: UserTier.fromString(data['tier']?.toString() ?? 'user'),
      status: UserStatus.fromString(data['status']?.toString() ?? 'inactive'),
      joinDate: parseDate(data['joinDate']),
      suspensionDate: data['suspensionDate'] != null
          ? parseDate(data['suspensionDate'])
          : null,
      origin: UserOrigin.fromString(data['origin']?.toString() ?? 'direct'),
      recruiterId: data['recruiterId']?.toString(),
      recruiterName: data['recruiterName']?.toString(),
      referredUsers: data['referredUsers'] != null
          ? List<String>.from((data['referredUsers'] as List).map((e) => e.toString()))
          : [],
      borrowValue: _parseDouble(data['borrowValue']),
      sellValue: _parseDouble(data['sellValue']),
      refunds: _parseDouble(data['refunds']),
      referralEarnings: _parseDouble(data['referralEarnings']),
      cashIn: _parseDouble(data['cashIn']),
      usedBalance: _parseDouble(data['usedBalance']),
      expiredBalance: _parseDouble(data['expiredBalance']),
      withdrawalFees: _parseDouble(data['withdrawalFees']),
      balanceEntries: entries,
      points: _parseInt(data['points']),
      convertedPoints: _parseInt(data['convertedPoints']),
      socialGiftPoints: _parseInt(data['socialGiftPoints']),
      goodwillPoints: _parseInt(data['goodwillPoints']),
      expensePoints: _parseInt(data['expensePoints']),
      stationLimit: _parseDouble(data['stationLimit']),
      remainingStationLimit: _parseDouble(data['remainingStationLimit']),
      borrowLimit: _parseInt(data['borrowLimit']),
      currentBorrows: _parseDouble(data['currentBorrows']),
      totalBorrowsCount: _parseInt(data['totalBorrowsCount']),
      freeborrowings: _parseInt(data['freeborrowings']),
      coolDownEligible: data['coolDownEligible'] == true,
      coolDownEndDate: data['coolDownEndDate'] != null
          ? parseDate(data['coolDownEndDate'])
          : null,
      gameShares: _parseDouble(data['gameShares']),
      fundShares: _parseDouble(data['fundShares']),
      totalShares: _parseDouble(data['totalShares']),
      totalFunds: _parseDouble(data['totalFunds']),
      shareBreakdown: data['shareBreakdown'] != null
          ? Map<String, int>.from(data['shareBreakdown'] as Map)
          : {'full': 0, 'primary': 0, 'secondary': 0, 'psplus': 0},
      lastActivityDate: data['lastActivityDate'] != null
          ? parseDate(data['lastActivityDate'])
          : null,
      coldPeriodDays: _parseInt(data['coldPeriodDays']),
      averageHoldPeriod: _parseDouble(data['averageHoldPeriod']),
      netLendings: _parseDouble(data['netLendings']),
      netBorrowings: _parseDouble(data['netBorrowings']),
      netExchange: _parseDouble(data['netExchange']),
      cScore: _parseInt(data['cScore']),
      fScore: _parseInt(data['fScore']),
      hScore: _parseInt(data['hScore']),
      eScore: _parseInt(data['eScore']),
      overallScore: _parseDouble(data['overallScore']),
      adminNetIncome: data['adminNetIncome'] != null
          ? _parseDouble(data['adminNetIncome'])
          : null,
      adminRevenueBreakdown: data['adminRevenueBreakdown'] != null
          ? Map<String, double>.from((data['adminRevenueBreakdown'] as Map).map(
              (key, value) => MapEntry(key.toString(), _parseDouble(value))))
          : null,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
      additionalData: data['additionalData'] as Map<String, dynamic>?,
    );
  }

  // Helper method to safely parse double
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Helper method to safely parse int
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'memberId': memberId,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'platform': platform.value,
      'psId': psId,
      'tier': tier.value,
      'status': status.value,
      'joinDate': Timestamp.fromDate(joinDate),
      'suspensionDate': suspensionDate != null
          ? Timestamp.fromDate(suspensionDate!)
          : null,
      'origin': origin.value,
      'recruiterId': recruiterId,
      'recruiterName': recruiterName,
      'referredUsers': referredUsers,
      'borrowValue': borrowValue,
      'sellValue': sellValue,
      'refunds': refunds,
      'referralEarnings': referralEarnings,
      'cashIn': cashIn,
      'usedBalance': usedBalance,
      'expiredBalance': expiredBalance,
      'withdrawalFees': withdrawalFees,
      'balanceEntries': balanceEntries.map((e) => e.toMap()).toList(),
      'points': points,
      'convertedPoints': convertedPoints,
      'socialGiftPoints': socialGiftPoints,
      'goodwillPoints': goodwillPoints,
      'expensePoints': expensePoints,
      'stationLimit': stationLimit,
      'remainingStationLimit': remainingStationLimit,
      'borrowLimit': borrowLimit,
      'currentBorrows': currentBorrows,
      'totalBorrowsCount': totalBorrowsCount,
      'freeborrowings': freeborrowings,
      'coolDownEligible': coolDownEligible,
      'coolDownEndDate': coolDownEndDate != null
          ? Timestamp.fromDate(coolDownEndDate!)
          : null,
      'gameShares': gameShares,
      'fundShares': fundShares,
      'totalShares': totalShares,
      'totalFunds': totalFunds,
      'shareBreakdown': shareBreakdown,
      'lastActivityDate': lastActivityDate != null
          ? Timestamp.fromDate(lastActivityDate!)
          : null,
      'coldPeriodDays': coldPeriodDays,
      'averageHoldPeriod': averageHoldPeriod,
      'netLendings': netLendings,
      'netBorrowings': netBorrowings,
      'netExchange': netExchange,
      'cScore': cScore,
      'fScore': fScore,
      'hScore': hScore,
      'eScore': eScore,
      'overallScore': overallScore,
      'adminNetIncome': adminNetIncome,
      'adminRevenueBreakdown': adminRevenueBreakdown,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'additionalData': additionalData,
    };
  }

  // CopyWith method for updates
  UserModel copyWith({
    String? uid,
    String? memberId,
    String? name,
    String? email,
    String? phoneNumber,
    Platform? platform,
    String? psId,
    UserTier? tier,
    UserStatus? status,
    DateTime? joinDate,
    DateTime? suspensionDate,
    UserOrigin? origin,
    String? recruiterId,
    String? recruiterName,
    List<String>? referredUsers,
    double? borrowValue,
    double? sellValue,
    double? refunds,
    double? referralEarnings,
    double? cashIn,
    double? usedBalance,
    double? expiredBalance,
    double? withdrawalFees,
    List<BalanceEntry>? balanceEntries,
    int? points,
    int? convertedPoints,
    int? socialGiftPoints,
    int? goodwillPoints,
    int? expensePoints,
    double? stationLimit,
    double? remainingStationLimit,
    int? borrowLimit,
    double? currentBorrows,
    int? totalBorrowsCount,
    int? freeborrowings,
    bool? coolDownEligible,
    DateTime? coolDownEndDate,
    double? gameShares,
    double? fundShares,
    double? totalShares,
    double? totalFunds,
    Map<String, int>? shareBreakdown,
    DateTime? lastActivityDate,
    int? coldPeriodDays,
    double? averageHoldPeriod,
    double? netLendings,
    double? netBorrowings,
    double? netExchange,
    int? cScore,
    int? fScore,
    int? hScore,
    int? eScore,
    double? overallScore,
    double? adminNetIncome,
    Map<String, double>? adminRevenueBreakdown,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? additionalData,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      memberId: memberId ?? this.memberId,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      platform: platform ?? this.platform,
      psId: psId ?? this.psId,
      tier: tier ?? this.tier,
      status: status ?? this.status,
      joinDate: joinDate ?? this.joinDate,
      suspensionDate: suspensionDate ?? this.suspensionDate,
      origin: origin ?? this.origin,
      recruiterId: recruiterId ?? this.recruiterId,
      recruiterName: recruiterName ?? this.recruiterName,
      referredUsers: referredUsers ?? this.referredUsers,
      borrowValue: borrowValue ?? this.borrowValue,
      sellValue: sellValue ?? this.sellValue,
      refunds: refunds ?? this.refunds,
      referralEarnings: referralEarnings ?? this.referralEarnings,
      cashIn: cashIn ?? this.cashIn,
      usedBalance: usedBalance ?? this.usedBalance,
      expiredBalance: expiredBalance ?? this.expiredBalance,
      withdrawalFees: withdrawalFees ?? this.withdrawalFees,
      balanceEntries: balanceEntries ?? this.balanceEntries,
      points: points ?? this.points,
      convertedPoints: convertedPoints ?? this.convertedPoints,
      socialGiftPoints: socialGiftPoints ?? this.socialGiftPoints,
      goodwillPoints: goodwillPoints ?? this.goodwillPoints,
      expensePoints: expensePoints ?? this.expensePoints,
      stationLimit: stationLimit ?? this.stationLimit,
      remainingStationLimit: remainingStationLimit ?? this.remainingStationLimit,
      borrowLimit: borrowLimit ?? this.borrowLimit,
      currentBorrows: currentBorrows ?? this.currentBorrows,
      totalBorrowsCount: totalBorrowsCount ?? this.totalBorrowsCount,
      freeborrowings: freeborrowings ?? this.freeborrowings,
      coolDownEligible: coolDownEligible ?? this.coolDownEligible,
      coolDownEndDate: coolDownEndDate ?? this.coolDownEndDate,
      gameShares: gameShares ?? this.gameShares,
      fundShares: fundShares ?? this.fundShares,
      totalShares: totalShares ?? this.totalShares,
      totalFunds: totalFunds ?? this.totalFunds,
      shareBreakdown: shareBreakdown ?? this.shareBreakdown,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      coldPeriodDays: coldPeriodDays ?? this.coldPeriodDays,
      averageHoldPeriod: averageHoldPeriod ?? this.averageHoldPeriod,
      netLendings: netLendings ?? this.netLendings,
      netBorrowings: netBorrowings ?? this.netBorrowings,
      netExchange: netExchange ?? this.netExchange,
      cScore: cScore ?? this.cScore,
      fScore: fScore ?? this.fScore,
      hScore: hScore ?? this.hScore,
      eScore: eScore ?? this.eScore,
      overallScore: overallScore ?? this.overallScore,
      adminNetIncome: adminNetIncome ?? this.adminNetIncome,
      adminRevenueBreakdown: adminRevenueBreakdown ?? this.adminRevenueBreakdown,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}