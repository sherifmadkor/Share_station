// lib/data/models/game_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// Platform enum with proper value getter
enum Platform {
  ps4('PS4'),
  ps5('PS5'),
  na('N/A');

  final String displayName;
  const Platform(this.displayName);

  // Use this for storing in Firebase
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

// Account Type enum with multipliers
enum AccountType {
  full('Full Account'),
  primary('Primary'),
  secondary('Secondary'),
  psPlus('PS Plus');

  final String displayName;
  const AccountType(this.displayName);

  // Use this for storing in Firebase
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
      case 'ps plus':
        return AccountType.psPlus;
      default:
        return AccountType.primary;
    }
  }

  // Get borrow value multiplier (for calculating Station Limit deduction)
  double get borrowMultiplier {
    switch (this) {
      case AccountType.full:
      case AccountType.primary:
        return 1.0;  // 100% of game value
      case AccountType.secondary:
        return 0.75; // 75% of game value
      case AccountType.psPlus:
        return 2.0;  // 200% of game value
    }
  }

  // Get share count value (for calculating total shares)
  double get shareValue {
    switch (this) {
      case AccountType.full:
      case AccountType.primary:
        return 1.0;  // Counts as 1 share
      case AccountType.secondary:
        return 0.5;  // Counts as 0.5 share
      case AccountType.psPlus:
        return 2.0;  // Counts as 2 shares
    }
  }

  // Get borrow limit impact
  double get borrowLimitImpact {
    switch (this) {
      case AccountType.full:
      case AccountType.primary:
        return 1.0;  // Uses 1 borrow slot
      case AccountType.secondary:
        return 0.5;  // Uses 0.5 borrow slot
      case AccountType.psPlus:
        return 2.0;  // Uses 2 borrow slots
    }
  }
}

// Slot Status enum
enum SlotStatus {
  available('Available'),
  taken('Taken'),
  reserved('Reserved'),
  notAvailable('Not Available');

  final String displayName;
  const SlotStatus(this.displayName);

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
      case 'not available':
      default:
        return SlotStatus.notAvailable;
    }
  }

  bool get canBorrow => this == SlotStatus.available;
  bool get isOccupied => this == SlotStatus.taken || this == SlotStatus.reserved;
}

// Lender Tier enum
enum LenderTier {
  gamesVault('Games Vault'),
  member('Member'),
  nonMember('Non-Member'),
  admin('Admin');

  final String displayName;
  const LenderTier(this.displayName);

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
      case 'vault':
        return LenderTier.gamesVault;
      case 'member':
        return LenderTier.member;
      case 'nonmember':
      case 'non-member':
        return LenderTier.nonMember;
      case 'admin':
        return LenderTier.admin;
      default:
        return LenderTier.nonMember;
    }
  }

  // Priority order for borrowing
  int get priority {
    switch (this) {
      case LenderTier.member:
        return 1; // Highest priority (free for members)
      case LenderTier.gamesVault:
        return 2; // Second priority
      case LenderTier.admin:
        return 3;
      case LenderTier.nonMember:
        return 4; // Lowest priority
    }
  }
}

// Game Slot class representing each borrowable slot
class GameSlot {
  final Platform platform;
  final AccountType accountType;
  final SlotStatus status;
  final String? borrowerId;
  final String? borrowerName;
  final DateTime? borrowDate;
  final DateTime? expectedReturnDate;
  final DateTime? reservationDate;
  final String? reservedById;
  final String? reservedByName;

  GameSlot({
    required this.platform,
    required this.accountType,
    required this.status,
    this.borrowerId,
    this.borrowerName,
    this.borrowDate,
    this.expectedReturnDate,
    this.reservationDate,
    this.reservedById,
    this.reservedByName,
  });

  // Generate slot key for Firebase
  String get slotKey => '${platform.value}_${accountType.value}';

  // Check if slot is available for specific user
  bool isAvailableFor(String userId) {
    if (status == SlotStatus.available) return true;
    if (status == SlotStatus.reserved && reservedById == userId) return true;
    return false;
  }

  // Calculate days remaining for borrow
  int? get daysRemaining {
    if (expectedReturnDate == null) return null;
    return expectedReturnDate!.difference(DateTime.now()).inDays;
  }

  // Check if overdue
  bool get isOverdue {
    if (expectedReturnDate == null) return false;
    return DateTime.now().isAfter(expectedReturnDate!);
  }

  Map<String, dynamic> toMap() {
    return {
      'platform': platform.value,
      'accountType': accountType.value,
      'status': status.value,
      'borrowerId': borrowerId,
      'borrowerName': borrowerName,
      'borrowDate': borrowDate != null ? Timestamp.fromDate(borrowDate!) : null,
      'expectedReturnDate': expectedReturnDate != null
          ? Timestamp.fromDate(expectedReturnDate!) : null,
      'reservationDate': reservationDate != null
          ? Timestamp.fromDate(reservationDate!) : null,
      'reservedById': reservedById,
      'reservedByName': reservedByName,
    };
  }

  factory GameSlot.fromMap(Map<String, dynamic> map) {
    return GameSlot(
      platform: Platform.fromString(map['platform'] ?? 'na'),
      accountType: AccountType.fromString(map['accountType'] ?? 'primary'),
      status: SlotStatus.fromString(map['status'] ?? 'notAvailable'),
      borrowerId: map['borrowerId'],
      borrowerName: map['borrowerName'],
      borrowDate: map['borrowDate'] != null
          ? (map['borrowDate'] as Timestamp).toDate() : null,
      expectedReturnDate: map['expectedReturnDate'] != null
          ? (map['expectedReturnDate'] as Timestamp).toDate() : null,
      reservationDate: map['reservationDate'] != null
          ? (map['reservationDate'] as Timestamp).toDate() : null,
      reservedById: map['reservedById'],
      reservedByName: map['reservedByName'],
    );
  }

  GameSlot copyWith({
    Platform? platform,
    AccountType? accountType,
    SlotStatus? status,
    String? borrowerId,
    String? borrowerName,
    DateTime? borrowDate,
    DateTime? expectedReturnDate,
    DateTime? reservationDate,
    String? reservedById,
    String? reservedByName,
  }) {
    return GameSlot(
      platform: platform ?? this.platform,
      accountType: accountType ?? this.accountType,
      status: status ?? this.status,
      borrowerId: borrowerId ?? this.borrowerId,
      borrowerName: borrowerName ?? this.borrowerName,
      borrowDate: borrowDate ?? this.borrowDate,
      expectedReturnDate: expectedReturnDate ?? this.expectedReturnDate,
      reservationDate: reservationDate ?? this.reservationDate,
      reservedById: reservedById ?? this.reservedById,
      reservedByName: reservedByName ?? this.reservedByName,
    );
  }
}

// MAIN CLASS - KEEPING THE NAME GameAccount FOR BACKWARD COMPATIBILITY
// This represents a game title that can have multiple accounts
class GameAccount {
  // Basic Info
  final String accountId; // This is actually the game ID
  final String title;
  final List<String> includedTitles; // For accounts with multiple games
  final String? coverImageUrl;
  final String? description;

  // Account Details (for backward compatibility - will use first account's data)
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

  // Multiple accounts support (NEW)
  final List<Map<String, dynamic>>? accounts; // Array of accounts for same game
  final int? totalAccounts;
  final int? availableAccounts;

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
    this.accounts,
    this.totalAccounts,
    this.availableAccounts,
    required this.createdAt,
    required this.updatedAt,
    this.additionalData,
  });

  // Calculate profit
  double get profit => totalRevenues - totalCost;

  // Check if available for borrowing
  bool isAvailableForBorrowing(Platform platform, AccountType accountType) {
    final slotKey = '${platform.value}_${accountType.value}';
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

  // Check if has any available slot
  bool get hasAvailableSlots => availableSlotsCount > 0;

  // Factory constructor from Firestore - UPDATED to handle multiple accounts
  factory GameAccount.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Handle multiple accounts structure (NEW)
    List<Map<String, dynamic>>? accountsList;
    Map<String, GameSlot> allSlots = {};
    String firstEmail = '';
    String firstPassword = '';
    String? firstEdition;
    String? firstRegion;
    String firstContributorId = '';
    String firstContributorName = '';
    List<Platform> allPlatforms = [];
    List<AccountType> allSharingOptions = [];

    if (data['accounts'] != null && data['accounts'] is List) {
      accountsList = List<Map<String, dynamic>>.from(data['accounts']);

      // Process all accounts to collect slots and data
      for (var account in accountsList) {
        // Get first account's credentials for backward compatibility
        if (firstEmail.isEmpty) {
          firstEmail = account['credentials']?['email'] ?? '';
          firstPassword = account['credentials']?['password'] ?? '';
          firstEdition = account['edition'];
          firstRegion = account['region'];
          firstContributorId = account['contributorId'] ?? '';
          firstContributorName = account['contributorName'] ?? '';
        }

        // Collect all platforms
        if (account['platforms'] != null) {
          for (var p in account['platforms']) {
            final platform = Platform.fromString(p);
            if (!allPlatforms.contains(platform)) {
              allPlatforms.add(platform);
            }
          }
        }

        // Collect all sharing options
        if (account['sharingOptions'] != null) {
          for (var a in account['sharingOptions']) {
            final accountType = AccountType.fromString(a);
            if (!allSharingOptions.contains(accountType)) {
              allSharingOptions.add(accountType);
            }
          }
        }

        // Parse slots from each account
        if (account['slots'] != null) {
          (account['slots'] as Map<String, dynamic>).forEach((key, value) {
            allSlots[key] = GameSlot.fromMap(value);
          });
        }
      }
    } else {
      // Old structure - single account (backward compatibility)
      firstEmail = data['email'] ?? '';
      firstPassword = data['password'] ?? '';
      firstEdition = data['edition'];
      firstRegion = data['region'];
      firstContributorId = data['contributorId'] ?? '';
      firstContributorName = data['contributorName'] ?? '';

      // Parse platforms
      if (data['supportedPlatforms'] != null) {
        allPlatforms = (data['supportedPlatforms'] as List<dynamic>)
            .map((e) => Platform.fromString(e.toString()))
            .toList();
      }

      // Parse sharing options
      if (data['sharingOptions'] != null) {
        allSharingOptions = (data['sharingOptions'] as List<dynamic>)
            .map((e) => AccountType.fromString(e.toString()))
            .toList();
      }

      // Parse slots
      if (data['slots'] != null) {
        (data['slots'] as Map<String, dynamic>).forEach((key, value) {
          allSlots[key] = GameSlot.fromMap(value);
        });
      }
    }

    return GameAccount(
      accountId: doc.id,
      title: data['title'] ?? '',
      includedTitles: List<String>.from(data['includedTitles'] ?? []),
      coverImageUrl: data['coverImageUrl'],
      description: data['description'],
      email: firstEmail,
      password: firstPassword,
      edition: firstEdition,
      region: firstRegion,
      expiryDate: data['expiryDate'] != null
          ? (data['expiryDate'] as Timestamp).toDate() : null,
      contributorId: firstContributorId,
      contributorName: firstContributorName,
      lenderTier: LenderTier.fromString(data['lenderTier'] ?? 'nonMember'),
      dateAdded: data['dateAdded'] != null
          ? (data['dateAdded'] as Timestamp).toDate()
          : DateTime.now(),
      dateRemoved: data['dateRemoved'] != null
          ? (data['dateRemoved'] as Timestamp).toDate() : null,
      isActive: data['isActive'] ?? true,
      supportedPlatforms: allPlatforms,
      sharingOptions: allSharingOptions,
      slots: allSlots,
      gameValue: (data['gameValue'] ?? data['totalValue'] ?? 0).toDouble(),
      totalCost: (data['totalCost'] ?? data['totalValue'] ?? 0).toDouble(),
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
      accounts: accountsList,
      totalAccounts: data['totalAccounts'] ?? accountsList?.length ?? 1,
      availableAccounts: data['availableAccounts'] ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      additionalData: data['additionalData'],
    );
  }

  // Convert to Firestore document
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
      'lenderTier': lenderTier.value,
      'dateAdded': Timestamp.fromDate(dateAdded),
      'dateRemoved': dateRemoved != null ? Timestamp.fromDate(dateRemoved!) : null,
      'isActive': isActive,
      'supportedPlatforms': supportedPlatforms.map((e) => e.value).toList(),
      'sharingOptions': sharingOptions.map((e) => e.value).toList(),
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
      'accounts': accounts,
      'totalAccounts': totalAccounts,
      'availableAccounts': availableAccounts,
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
    List<Map<String, dynamic>>? accounts,
    int? totalAccounts,
    int? availableAccounts,
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
      accounts: accounts ?? this.accounts,
      totalAccounts: totalAccounts ?? this.totalAccounts,
      availableAccounts: availableAccounts ?? this.availableAccounts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}

// Alias for backward compatibility
typedef Game = GameAccount;