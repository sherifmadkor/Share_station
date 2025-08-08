import 'package:cloud_firestore/cloud_firestore.dart';

// FIXED ENUMS - Compatible with all Flutter versions
enum UserTier {
  admin('Admin'),
  vip('VIP Member'),
  member('Member'),
  client('Client'),
  user('User');

  final String displayName;
  const UserTier(this.displayName);

  // Use this for storing in Firebase instead of .name
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
}

enum Platform {
  ps4('PS4'),
  ps5('PS5'),
  na('N/A');

  final String displayName;
  const Platform(this.displayName);

  // Use this for storing in Firebase instead of .name
  String get value {
    switch (this) {
      case Platform.ps4:
        return 'ps4';
      case Platform.ps5:
        return 'ps5';
      case Platform.na:
        return 'na';
    }
  }

  static Platform fromString(String value) {
    switch (value.toLowerCase()) {
      case 'ps4':
        return Platform.ps4;
      case 'ps5':
        return Platform.ps5;
      case 'na':
      default:
        return Platform.na;
    }
  }
}

enum UserStatus {
  active('Active'),
  inactive('Inactive'),
  suspended('Suspended'),
  pending('Pending'); // For new registrations

  final String displayName;
  const UserStatus(this.displayName);

  // Use this for storing in Firebase instead of .name
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
}

class UserModel {
  // Basic Info
  final String uid;
  final String memberId; // 3-digit ID (100-999)
  final String name;
  final String email;
  final String phoneNumber;
  final Platform platform;
  final String? psId;

  // Tier & Status
  final UserTier tier;
  final UserStatus status;
  final DateTime joinDate;
  final DateTime? suspensionDate;
  final String origin; // Admin, Co-Founder, Wave 1-5, etc.

  // Referral Info
  final String? recruiterId;
  final String? recruiterName;
  final List<String> referredUsers; // List of referred user IDs

  // Balance Components
  final double borrowValue; // 70% of borrow value (expires 90 days)
  final double sellValue; // 90% of sell value (expires 90 days)
  final double refunds; // From new fund shares
  final double referralEarnings; // 20% of recruit fees
  final double cashIn; // Non-expirable deposits
  final double usedBalance;
  final double expiredBalance;
  final double withdrawalFees; // 20% fee for VIP withdrawals
  final Map<String, DateTime> balanceExpiry; // Track expiry dates

  // Points
  final int points;
  final int convertedPoints;
  final int socialGiftPoints;
  final int goodwillPoints; // Top 5 monthly players
  final int expensePoints; // 1 point per 1 LE spent

  // Station Limit & Borrowing
  final double stationLimit;
  final double remainingStationLimit;
  final int borrowLimit; // Based on total shares
  final int currentBorrows; // Active borrows count
  final int freeborrowings; // For clients only
  final bool coolDownEligible;
  final DateTime? coolDownEndDate;

  // Contributions
  final int gameShares;
  final int fundShares;
  final int totalShares;
  final double totalFunds; // Total value of contributions
  final Map<String, int> shareBreakdown; // Full, Primary, Secondary, PS Plus

  // Activity Metrics
  final DateTime? lastActivityDate;
  final int coldPeriodDays;
  final double averageHoldPeriod;

  // Net Metrics
  final double netLendings;
  final double netBorrowings;
  final double netExchange;

  // Scores (Position rankings)
  final int cScore; // Contribution score
  final int fScore; // Fund score
  final int hScore; // Hold period score
  final int eScore; // Exchange score
  final double overallScore; // Weighted average

  // Admin specific (if applicable)
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
    required this.balanceExpiry,
    required this.points,
    required this.convertedPoints,
    required this.socialGiftPoints,
    required this.goodwillPoints,
    required this.expensePoints,
    required this.stationLimit,
    required this.remainingStationLimit,
    required this.borrowLimit,
    required this.currentBorrows,
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

  // Calculate withdrawable balance (VIP only)
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
    if (tier == UserTier.client) return 10; // Max for clients

    if (totalShares < 4) return 1;
    if (totalShares < 9) return 2;
    if (totalShares < 15) return 3;
    return 4;
  }

  // Check if suspension is due
  bool get shouldBeSuspended {
    if (tier == UserTier.vip || tier == UserTier.admin) return false;
    if (lastActivityDate == null) return false;

    final daysSinceActivity = DateTime.now().difference(lastActivityDate!).inDays;
    return daysSinceActivity >= 180; // 6 months
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

    return UserModel(
      uid: doc.id,
      memberId: data['memberId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phoneNumber: data['phoneNumber']?.toString() ?? '',
      platform: Platform.fromString(data['platform']?.toString() ?? 'na'),
      psId: data['psId']?.toString(),
      tier: UserTier.fromString(data['tier']?.toString() ?? 'user'),
      status: UserStatus.fromString(data['status']?.toString() ?? 'inactive'),
      joinDate: parseDate(data['joinDate']),
      suspensionDate: data['suspensionDate'] != null
          ? parseDate(data['suspensionDate'])
          : null,
      origin: data['origin']?.toString() ?? '',
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
      balanceExpiry: _parseBalanceExpiry(data['balanceExpiry']),
      points: _parseInt(data['points']),
      convertedPoints: _parseInt(data['convertedPoints']),
      socialGiftPoints: _parseInt(data['socialGiftPoints']),
      goodwillPoints: _parseInt(data['goodwillPoints']),
      expensePoints: _parseInt(data['expensePoints']),
      stationLimit: _parseDouble(data['stationLimit']),
      remainingStationLimit: _parseDouble(data['remainingStationLimit']),
      borrowLimit: _parseInt(data['borrowLimit']),
      currentBorrows: _parseInt(data['currentBorrows']),
      freeborrowings: _parseInt(data['freeborrowings']),
      coolDownEligible: data['coolDownEligible'] == true,
      coolDownEndDate: data['coolDownEndDate'] != null
          ? parseDate(data['coolDownEndDate'])
          : null,
      gameShares: _parseInt(data['gameShares']),
      fundShares: _parseInt(data['fundShares']),
      totalShares: _parseInt(data['totalShares']),
      totalFunds: _parseDouble(data['totalFunds']),
      shareBreakdown: data['shareBreakdown'] != null
          ? Map<String, int>.from(data['shareBreakdown'] as Map)
          : {},
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

  // Helper method to parse balance expiry dates
  static Map<String, DateTime> _parseBalanceExpiry(dynamic data) {
    if (data == null) return {};
    if (data is! Map) return {};

    Map<String, DateTime> result = {};
    try {
      (data as Map).forEach((key, value) {
        if (value is Timestamp) {
          result[key.toString()] = value.toDate();
        } else if (value is String) {
          final date = DateTime.tryParse(value);
          if (date != null) {
            result[key.toString()] = date;
          }
        }
      });
    } catch (e) {
      print('Error parsing balance expiry: $e');
    }
    return result;
  }

  // Convert to Firestore document - FIXED to use .value instead of .name
  Map<String, dynamic> toFirestore() {
    return {
      'memberId': memberId,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'platform': platform.value,  // FIXED: Using .value instead of .name
      'psId': psId,
      'tier': tier.value,  // FIXED: Using .value instead of .name
      'status': status.value,  // FIXED: Using .value instead of .name
      'joinDate': Timestamp.fromDate(joinDate),
      'suspensionDate': suspensionDate != null
          ? Timestamp.fromDate(suspensionDate!)
          : null,
      'origin': origin,
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
      'balanceExpiry': _convertBalanceExpiryToFirestore(balanceExpiry),
      'points': points,
      'convertedPoints': convertedPoints,
      'socialGiftPoints': socialGiftPoints,
      'goodwillPoints': goodwillPoints,
      'expensePoints': expensePoints,
      'stationLimit': stationLimit,
      'remainingStationLimit': remainingStationLimit,
      'borrowLimit': borrowLimit,
      'currentBorrows': currentBorrows,
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

  // Helper method to convert balance expiry to Firestore format
  static Map<String, dynamic> _convertBalanceExpiryToFirestore(Map<String, DateTime> expiry) {
    Map<String, dynamic> result = {};
    expiry.forEach((key, value) {
      result[key] = Timestamp.fromDate(value);
    });
    return result;
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
    String? origin,
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
    Map<String, DateTime>? balanceExpiry,
    int? points,
    int? convertedPoints,
    int? socialGiftPoints,
    int? goodwillPoints,
    int? expensePoints,
    double? stationLimit,
    double? remainingStationLimit,
    int? borrowLimit,
    int? currentBorrows,
    int? freeborrowings,
    bool? coolDownEligible,
    DateTime? coolDownEndDate,
    int? gameShares,
    int? fundShares,
    int? totalShares,
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
      balanceExpiry: balanceExpiry ?? this.balanceExpiry,
      points: points ?? this.points,
      convertedPoints: convertedPoints ?? this.convertedPoints,
      socialGiftPoints: socialGiftPoints ?? this.socialGiftPoints,
      goodwillPoints: goodwillPoints ?? this.goodwillPoints,
      expensePoints: expensePoints ?? this.expensePoints,
      stationLimit: stationLimit ?? this.stationLimit,
      remainingStationLimit: remainingStationLimit ?? this.remainingStationLimit,
      borrowLimit: borrowLimit ?? this.borrowLimit,
      currentBorrows: currentBorrows ?? this.currentBorrows,
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