import 'package:cloud_firestore/cloud_firestore.dart';

// Import Platform from user_model but we'll redefine it here for clarity
// Or you can import it: import '../user_model.dart' show Platform;

// Redefine Platform here to ensure it has the .value getter
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

enum AccountType {
  full('Full Account'),
  primary('Primary'),
  secondary('Secondary'),
  psPlus('PS Plus');

  final String displayName;
  const AccountType(this.displayName);

  // Use this for storing in Firebase instead of .name
  String get value {
    switch (this) {
      case AccountType.full:
        return 'full';
      case AccountType.primary:
        return 'primary';
      case AccountType.secondary:
        return 'secondary';
      case AccountType.psPlus:
        return 'psPlus';
    }
  }

  static AccountType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'full':
        return AccountType.full;
      case 'primary':
        return AccountType.primary;
      case 'secondary':
        return AccountType.secondary;
      case 'psplus':
        return AccountType.psPlus;
      default:
        return AccountType.primary;
    }
  }

  // Get borrow value multiplier
  double get borrowMultiplier {
    switch (this) {
      case AccountType.full:
      case AccountType.primary:
        return 1.0;
      case AccountType.secondary:
        return 0.75;
      case AccountType.psPlus:
        return 2.0;
    }
  }

  // Get share count value
  double get shareValue {
    switch (this) {
      case AccountType.full:
      case AccountType.primary:
        return 1.0;
      case AccountType.secondary:
        return 0.5;
      case AccountType.psPlus:
        return 2.0;
    }
  }
}

enum SlotStatus {
  available('Available'),
  taken('Taken'),
  reserved('Reserved'),
  notAvailable('Not Available');

  final String displayName;
  const SlotStatus(this.displayName);

  // Use this for storing in Firebase instead of .name
  String get value {
    switch (this) {
      case SlotStatus.available:
        return 'available';
      case SlotStatus.taken:
        return 'taken';
      case SlotStatus.reserved:
        return 'reserved';
      case SlotStatus.notAvailable:
        return 'notAvailable';
    }
  }

  static SlotStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'available':
        return SlotStatus.available;
      case 'taken':
        return SlotStatus.taken;
      case 'reserved':
        return SlotStatus.reserved;
      case 'notavailable':
      default:
        return SlotStatus.notAvailable;
    }
  }
}

enum LenderTier {
  gamesVault('Games Vault'),
  member('Member'),
  nonMember('Non-Member'),
  admin('Admin');

  final String displayName;
  const LenderTier(this.displayName);

  // Use this for storing in Firebase instead of .name
  String get value {
    switch (this) {
      case LenderTier.gamesVault:
        return 'gamesVault';
      case LenderTier.member:
        return 'member';
      case LenderTier.nonMember:
        return 'nonMember';
      case LenderTier.admin:
        return 'admin';
    }
  }

  static LenderTier fromString(String value) {
    switch (value.toLowerCase()) {
      case 'gamesvault':
        return LenderTier.gamesVault;
      case 'member':
        return LenderTier.member;
      case 'nonmember':
        return LenderTier.nonMember;
      case 'admin':
        return LenderTier.admin;
      default:
        return LenderTier.nonMember;
    }
  }
}

class GameSlot {
  final Platform platform;
  final AccountType accountType;
  final SlotStatus status;
  final String? borrowerId;
  final DateTime? borrowDate;
  final DateTime? expectedReturnDate;
  final DateTime? reservationDate;
  final String? reservedById;

  GameSlot({
    required this.platform,
    required this.accountType,
    required this.status,
    this.borrowerId,
    this.borrowDate,
    this.expectedReturnDate,
    this.reservationDate,
    this.reservedById,
  });

  Map<String, dynamic> toMap() {
    return {
      'platform': platform.value,  // FIXED: Using .value instead of .name
      'accountType': accountType.value,  // FIXED: Using .value instead of .name
      'status': status.value,  // FIXED: Using .value instead of .name
      'borrowerId': borrowerId,
      'borrowDate': borrowDate != null ? Timestamp.fromDate(borrowDate!) : null,
      'expectedReturnDate': expectedReturnDate != null
          ? Timestamp.fromDate(expectedReturnDate!) : null,
      'reservationDate': reservationDate != null
          ? Timestamp.fromDate(reservationDate!) : null,
      'reservedById': reservedById,
    };
  }

  factory GameSlot.fromMap(Map<String, dynamic> map) {
    return GameSlot(
      platform: Platform.fromString(map['platform'] ?? 'na'),
      accountType: AccountType.fromString(map['accountType'] ?? 'primary'),
      status: SlotStatus.fromString(map['status'] ?? 'notAvailable'),
      borrowerId: map['borrowerId'],
      borrowDate: map['borrowDate'] != null
          ? (map['borrowDate'] as Timestamp).toDate() : null,
      expectedReturnDate: map['expectedReturnDate'] != null
          ? (map['expectedReturnDate'] as Timestamp).toDate() : null,
      reservationDate: map['reservationDate'] != null
          ? (map['reservationDate'] as Timestamp).toDate() : null,
      reservedById: map['reservedById'],
    );
  }

  GameSlot copyWith({
    Platform? platform,
    AccountType? accountType,
    SlotStatus? status,
    String? borrowerId,
    DateTime? borrowDate,
    DateTime? expectedReturnDate,
    DateTime? reservationDate,
    String? reservedById,
  }) {
    return GameSlot(
      platform: platform ?? this.platform,
      accountType: accountType ?? this.accountType,
      status: status ?? this.status,
      borrowerId: borrowerId ?? this.borrowerId,
      borrowDate: borrowDate ?? this.borrowDate,
      expectedReturnDate: expectedReturnDate ?? this.expectedReturnDate,
      reservationDate: reservationDate ?? this.reservationDate,
      reservedById: reservedById ?? this.reservedById,
    );
  }
}

class GameAccount {
  // Basic Info
  final String accountId;
  final String title;
  final List<String> includedTitles; // For accounts with multiple games
  final String? coverImageUrl;
  final String? description;

  // Account Details
  final String email;
  final String password;
  final String? edition;
  final String? region;
  final DateTime? expiryDate;

  // Ownership & Contribution
  final String contributorId;
  final String contributorName;
  final LenderTier lenderTier;
  final DateTime dateAdded;
  final DateTime? dateRemoved;
  final bool isActive;

  // Platform & Sharing Options
  final List<Platform> supportedPlatforms;
  final List<AccountType> sharingOptions;

  // Slots Management
  final Map<String, GameSlot> slots; // Key: "ps5_primary", "ps4_secondary", etc.

  // Financial Data
  final double gameValue;
  final double totalCost;
  final double totalRevenues;
  final double borrowRevenue;
  final double sellRevenue;
  final double fundShareRevenue;

  // Statistics
  final int totalBorrows;
  final int currentBorrows;
  final double averageBorrowDuration;
  final List<String> borrowHistory; // User IDs who borrowed

  // Games Vault Specific
  final int? batchNumber;
  final double? nextShareValue;
  final List<String>? fundContributors;
  final Map<String, double>? contributorShares;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? additionalData;

  GameAccount({
    required this.accountId,
    required this.title,
    required this.includedTitles,
    this.coverImageUrl,
    this.description,
    required this.email,
    required this.password,
    this.edition,
    this.region,
    this.expiryDate,
    required this.contributorId,
    required this.contributorName,
    required this.lenderTier,
    required this.dateAdded,
    this.dateRemoved,
    required this.isActive,
    required this.supportedPlatforms,
    required this.sharingOptions,
    required this.slots,
    required this.gameValue,
    required this.totalCost,
    required this.totalRevenues,
    required this.borrowRevenue,
    required this.sellRevenue,
    required this.fundShareRevenue,
    required this.totalBorrows,
    required this.currentBorrows,
    required this.averageBorrowDuration,
    required this.borrowHistory,
    this.batchNumber,
    this.nextShareValue,
    this.fundContributors,
    this.contributorShares,
    required this.createdAt,
    required this.updatedAt,
    this.additionalData,
  });

  // Calculate profit
  double get profit => totalRevenues - totalCost;

  // Check if available for borrowing - FIXED
  bool isAvailableForBorrowing(Platform platform, AccountType accountType) {
    final slotKey = '${platform.value}_${accountType.value}';  // FIXED: Using .value
    final slot = slots[slotKey];
    return slot != null && slot.status == SlotStatus.available;
  }

  // Get available slots count
  int get availableSlotsCount {
    return slots.values.where((slot) => slot.status == SlotStatus.available).length;
  }

  // Check if it's a Games Vault item
  bool get isGamesVaultItem => lenderTier == LenderTier.gamesVault;

  // Check if PS Plus account
  bool get isPSPlusAccount => sharingOptions.contains(AccountType.psPlus);

  // Factory constructor from Firestore
  factory GameAccount.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Parse slots
    Map<String, GameSlot> parsedSlots = {};
    if (data['slots'] != null) {
      (data['slots'] as Map<String, dynamic>).forEach((key, value) {
        parsedSlots[key] = GameSlot.fromMap(value);
      });
    }

    return GameAccount(
      accountId: doc.id,
      title: data['title'] ?? '',
      includedTitles: List<String>.from(data['includedTitles'] ?? []),
      coverImageUrl: data['coverImageUrl'],
      description: data['description'],
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      edition: data['edition'],
      region: data['region'],
      expiryDate: data['expiryDate'] != null
          ? (data['expiryDate'] as Timestamp).toDate() : null,
      contributorId: data['contributorId'] ?? '',
      contributorName: data['contributorName'] ?? '',
      lenderTier: LenderTier.fromString(data['lenderTier'] ?? 'nonMember'),
      dateAdded: data['dateAdded'] != null
          ? (data['dateAdded'] as Timestamp).toDate()
          : DateTime.now(),
      dateRemoved: data['dateRemoved'] != null
          ? (data['dateRemoved'] as Timestamp).toDate() : null,
      isActive: data['isActive'] ?? true,
      supportedPlatforms: (data['supportedPlatforms'] as List<dynamic>?)
          ?.map((e) => Platform.fromString(e.toString()))
          .toList() ?? [],
      sharingOptions: (data['sharingOptions'] as List<dynamic>?)
          ?.map((e) => AccountType.fromString(e.toString()))
          .toList() ?? [],
      slots: parsedSlots,
      gameValue: (data['gameValue'] ?? 0).toDouble(),
      totalCost: (data['totalCost'] ?? 0).toDouble(),
      totalRevenues: (data['totalRevenues'] ?? 0).toDouble(),
      borrowRevenue: (data['borrowRevenue'] ?? 0).toDouble(),
      sellRevenue: (data['sellRevenue'] ?? 0).toDouble(),
      fundShareRevenue: (data['fundShareRevenue'] ?? 0).toDouble(),
      totalBorrows: data['totalBorrows'] ?? 0,
      currentBorrows: data['currentBorrows'] ?? 0,
      averageBorrowDuration: (data['averageBorrowDuration'] ?? 0).toDouble(),
      borrowHistory: List<String>.from(data['borrowHistory'] ?? []),
      batchNumber: data['batchNumber'],
      nextShareValue: data['nextShareValue']?.toDouble(),
      fundContributors: data['fundContributors'] != null
          ? List<String>.from(data['fundContributors']) : null,
      contributorShares: data['contributorShares'] != null
          ? Map<String, double>.from(data['contributorShares']) : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      additionalData: data['additionalData'],
    );
  }

  // Convert to Firestore document - FIXED
  Map<String, dynamic> toFirestore() {
    // Convert slots to map
    Map<String, dynamic> slotsMap = {};
    slots.forEach((key, value) {
      slotsMap[key] = value.toMap();
    });

    return {
      'title': title,
      'includedTitles': includedTitles,
      'coverImageUrl': coverImageUrl,
      'description': description,
      'email': email,
      'password': password,
      'edition': edition,
      'region': region,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'contributorId': contributorId,
      'contributorName': contributorName,
      'lenderTier': lenderTier.value,  // FIXED: Using .value instead of .name
      'dateAdded': Timestamp.fromDate(dateAdded),
      'dateRemoved': dateRemoved != null ? Timestamp.fromDate(dateRemoved!) : null,
      'isActive': isActive,
      'supportedPlatforms': supportedPlatforms.map((e) => e.value).toList(),  // FIXED
      'sharingOptions': sharingOptions.map((e) => e.value).toList(),  // FIXED
      'slots': slotsMap,
      'gameValue': gameValue,
      'totalCost': totalCost,
      'totalRevenues': totalRevenues,
      'borrowRevenue': borrowRevenue,
      'sellRevenue': sellRevenue,
      'fundShareRevenue': fundShareRevenue,
      'totalBorrows': totalBorrows,
      'currentBorrows': currentBorrows,
      'averageBorrowDuration': averageBorrowDuration,
      'borrowHistory': borrowHistory,
      'batchNumber': batchNumber,
      'nextShareValue': nextShareValue,
      'fundContributors': fundContributors,
      'contributorShares': contributorShares,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'additionalData': additionalData,
    };
  }

  // CopyWith method
  GameAccount copyWith({
    String? accountId,
    String? title,
    List<String>? includedTitles,
    String? coverImageUrl,
    String? description,
    String? email,
    String? password,
    String? edition,
    String? region,
    DateTime? expiryDate,
    String? contributorId,
    String? contributorName,
    LenderTier? lenderTier,
    DateTime? dateAdded,
    DateTime? dateRemoved,
    bool? isActive,
    List<Platform>? supportedPlatforms,
    List<AccountType>? sharingOptions,
    Map<String, GameSlot>? slots,
    double? gameValue,
    double? totalCost,
    double? totalRevenues,
    double? borrowRevenue,
    double? sellRevenue,
    double? fundShareRevenue,
    int? totalBorrows,
    int? currentBorrows,
    double? averageBorrowDuration,
    List<String>? borrowHistory,
    int? batchNumber,
    double? nextShareValue,
    List<String>? fundContributors,
    Map<String, double>? contributorShares,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? additionalData,
  }) {
    return GameAccount(
      accountId: accountId ?? this.accountId,
      title: title ?? this.title,
      includedTitles: includedTitles ?? this.includedTitles,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      description: description ?? this.description,
      email: email ?? this.email,
      password: password ?? this.password,
      edition: edition ?? this.edition,
      region: region ?? this.region,
      expiryDate: expiryDate ?? this.expiryDate,
      contributorId: contributorId ?? this.contributorId,
      contributorName: contributorName ?? this.contributorName,
      lenderTier: lenderTier ?? this.lenderTier,
      dateAdded: dateAdded ?? this.dateAdded,
      dateRemoved: dateRemoved ?? this.dateRemoved,
      isActive: isActive ?? this.isActive,
      supportedPlatforms: supportedPlatforms ?? this.supportedPlatforms,
      sharingOptions: sharingOptions ?? this.sharingOptions,
      slots: slots ?? this.slots,
      gameValue: gameValue ?? this.gameValue,
      totalCost: totalCost ?? this.totalCost,
      totalRevenues: totalRevenues ?? this.totalRevenues,
      borrowRevenue: borrowRevenue ?? this.borrowRevenue,
      sellRevenue: sellRevenue ?? this.sellRevenue,
      fundShareRevenue: fundShareRevenue ?? this.fundShareRevenue,
      totalBorrows: totalBorrows ?? this.totalBorrows,
      currentBorrows: currentBorrows ?? this.currentBorrows,
      averageBorrowDuration: averageBorrowDuration ?? this.averageBorrowDuration,
      borrowHistory: borrowHistory ?? this.borrowHistory,
      batchNumber: batchNumber ?? this.batchNumber,
      nextShareValue: nextShareValue ?? this.nextShareValue,
      fundContributors: fundContributors ?? this.fundContributors,
      contributorShares: contributorShares ?? this.contributorShares,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}