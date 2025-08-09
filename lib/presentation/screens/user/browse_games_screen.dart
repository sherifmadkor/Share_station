// lib/presentation/screens/user/browse_games_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_model.dart' as game_models;
import '../../../data/models/user_model.dart' hide Platform;
import '../../widgets/custom_loading.dart';
import '../../widgets/game/game_details_modal.dart';

class BrowseGamesScreen extends StatefulWidget {
  const BrowseGamesScreen({Key? key}) : super(key: key);

  @override
  State<BrowseGamesScreen> createState() => _BrowseGamesScreenState();
}

class _BrowseGamesScreenState extends State<BrowseGamesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Filters
  game_models.Platform _selectedPlatform = game_models.Platform.na;
  String _searchQuery = '';
  game_models.LenderTier? _selectedCategory;

  // Loading state
  bool _isLoading = false;
  List<game_models.GameAccount> _games = [];

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  // Load games from Firebase
  Future<void> _loadGames() async {
    setState(() => _isLoading = true);

    try {
      // Get games from Firebase
      final QuerySnapshot snapshot = await _firestore
          .collection('games')
          .where('isActive', isEqualTo: true)
          .get();

      final List<game_models.GameAccount> loadedGames = [];

      for (var doc in snapshot.docs) {
        try {
          final game = game_models.GameAccount.fromFirestore(doc);
          loadedGames.add(game);
        } catch (e) {
          print('Error parsing game ${doc.id}: $e');
        }
      }

      // Sort by date added (newest first)
      loadedGames.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));

      setState(() {
        _games = loadedGames;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading games: $e');
      setState(() => _isLoading = false);
    }
  }

  // Get filtered games based on search and filters
  List<game_models.GameAccount> get filteredGames {
    return _games.where((game) {
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        bool matchesSearch = game.title.toLowerCase().contains(query);

        // Also search in included titles
        for (var title in game.includedTitles) {
          if (title.toLowerCase().contains(query)) {
            matchesSearch = true;
            break;
          }
        }

        if (!matchesSearch) return false;
      }

      // Filter by platform
      if (_selectedPlatform != game_models.Platform.na) {
        bool hasPlatform = false;

        // Check if any account supports this platform
        if (game.accounts != null && game.accounts!.isNotEmpty) {
          for (var account in game.accounts!) {
            final platforms = account['platforms'] as List<dynamic>?;
            if (platforms != null && platforms.contains(_selectedPlatform.value)) {
              hasPlatform = true;
              break;
            }
          }
        } else {
          hasPlatform = game.supportedPlatforms.contains(_selectedPlatform);
        }

        if (!hasPlatform) return false;
      }

      // Filter by category
      if (_selectedCategory != null && game.lenderTier != _selectedCategory) {
        return false;
      }

      return true;
    }).toList();
  }

  // Get count of available slots for a game
  int _getAvailableSlots(game_models.GameAccount game) {
    int available = 0;

    if (game.accounts != null && game.accounts!.isNotEmpty) {
      // New structure with multiple accounts
      for (var account in game.accounts!) {
        final slots = account['slots'] as Map<String, dynamic>?;
        if (slots != null) {
          slots.forEach((key, slotData) {
            if (slotData['status'] == 'available') {
              available++;
            }
          });
        }
      }
    } else {
      // Old structure
      game.slots.forEach((key, slot) {
        if (slot.status == game_models.SlotStatus.available) {
          available++;
        }
      });
    }

    return available;
  }

  // Get total slots for a game
  int _getTotalSlots(game_models.GameAccount game) {
    int total = 0;

    if (game.accounts != null && game.accounts!.isNotEmpty) {
      // New structure with multiple accounts
      for (var account in game.accounts!) {
        final slots = account['slots'] as Map<String, dynamic>?;
        if (slots != null) {
          total += slots.length;
        }
      }
    } else {
      // Old structure
      total = game.slots.length;
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          isArabic ? 'تصفح الألعاب' : 'Browse Games',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadGames,
            tooltip: isArabic ? 'تحديث' : 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterDialog,
            tooltip: isArabic ? 'تصفية' : 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: isArabic ? 'ابحث عن لعبة...' : 'Search for a game...',
                prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                filled: true,
                fillColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
            ),
          ),

          // Platform Filter Chips
          Container(
            height: 60.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildPlatformChip(
                  label: isArabic ? 'الكل' : 'All',
                  platform: game_models.Platform.na,
                  isSelected: _selectedPlatform == game_models.Platform.na,
                  icon: Icons.apps,
                ),
                SizedBox(width: 8.w),
                _buildPlatformChip(
                  label: 'PS5',
                  platform: game_models.Platform.ps5,
                  isSelected: _selectedPlatform == game_models.Platform.ps5,
                  icon: FontAwesomeIcons.playstation,
                ),
                SizedBox(width: 8.w),
                _buildPlatformChip(
                  label: 'PS4',
                  platform: game_models.Platform.ps4,
                  isSelected: _selectedPlatform == game_models.Platform.ps4,
                  icon: FontAwesomeIcons.playstation,
                ),
              ],
            ),
          ),

          // Category Filter (Lender Tier)
          if (_selectedCategory != null)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: _getCategoryColor(_selectedCategory!).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: _getCategoryColor(_selectedCategory!)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.category,
                    size: 16.sp,
                    color: _getCategoryColor(_selectedCategory!),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    _getCategoryLabel(_selectedCategory!, isArabic),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: _getCategoryColor(_selectedCategory!),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = null;
                      });
                    },
                    child: Icon(
                      Icons.close,
                      size: 18.sp,
                      color: _getCategoryColor(_selectedCategory!),
                    ),
                  ),
                ],
              ),
            ),

          // Borrow Window Status
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('settings').doc('borrow_window').snapshots(),
            builder: (context, snapshot) {
              bool isWindowOpen = false;
              String nextWindowTime = '';

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                isWindowOpen = data?['isOpen'] ?? false;

                // Calculate next Thursday if window is closed
                if (!isWindowOpen) {
                  final now = DateTime.now();
                  final daysUntilThursday = (DateTime.thursday - now.weekday) % 7;
                  final nextThursday = now.add(Duration(days: daysUntilThursday == 0 ? 7 : daysUntilThursday));
                  nextWindowTime = isArabic
                      ? 'تفتح يوم الخميس القادم'
                      : 'Opens next Thursday';
                }
              }

              if (!isWindowOpen) {
                return Container(
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
                        Icons.schedule,
                        color: AppTheme.warningColor,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'نافذة الاستعارة مغلقة حالياً'
                                  : 'Borrow window is currently closed',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppTheme.warningColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (nextWindowTime.isNotEmpty)
                              Text(
                                nextWindowTime,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppTheme.warningColor.withOpacity(0.8),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),

          // Games Count
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic
                      ? '${filteredGames.length} ${filteredGames.length == 1 ? "لعبة" : "ألعاب"}'
                      : '${filteredGames.length} ${filteredGames.length == 1 ? "Game" : "Games"}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (_isLoading)
                  SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
              ],
            ),
          ),

          // Games Grid
          Expanded(
            child: _isLoading && _games.isEmpty
                ? Center(child: CustomLoading())
                : filteredGames.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FontAwesomeIcons.gamepad,
                    size: 64.sp,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    _searchQuery.isNotEmpty
                        ? (isArabic ? 'لا توجد نتائج للبحث' : 'No search results')
                        : (isArabic ? 'لا توجد ألعاب متاحة' : 'No games available'),
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      child: Text(
                        isArabic ? 'مسح البحث' : 'Clear search',
                        style: TextStyle(color: AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadGames,
              child: GridView.builder(
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
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformChip({
    required String label,
    required game_models.Platform platform,
    required bool isSelected,
    required IconData icon,
  }) {
    return FilterChip(
      avatar: Icon(
        icon,
        size: 16.sp,
        color: isSelected ? Colors.white : AppTheme.primaryColor,
      ),
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

  Widget _buildGameCard(game_models.GameAccount game) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    final availableSlots = _getAvailableSlots(game);
    final totalSlots = _getTotalSlots(game);
    final isAvailable = availableSlots > 0;
    final categoryColor = _getCategoryColor(game.lenderTier);

    return InkWell(
      onTap: () => _showGameDetails(game),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
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
                  height: 160.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.grey.shade300,
                        Colors.grey.shade400,
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                    child: game.coverImageUrl != null && game.coverImageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: game.coverImageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        child: Center(
                          child: Icon(
                            FontAwesomeIcons.gamepad,
                            size: 40.sp,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    )
                        : Container(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      child: Center(
                        child: Icon(
                          FontAwesomeIcons.gamepad,
                          size: 40.sp,
                          color: AppTheme.primaryColor,
                        ),
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
                      color: categoryColor.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(6.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
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
                          ? AppTheme.successColor.withOpacity(0.95)
                          : AppTheme.errorColor.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(6.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAvailable ? Icons.check_circle : Icons.cancel,
                          size: 12.sp,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '$availableSlots/$totalSlots',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Game Info
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
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
                        // Platform badges
                        _buildPlatformBadges(game),
                      ],
                    ),
                    // Price and Account Info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${game.gameValue.toStringAsFixed(0)} LE',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (game.totalAccounts != null && game.totalAccounts! > 1)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: AppTheme.infoColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  '${game.totalAccounts} ${isArabic ? "حساب" : "accounts"}',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: AppTheme.infoColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformBadges(game_models.GameAccount game) {
    List<String> platforms = [];

    if (game.accounts != null && game.accounts!.isNotEmpty) {
      // New structure - collect unique platforms from all accounts
      Set<String> uniquePlatforms = {};
      for (var account in game.accounts!) {
        final accountPlatforms = account['platforms'] as List<dynamic>?;
        if (accountPlatforms != null) {
          uniquePlatforms.addAll(accountPlatforms.map((p) => p.toString()));
        }
      }
      platforms = uniquePlatforms.toList();
    } else {
      // Old structure
      platforms = game.supportedPlatforms.map((p) => p.value).toList();
    }

    return Wrap(
      spacing: 4.w,
      children: platforms.map((platform) {
        final isPS5 = platform.toLowerCase().contains('ps5');
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: isPS5 ? Colors.blue : Colors.indigo,
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text(
            platform.toUpperCase(),
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getCategoryColor(game_models.LenderTier tier) {
    switch (tier) {
      case game_models.LenderTier.gamesVault:
        return AppTheme.vipColor;
      case game_models.LenderTier.member:
        return AppTheme.memberColor;
      case game_models.LenderTier.admin:
        return AppTheme.adminColor;
      case game_models.LenderTier.nonMember:
        return AppTheme.userColor;
    }
  }

  String _getCategoryLabel(game_models.LenderTier tier, bool isArabic) {
    switch (tier) {
      case game_models.LenderTier.gamesVault:
        return isArabic ? 'خزينة الألعاب' : 'Games Vault';
      case game_models.LenderTier.member:
        return isArabic ? 'ألعاب الأعضاء' : "Members' Games";
      case game_models.LenderTier.admin:
        return isArabic ? 'ألعاب الإدارة' : "Admin Games";
      case game_models.LenderTier.nonMember:
        return isArabic ? 'غير الأعضاء' : "Non-Members";
    }
  }

  void _showFilterDialog() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    showDialog(
      context: context,
      builder: (dialogContext) {
        game_models.LenderTier? tempCategory = _selectedCategory;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isArabic ? 'تصفية الألعاب' : 'Filter Games',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'الفئة:' : 'Category:',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _buildCategoryChip(
                          label: isArabic ? 'الكل' : 'All',
                          tier: null,
                          isSelected: tempCategory == null,
                          onSelected: () {
                            setDialogState(() {
                              tempCategory = null;
                            });
                          },
                        ),
                        _buildCategoryChip(
                          label: _getCategoryLabel(game_models.LenderTier.member, isArabic),
                          tier: game_models.LenderTier.member,
                          isSelected: tempCategory == game_models.LenderTier.member,
                          onSelected: () {
                            setDialogState(() {
                              tempCategory = game_models.LenderTier.member;
                            });
                          },
                        ),
                        _buildCategoryChip(
                          label: _getCategoryLabel(game_models.LenderTier.gamesVault, isArabic),
                          tier: game_models.LenderTier.gamesVault,
                          isSelected: tempCategory == game_models.LenderTier.gamesVault,
                          onSelected: () {
                            setDialogState(() {
                              tempCategory = game_models.LenderTier.gamesVault;
                            });
                          },
                        ),
                        _buildCategoryChip(
                          label: _getCategoryLabel(game_models.LenderTier.nonMember, isArabic),
                          tier: game_models.LenderTier.nonMember,
                          isSelected: tempCategory == game_models.LenderTier.nonMember,
                          onSelected: () {
                            setDialogState(() {
                              tempCategory = game_models.LenderTier.nonMember;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    isArabic ? 'إلغاء' : 'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = tempCategory;
                    });
                    Navigator.pop(dialogContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: Text(
                    isArabic ? 'تطبيق' : 'Apply',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required game_models.LenderTier? tier,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    final color = tier != null ? _getCategoryColor(tier) : Colors.grey;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12.sp,
          ),
        ),
      ),
    );
  }

  void _showGameDetails(game_models.GameAccount game) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GameDetailsModal(game: game),
    ).then((result) {
      if (result == true) {
        // Refresh the games list if a borrow was made
        _loadGames();
      }
    });
  }
}