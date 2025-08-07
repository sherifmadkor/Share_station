import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/user_model.dart' hide Platform;

import '../../widgets/game/game_details_modal.dart';

class BrowseGamesScreen extends StatefulWidget {
  const BrowseGamesScreen({Key? key}) : super(key: key);

  @override
  State<BrowseGamesScreen> createState() => _BrowseGamesScreenState();
}

class _BrowseGamesScreenState extends State<BrowseGamesScreen> {
  Platform _selectedPlatform = Platform.na;
  String _searchQuery = '';
  LenderTier? _selectedCategory;

  // Dummy data for testing
  final List<GameAccount> _dummyGames = [
    GameAccount(
      accountId: '1',
      title: 'Spider-Man 2',
      includedTitles: ['Spider-Man 2'],
      coverImageUrl: 'https://image.api.playstation.com/vulcan/ap/rnd/202306/1301/0c96c1bbfe3ff9e088549f0f8ee3c6eb9fb318d7a982b66a.jpg',
      email: 'game1@ps.com',
      password: '****',
      contributorId: 'user1',
      contributorName: 'John Doe',
      lenderTier: LenderTier.member,
      dateAdded: DateTime.now().subtract(Duration(days: 30)),
      isActive: true,
      supportedPlatforms: [Platform.ps5],
      sharingOptions: [AccountType.primary, AccountType.secondary],
      slots: {
        'ps5_primary': GameSlot(
          platform: Platform.ps5,
          accountType: AccountType.primary,
          status: SlotStatus.available,
        ),
        'ps5_secondary': GameSlot(
          platform: Platform.ps5,
          accountType: AccountType.secondary,
          status: SlotStatus.taken,
          borrowerId: 'user2',
          borrowDate: DateTime.now().subtract(Duration(days: 2)),
        ),
      },
      gameValue: 350,
      totalCost: 350,
      totalRevenues: 100,
      borrowRevenue: 100,
      sellRevenue: 0,
      fundShareRevenue: 0,
      totalBorrows: 5,
      currentBorrows: 1,
      averageBorrowDuration: 7,
      borrowHistory: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    GameAccount(
      accountId: '2',
      title: 'FC 24',
      includedTitles: ['FC 24'],
      coverImageUrl: 'https://image.api.playstation.com/vulcan/ap/rnd/202306/2622/79a5c4e2f8a3a6d96c3e428e6200c743313c57be1f8e2051.jpg',
      email: 'game2@ps.com',
      password: '****',
      contributorId: 'admin',
      contributorName: 'Admin',
      lenderTier: LenderTier.gamesVault,
      dateAdded: DateTime.now().subtract(Duration(days: 60)),
      isActive: true,
      supportedPlatforms: [Platform.ps4, Platform.ps5],
      sharingOptions: [AccountType.primary],
      slots: {
        'ps4_primary': GameSlot(
          platform: Platform.ps4,
          accountType: AccountType.primary,
          status: SlotStatus.available,
        ),
        'ps5_primary': GameSlot(
          platform: Platform.ps5,
          accountType: AccountType.primary,
          status: SlotStatus.available,
        ),
      },
      gameValue: 400,
      totalCost: 400,
      totalRevenues: 200,
      borrowRevenue: 200,
      sellRevenue: 0,
      fundShareRevenue: 0,
      totalBorrows: 10,
      currentBorrows: 0,
      averageBorrowDuration: 5,
      borrowHistory: [],
      batchNumber: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    GameAccount(
      accountId: '3',
      title: 'God of War Ragnarök',
      includedTitles: ['God of War Ragnarök'],
      coverImageUrl: 'https://image.api.playstation.com/vulcan/ap/rnd/202207/1210/5bmwDsOQXgisXFCyh2e8C0IJ.jpg',
      email: 'game3@ps.com',
      password: '****',
      contributorId: 'user3',
      contributorName: 'Jane Smith',
      lenderTier: LenderTier.member,
      dateAdded: DateTime.now().subtract(Duration(days: 45)),
      isActive: true,
      supportedPlatforms: [Platform.ps4, Platform.ps5],
      sharingOptions: [AccountType.psPlus],
      slots: {
        'ps4_psplus': GameSlot(
          platform: Platform.ps4,
          accountType: AccountType.psPlus,
          status: SlotStatus.available,
        ),
        'ps5_psplus': GameSlot(
          platform: Platform.ps5,
          accountType: AccountType.psPlus,
          status: SlotStatus.reserved,
          reservedById: 'user4',
          reservationDate: DateTime.now(),
        ),
      },
      gameValue: 300,
      totalCost: 300,
      totalRevenues: 150,
      borrowRevenue: 150,
      sellRevenue: 0,
      fundShareRevenue: 0,
      totalBorrows: 8,
      currentBorrows: 0,
      averageBorrowDuration: 6,
      borrowHistory: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  List<GameAccount> get filteredGames {
    return _dummyGames.where((game) {
      // Filter by search query
      if (_searchQuery.isNotEmpty &&
          !game.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }

      // Filter by platform
      if (_selectedPlatform != Platform.na &&
          !game.supportedPlatforms.contains(_selectedPlatform)) {
        return false;
      }

      // Filter by category
      if (_selectedCategory != null &&
          game.lenderTier != _selectedCategory) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic ? 'تصفح الألعاب' : 'Browse Games',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16.w),
            color: isDarkMode ? AppTheme.darkSurface : Colors.grey.shade50,
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: isArabic ? 'ابحث عن لعبة...' : 'Search for a game...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: isDarkMode ? AppTheme.darkBackground : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Platform Filter Chips
          Container(
            height: 50.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildPlatformChip(
                  label: isArabic ? 'الكل' : 'All',
                  platform: Platform.na,
                  isSelected: _selectedPlatform == Platform.na,
                ),
                SizedBox(width: 8.w),
                _buildPlatformChip(
                  label: 'PS5',
                  platform: Platform.ps5,
                  isSelected: _selectedPlatform == Platform.ps5,
                ),
                SizedBox(width: 8.w),
                _buildPlatformChip(
                  label: 'PS4',
                  platform: Platform.ps4,
                  isSelected: _selectedPlatform == Platform.ps4,
                ),
              ],
            ),
          ),

          // Borrow Window Status
          if (!appProvider.isBorrowWindowCurrentlyOpen())
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppTheme.warningColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.warningColor,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'نافذة الاستعارة مغلقة. تفتح كل يوم جمعة.'
                          : 'Borrow window is closed. Opens every Friday.',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Games Grid
          Expanded(
            child: filteredGames.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FontAwesomeIcons.gamepad,
                    size: 64.sp,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    isArabic ? 'لا توجد ألعاب متاحة' : 'No games available',
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : GridView.builder(
              padding: EdgeInsets.all(16.w),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 16.w,
                mainAxisSpacing: 16.h,
              ),
              itemCount: filteredGames.length,
              itemBuilder: (context, index) {
                return _buildGameCard(filteredGames[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformChip({
    required String label,
    required Platform platform,
    required bool isSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPlatform = platform;
        });
      },
      selectedColor: AppTheme.primaryColor,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }

  Widget _buildGameCard(GameAccount game) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    final isAvailable = game.availableSlotsCount > 0;
    final categoryColor = _getCategoryColor(game.lenderTier);

    return InkWell(
      onTap: () => _showGameDetails(game),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Cover
            Stack(
              children: [
                Container(
                  height: 150.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
                    color: Colors.grey.shade200,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
                    child: game.coverImageUrl != null
                        ? CachedNetworkImage(
                      imageUrl: game.coverImageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Icon(
                          FontAwesomeIcons.gamepad,
                          size: 40.sp,
                          color: Colors.grey,
                        ),
                      ),
                    )
                        : Center(
                      child: Icon(
                        FontAwesomeIcons.gamepad,
                        size: 40.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                // Category Badge
                Positioned(
                  top: 8.h,
                  right: isArabic ? null : 8.w,
                  left: isArabic ? 8.w : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      _getCategoryLabel(game.lenderTier, isArabic),
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Availability Badge
                Positioned(
                  bottom: 8.h,
                  left: isArabic ? null : 8.w,
                  right: isArabic ? 8.w : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? AppTheme.successColor.withOpacity(0.9)
                          : AppTheme.errorColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      isAvailable
                          ? (isArabic ? 'متاح' : 'Available')
                          : (isArabic ? 'غير متاح' : 'Unavailable'),
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Game Info
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      ...game.supportedPlatforms.map((platform) {
                        return Container(
                          margin: EdgeInsets.only(right: 4.w),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: platform == Platform.ps5
                                ? Colors.blue
                                : Colors.indigo,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            platform.displayName,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${game.gameValue.toStringAsFixed(0)} LE',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(LenderTier tier) {
    switch (tier) {
      case LenderTier.gamesVault:
        return AppTheme.vipColor;
      case LenderTier.member:
        return AppTheme.memberColor;
      case LenderTier.admin:
        return AppTheme.adminColor;
      default:
        return AppTheme.userColor;
    }
  }

  String _getCategoryLabel(LenderTier tier, bool isArabic) {
    switch (tier) {
      case LenderTier.gamesVault:
        return isArabic ? 'خزينة الألعاب' : 'Games Vault';
      case LenderTier.member:
        return isArabic ? 'ألعاب الأعضاء' : "Members' Games";
      case LenderTier.admin:
        return isArabic ? 'ألعاب الإدارة' : "Admin Games";
      default:
        return isArabic ? 'ألعاب المستخدمين' : "User Games";
    }
  }

  void _showFilterDialog() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isArabic ? 'تصفية الألعاب' : 'Filter Games'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Category filter would go here
              Text(isArabic ? 'خيارات التصفية' : 'Filter options'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Apply filters
                Navigator.pop(context);
              },
              child: Text(isArabic ? 'تطبيق' : 'Apply'),
            ),
          ],
        );
      },
    );
  }

  void _showGameDetails(GameAccount game) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GameDetailsModal(game: game),
    ).then((result) {
      if (result == true) {
        // Refresh the games list if a borrow was made
        setState(() {});
      }
    });
  }
}