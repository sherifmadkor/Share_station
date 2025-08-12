// lib/presentation/screens/admin/manage_games_vault_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_vault_model.dart';
import '../../../services/game_database_service.dart';
import '../../../services/notification_service.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';

class ManageGamesVaultScreen extends StatefulWidget {
  const ManageGamesVaultScreen({Key? key}) : super(key: key);

  @override
  State<ManageGamesVaultScreen> createState() => _ManageGamesVaultScreenState();
}

class _ManageGamesVaultScreenState extends State<ManageGamesVaultScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameDatabaseService _gameDBService = GameDatabaseService();
  final NotificationService _notificationService = NotificationService();
  
  late TabController _tabController;
  
  // Search state for game selection
  List<Map<String, dynamic>> _gameSuggestions = [];
  bool _isSearchingGames = false;
  Map<String, dynamic>? _selectedGameForVault;
  
  // Fund contribution approvals
  int _pendingFundContributions = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPendingContributions();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPendingContributions() async {
    try {
      print('Loading pending contributions count...');
      
      // Try count query first
      try {
        final snapshot = await _firestore
            .collection('fund_contributions')
            .where('status', isEqualTo: 'pending')
            .count()
            .get();
        setState(() {
          _pendingFundContributions = snapshot.count ?? 0;
        });
        print('Pending contributions count: $_pendingFundContributions');
      } catch (countError) {
        print('Count query failed: $countError');
        // Fallback: get actual documents
        final snapshot = await _firestore
            .collection('fund_contributions')
            .where('status', isEqualTo: 'pending')
            .get();
        setState(() {
          _pendingFundContributions = snapshot.docs.length;
        });
        print('Pending contributions count (fallback): $_pendingFundContributions');
      }
    } catch (e) {
      print('Error loading pending contributions: $e');
      setState(() {
        _pendingFundContributions = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        title: Text(
          isArabic ? 'إدارة خزنة الألعاب' : 'Games Vault Management',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.add_circle_outline, color: Colors.white),
            onSelected: (value) {
              if (value == 'search_api') {
                _showSearchGameDialog(context, isArabic);
              } else if (value == 'manual') {
                _showAddGameDialog(context, isArabic);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'search_api',
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(isArabic ? 'البحث في قاعدة البيانات' : 'Search Game Database'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'manual',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(isArabic ? 'إضافة يدوية' : 'Manual Entry'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3.h,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: Icon(Icons.gamepad),
              text: isArabic ? 'الألعاب' : 'Games',
            ),
            Tab(
              icon: Stack(
                children: [
                  Icon(Icons.approval),
                  if (_pendingFundContributions > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$_pendingFundContributions',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              text: isArabic ? 'الموافقات' : 'Approvals',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGamesTab(isArabic, isDarkMode),
          _buildApprovalsTab(isArabic, isDarkMode),
        ],
      ),
    );
  }

  // Games tab with vault games list
  Widget _buildGamesTab(bool isArabic, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('games_vault')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FontAwesomeIcons.vault, size: 64.sp, color: Colors.grey),
                SizedBox(height: 16.h),
                Text(
                  isArabic ? 'لا توجد ألعاب في الخزنة' : 'No games in vault',
                  style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showSearchGameDialog(context, isArabic),
                      icon: Icon(Icons.search),
                      label: Text(isArabic ? 'بحث في القاعدة' : 'Search Database'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    OutlinedButton.icon(
                      onPressed: () => _showAddGameDialog(context, isArabic),
                      icon: Icon(Icons.edit),
                      label: Text(isArabic ? 'إضافة يدوية' : 'Manual Entry'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final vaultGames = snapshot.data!.docs
            .map((doc) => GamesVaultModel.fromFirestore(doc))
            .toList();

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: vaultGames.length,
          itemBuilder: (context, index) {
            final game = vaultGames[index];
            return _buildVaultGameCard(game, isArabic, isDarkMode);
          },
        );
      },
    );
  }

  // Approvals tab for fund contributions
  Widget _buildApprovalsTab(bool isArabic, bool isDarkMode) {
    print('Building approvals tab...');
    
    // Try without orderBy first to avoid index issues
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('fund_contributions')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        print('StreamBuilder state: ${snapshot.connectionState}');
        print('Has data: ${snapshot.hasData}');
        print('Error: ${snapshot.error}');
        
        if (snapshot.hasError) {
          print('StreamBuilder error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64.sp, color: Colors.red),
                SizedBox(height: 16.h),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(fontSize: 14.sp, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: () {
                    // Try alternative query without orderBy
                    setState(() {});
                  },
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16.h),
                Text('Loading fund contributions...'),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          print('No snapshot data');
          return Center(
            child: Text('No data available'),
          );
        }
        
        var docs = snapshot.data!.docs;
        print('Found ${docs.length} fund contribution documents');
        
        // Manual sort by createdAt (descending) since orderBy might have index issues
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Descending order
        });
        
        // Debug: Print each document
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          print('Doc ${doc.id}: ${data['gameTitle']} - ${data['status']} - ${data['amount']} LE');
        }
        
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.approval, size: 64.sp, color: Colors.grey),
                SizedBox(height: 16.h),
                Text(
                  isArabic ? 'لا توجد طلبات تمويل معلقة' : 'No pending fund contributions',
                  style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                ),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: () async {
                    // Debug: Check all fund contributions
                    final allContributions = await _firestore
                        .collection('fund_contributions')
                        .get();
                    print('Total contributions in DB: ${allContributions.docs.length}');
                    for (var doc in allContributions.docs) {
                      final data = doc.data();
                      print('All: ${data['gameTitle']} - Status: ${data['status']}');
                    }
                  },
                  child: Text('Debug: Check All'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            print('Building card for: ${data['gameTitle']}');
            return _buildFundContributionCard(doc.id, data, isArabic, isDarkMode);
          },
        );
      },
    );
  }

  Widget _buildVaultGameCard(GamesVaultModel game, bool isArabic, bool isDarkMode) {
    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      elevation: 4,
      child: ExpansionTile(
        leading: game.coverImageUrl != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: Image.network(
            game.coverImageUrl!,
            width: 50.w,
            height: 50.w,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(FontAwesomeIcons.gamepad),
          ),
        )
            : Icon(FontAwesomeIcons.gamepad, size: 40.sp),
        title: Text(
          game.gameTitle,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: _getStatusColor(game.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    game.status.displayName,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: _getStatusColor(game.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  'Batch #${game.batchNumber}',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // Funding progress
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${game.currentFunding.toStringAsFixed(0)}/${game.targetAmount.toStringAsFixed(0)} LE',
                      style: TextStyle(fontSize: 13.sp),
                    ),
                    Text(
                      '${game.fundingPercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                LinearProgressIndicator(
                  value: game.fundingPercentage / 100,
                  minHeight: 6.h,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    game.isFullyFunded ? AppTheme.successColor : AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contributors section
                Text(
                  isArabic ? 'المساهمون' : 'Contributors',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),
                if (game.contributors.isEmpty)
                  Text(
                    isArabic ? 'لا يوجد مساهمون بعد' : 'No contributors yet',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  )
                else
                  ...game.contributors.entries.map((entry) {
                    final percentage = game.contributorShares[entry.key] ?? 0;
                    return Padding(
                      padding: EdgeInsets.only(bottom: 4.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key.substring(0, 8) + '...',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                          Text(
                            '${entry.value.toStringAsFixed(0)} LE (${percentage.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                SizedBox(height: 16.h),

                // Share value info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'قيمة السهم الحالية' : 'Current Share Value',
                      style: TextStyle(fontSize: 13.sp),
                    ),
                    Text(
                      '${game.currentShareValue.toStringAsFixed(0)} LE',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: game.acceptingNewShares ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (game.status == VaultGameStatus.funding && game.isFullyFunded)
                      ElevatedButton.icon(
                        onPressed: () => _markAsFunded(game.id, isArabic),
                        icon: Icon(Icons.check_circle, size: 16.sp),
                        label: Text(isArabic ? 'تم التمويل' : 'Mark Funded'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        ),
                      ),
                    if (game.status == VaultGameStatus.funded)
                      ElevatedButton.icon(
                        onPressed: () => _markAsPurchased(game.id, isArabic),
                        icon: Icon(Icons.shopping_cart, size: 16.sp),
                        label: Text(isArabic ? 'تم الشراء' : 'Mark Purchased'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.infoColor,
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _showEditVaultGameDialog(game, isArabic),
                      icon: Icon(Icons.edit, size: 16.sp),
                      label: Text(isArabic ? 'تعديل' : 'Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(VaultGameStatus status) {
    switch (status) {
      case VaultGameStatus.funding:
        return AppTheme.warningColor;
      case VaultGameStatus.funded:
        return AppTheme.successColor;
      case VaultGameStatus.available:
        return AppTheme.infoColor;
      case VaultGameStatus.soldOut:
        return AppTheme.errorColor;
    }
  }

  // Search for games from API database
  Future<void> _showSearchGameDialog(BuildContext context, bool isArabic) async {
    final searchController = TextEditingController();
    final targetAmountController = TextEditingController(text: '1500');
    final shareValueController = TextEditingController(text: '250');
    final minShareValueController = TextEditingController(text: '50');
    final descriptionController = TextEditingController();
    
    setState(() {
      _gameSuggestions = [];
      _selectedGameForVault = null;
      _isSearchingGames = false;
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isArabic ? 'بحث عن لعبة للتمويل' : 'Search Game for Funding',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Game Search Field
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'ابحث عن لعبة' : 'Search for a game',
                      hintText: isArabic ? 'ابدأ بالكتابة...' : 'Start typing...',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _isSearchingGames
                          ? SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: CircularProgressIndicator(strokeWidth: 2.w),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onChanged: (value) async {
                      if (value.length >= 2) {
                        setDialogState(() => _isSearchingGames = true);
                        try {
                          final results = await _gameDBService.searchGames(value);
                          setDialogState(() {
                            _gameSuggestions = results;
                            _isSearchingGames = false;
                          });
                        } catch (e) {
                          setDialogState(() => _isSearchingGames = false);
                        }
                      } else {
                        setDialogState(() {
                          _gameSuggestions = [];
                          _isSearchingGames = false;
                        });
                      }
                    },
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  // Game Suggestions
                  if (_gameSuggestions.isNotEmpty)
                    Container(
                      height: 200.h,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _gameSuggestions.length,
                        itemBuilder: (context, index) {
                          final game = _gameSuggestions[index];
                          final isSelected = _selectedGameForVault?['id'] == game['id'];
                          
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
                            leading: game['background_image'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4.r),
                                    child: Image.network(
                                      game['background_image'],
                                      width: 40.w,
                                      height: 40.w,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(FontAwesomeIcons.gamepad),
                                    ),
                                  )
                                : Icon(FontAwesomeIcons.gamepad, size: 32.sp),
                            title: Text(
                              game['name'],
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (game['platforms']?.isNotEmpty == true)
                                  Text(
                                    (game['platforms'] as List).join(', '),
                                    style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                                  ),
                                if (game['rating'] != null)
                                  Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.orange, size: 12.sp),
                                      Text(
                                        ' ${game['rating']}',
                                        style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
                                : null,
                            onTap: () {
                              setDialogState(() {
                                _selectedGameForVault = isSelected ? null : game;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  
                  if (_selectedGameForVault != null) ...[
                    SizedBox(height: 16.h),
                    Divider(),
                    SizedBox(height: 16.h),
                    
                    // Funding Details
                    Text(
                      isArabic ? 'تفاصيل التمويل' : 'Funding Details',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12.h),
                    
                    TextField(
                      controller: targetAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'المبلغ المستهدف' : 'Target Amount',
                        suffixText: 'LE',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: shareValueController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: isArabic ? 'قيمة السهم' : 'Share Value',
                              suffixText: 'LE',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: TextField(
                            controller: minShareValueController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: isArabic ? 'الحد الأدنى' : 'Min Value',
                              suffixText: 'LE',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'وصف اضافي (اختياري)' : 'Additional Description (Optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: _selectedGameForVault == null
                  ? null
                  : () async {
                      await _createVaultGameFromDatabase(
                        _selectedGameForVault!,
                        double.tryParse(targetAmountController.text) ?? 1500,
                        double.tryParse(shareValueController.text) ?? 250,
                        double.tryParse(minShareValueController.text) ?? 50,
                        descriptionController.text.trim(),
                        isArabic,
                      );
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: Text(
                isArabic ? 'بدء التمويل' : 'Start Funding',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Create vault game from database selection
  Future<void> _createVaultGameFromDatabase(
    Map<String, dynamic> selectedGame,
    double targetAmount,
    double shareValue,
    double minShareValue,
    String description,
    bool isArabic,
  ) async {
    try {
      // Get next batch number
      final lastBatch = await _firestore
          .collection('games_vault')
          .orderBy('batchNumber', descending: true)
          .limit(1)
          .get();

      final nextBatchNumber = lastBatch.docs.isEmpty
          ? 1
          : (lastBatch.docs.first.data()['batchNumber'] ?? 0) + 1;

      // Get admin user
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final adminUser = authProvider.currentUser;

      // Create vault game with rich details from API and flexible share values
      final gameData = {
        'gameTitle': selectedGame['name'],
        'coverImageUrl': selectedGame['background_image'],
        'description': description.isNotEmpty 
            ? description 
            : 'Added from game database${selectedGame['released'] != null ? ' • Released: ${selectedGame['released']}' : ''}',
        'batchNumber': nextBatchNumber,
        'targetAmount': targetAmount,
        'currentFunding': 0,
        'contributors': {},
        'contributorShares': {},
        'totalContributors': 0,
        'platforms': selectedGame['platforms'] ?? ['PS5', 'PS4'],
        'accountTypes': ['primary', 'secondary'],
        'genres': selectedGame['genres'] ?? [],
        'rating': selectedGame['rating'],
        'releaseDate': selectedGame['released'],
        'apiGameId': selectedGame['id'],
        'gameSource': selectedGame['source'], // 'rawg_api', 'firestore', 'fallback'
        'status': 'funding',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': adminUser?.uid ?? 'admin',
      };
      
      // Add share values only if specified
      if (shareValue > 0) {
        gameData['currentShareValue'] = shareValue;
      }
      
      if (minShareValue > 0) {
        gameData['minimumShareValue'] = minShareValue;
        gameData['acceptingNewShares'] = shareValue <= 0 || shareValue >= minShareValue;
      } else {
        gameData['acceptingNewShares'] = true; // Always accepting if no minimum
      }
      
      final gameDoc = await _firestore.collection('games_vault').add(gameData);

      // Send notification to all users about new funding
      await _notificationService.notifyNewGameFunding(
        gameTitle: selectedGame['name'],
        gameId: gameDoc.id,
        targetAmount: targetAmount,
        shareValue: shareValue,
        coverImageUrl: selectedGame['background_image'],
      );

      Fluttertoast.showToast(
        msg: isArabic 
            ? 'تم بدء تمويل لعبة ${selectedGame['name']}!' 
            : '${selectedGame['name']} funding started!',
        backgroundColor: AppTheme.successColor,
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  Future<void> _showAddGameDialog(BuildContext context, bool isArabic) async {
    final titleController = TextEditingController();
    final targetAmountController = TextEditingController(text: '1500');
    final shareValueController = TextEditingController(text: '250');
    final minShareValueController = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'إضافة لعبة للتمويل' : 'Add Game for Funding'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: isArabic ? 'اسم اللعبة' : 'Game Title',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: targetAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isArabic ? 'المبلغ المستهدف' : 'Target Amount',
                  suffixText: 'LE',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: shareValueController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isArabic ? 'قيمة السهم الأولية' : 'Initial Share Value',
                  suffixText: 'LE',
                  hintText: isArabic ? 'اختياري - فارغ لعدم التحديد' : 'Optional - Leave empty for no limit',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: minShareValueController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isArabic ? 'أقل قيمة للسهم' : 'Minimum Share Value',
                  suffixText: 'LE',
                  hintText: isArabic ? 'اختياري - فارغ لعدم حد أدنى' : 'Optional - Leave empty for no minimum',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty) {
                Fluttertoast.showToast(msg: 'Please enter game title');
                return;
              }

              // Get next batch number
              final lastBatch = await _firestore
                  .collection('games_vault')
                  .orderBy('batchNumber', descending: true)
                  .limit(1)
                  .get();

              final nextBatchNumber = lastBatch.docs.isEmpty
                  ? 1
                  : (lastBatch.docs.first.data()['batchNumber'] ?? 0) + 1;

              // Create vault game with flexible share values
              final shareValue = double.tryParse(shareValueController.text);
              final minShareValue = double.tryParse(minShareValueController.text);
              
              final gameData = {
                'gameTitle': titleController.text,
                'batchNumber': nextBatchNumber,
                'targetAmount': double.parse(targetAmountController.text),
                'currentFunding': 0,
                'contributors': {},
                'contributorShares': {},
                'totalContributors': 0,
                'platforms': ['PS5', 'PS4'],
                'accountTypes': ['primary', 'secondary'],
                'status': 'funding',
                'createdAt': FieldValue.serverTimestamp(),
              };
              
              // Add share values only if specified
              if (shareValue != null && shareValue > 0) {
                gameData['currentShareValue'] = shareValue;
              }
              
              if (minShareValue != null && minShareValue > 0) {
                gameData['minimumShareValue'] = minShareValue;
                gameData['acceptingNewShares'] = shareValue == null || shareValue >= minShareValue;
              } else {
                gameData['acceptingNewShares'] = true; // Always accepting if no minimum
              }
              
              final gameDoc = await _firestore.collection('games_vault').add(gameData);

              // Send notification to all users about new funding
              await _notificationService.notifyNewGameFunding(
                gameTitle: titleController.text,
                gameId: gameDoc.id,
                targetAmount: double.parse(targetAmountController.text),
                shareValue: double.parse(shareValueController.text),
              );

              Navigator.pop(context);
              Fluttertoast.showToast(
                msg: isArabic ? 'تمت إضافة اللعبة للتمويل' : 'Game added for funding',
                backgroundColor: AppTheme.successColor,
              );
            },
            child: Text(isArabic ? 'إضافة' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsFunded(String gameId, bool isArabic) async {
    await _firestore.collection('games_vault').doc(gameId).update({
      'status': 'funded',
      'fundedAt': FieldValue.serverTimestamp(),
    });

    Fluttertoast.showToast(
      msg: isArabic ? 'تم تحديث حالة اللعبة' : 'Game status updated',
      backgroundColor: AppTheme.successColor,
    );
  }

  Future<void> _markAsPurchased(String gameId, bool isArabic) async {
    try {
      // Get the vault game data first
      final vaultDoc = await _firestore.collection('games_vault').doc(gameId).get();
      if (!vaultDoc.exists) {
        throw Exception('Vault game not found');
      }
      
      final vaultData = vaultDoc.data()!;
      final batch = _firestore.batch();
      
      // Create game in main games collection for borrowing
      final gameRef = _firestore.collection('games').doc();
      
      // Create the game document with proper slots structure
      batch.set(gameRef, {
        'title': vaultData['gameTitle'],
        'coverImageUrl': vaultData['coverImageUrl'],
        'gameValue': vaultData['targetAmount'] ?? 500,
        'lenderTier': 'vault', // This should match your LenderTier enum value
        'isActive': true,
        'vaultGameId': gameId,
        'batchNumber': vaultData['batchNumber'],
        'contributors': vaultData['contributors'] ?? {},
        'platforms': ['PS5', 'PS4'],
        'accountTypes': ['primary', 'secondary'],
        // Create accounts with proper slots structure
        'accounts': [
          {
            'accountId': 'ps5_primary_${DateTime.now().millisecondsSinceEpoch}',
            'platform': 'ps5',
            'accountType': 'primary',
            'isVaultAccount': true,
            'status': 'active',
            'slots': {
              'ps5_primary': {
                'platform': 'ps5',
                'accountType': 'primary',
                'status': 'available',  // THIS IS CRITICAL - must be 'available' not 'taken'
                'borrowerId': null,
                'borrowerName': null,
                'borrowedAt': null,
                'returnBy': null,
                'isVaultSlot': true,
              }
            },
            'credentials': {
              'email': 'vault_ps5_primary@sharestation.com',
              'password': 'vault_${DateTime.now().millisecondsSinceEpoch}',
              'note': 'Vault game account - PS5 primary',
            },
            'dateAdded': Timestamp.now(),
          },
          {
            'accountId': 'ps5_secondary_${DateTime.now().millisecondsSinceEpoch}',
            'platform': 'ps5',
            'accountType': 'secondary',
            'isVaultAccount': true,
            'status': 'active',
            'slots': {
              'ps5_secondary': {
                'platform': 'ps5',
                'accountType': 'secondary',
                'status': 'available',  // Must be 'available'
                'borrowerId': null,
                'borrowerName': null,
                'borrowedAt': null,
                'returnBy': null,
                'isVaultSlot': true,
              }
            },
            'credentials': {
              'email': 'vault_ps5_secondary@sharestation.com',
              'password': 'vault_${DateTime.now().millisecondsSinceEpoch}',
              'note': 'Vault game account - PS5 secondary',
            },
            'dateAdded': Timestamp.now(),
          },
          {
            'accountId': 'ps4_primary_${DateTime.now().millisecondsSinceEpoch}',
            'platform': 'ps4',
            'accountType': 'primary',
            'isVaultAccount': true,
            'status': 'active',
            'slots': {
              'ps4_primary': {
                'platform': 'ps4',
                'accountType': 'primary',
                'status': 'available',  // Must be 'available'
                'borrowerId': null,
                'borrowerName': null,
                'borrowedAt': null,
                'returnBy': null,
                'isVaultSlot': true,
              }
            },
            'credentials': {
              'email': 'vault_ps4_primary@sharestation.com',
              'password': 'vault_${DateTime.now().millisecondsSinceEpoch}',
              'note': 'Vault game account - PS4 primary',
            },
            'dateAdded': Timestamp.now(),
          },
          {
            'accountId': 'ps4_secondary_${DateTime.now().millisecondsSinceEpoch}',
            'platform': 'ps4',
            'accountType': 'secondary',
            'isVaultAccount': true,
            'status': 'active',
            'slots': {
              'ps4_secondary': {
                'platform': 'ps4',
                'accountType': 'secondary',
                'status': 'available',  // Must be 'available'
                'borrowerId': null,
                'borrowerName': null,
                'borrowedAt': null,
                'returnBy': null,
                'isVaultSlot': true,
              }
            },
            'credentials': {
              'email': 'vault_ps4_secondary@sharestation.com',
              'password': 'vault_${DateTime.now().millisecondsSinceEpoch}',
              'note': 'Vault game account - PS4 secondary',
            },
            'dateAdded': Timestamp.now(),
          },
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'vault',
      });
      
      // Update vault game status
      batch.update(_firestore.collection('games_vault').doc(gameId), {
        'status': 'available',
        'purchasedAt': FieldValue.serverTimestamp(),
        'gameId': gameRef.id,
      });
      
      // Commit batch
      await batch.commit();
      
      Fluttertoast.showToast(
        msg: isArabic ? 'تم شراء اللعبة وإتاحتها للاستعارة' : 'Game purchased and available for borrowing',
        backgroundColor: AppTheme.successColor,
        toastLength: Toast.LENGTH_LONG,
      );
      
    } catch (e) {
      print('Error marking game as purchased: $e');
      Fluttertoast.showToast(
        msg: 'Error: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  // Alternative: If you want to use the old slots structure at the root level
  // (without the accounts array), use this version instead:
  Future<void> _markAsPurchasedSimpleSlots(String gameId, bool isArabic) async {
    try {
      // Get the vault game data first
      final vaultDoc = await _firestore.collection('games_vault').doc(gameId).get();
      if (!vaultDoc.exists) {
        throw Exception('Vault game not found');
      }
      
      final vaultData = vaultDoc.data()!;
      final batch = _firestore.batch();
      
      // Create game in main games collection with simple slots structure
      final gameRef = _firestore.collection('games').doc();
      
      batch.set(gameRef, {
        'title': vaultData['gameTitle'],
        'coverImageUrl': vaultData['coverImageUrl'],
        'gameValue': vaultData['targetAmount'] ?? 500,
        'lenderTier': 'vault',
        'isActive': true,
        'vaultGameId': gameId,
        'batchNumber': vaultData['batchNumber'],
        'contributors': vaultData['contributors'] ?? {},
        'platforms': ['PS5', 'PS4'],
        'accountTypes': ['primary', 'secondary'],
        // Use simple slots structure at root level
        'slots': {
          'ps5_primary': {
            'platform': 'ps5',
            'accountType': 'primary',
            'status': 'available',
            'borrowerId': null,
            'borrowerName': null,
            'borrowedAt': null,
            'returnBy': null,
            'isVaultSlot': true,
          },
          'ps5_secondary': {
            'platform': 'ps5',
            'accountType': 'secondary',
            'status': 'available',
            'borrowerId': null,
            'borrowerName': null,
            'borrowedAt': null,
            'returnBy': null,
            'isVaultSlot': true,
          },
          'ps4_primary': {
            'platform': 'ps4',
            'accountType': 'primary',
            'status': 'available',
            'borrowerId': null,
            'borrowerName': null,
            'borrowedAt': null,
            'returnBy': null,
            'isVaultSlot': true,
          },
          'ps4_secondary': {
            'platform': 'ps4',
            'accountType': 'secondary',
            'status': 'available',
            'borrowerId': null,
            'borrowerName': null,
            'borrowedAt': null,
            'returnBy': null,
            'isVaultSlot': true,
          },
        },
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'vault',
      });
      
      // Update vault game status
      batch.update(_firestore.collection('games_vault').doc(gameId), {
        'status': 'available',
        'purchasedAt': FieldValue.serverTimestamp(),
        'gameId': gameRef.id,
      });
      
      // Commit batch
      await batch.commit();
      
      Fluttertoast.showToast(
        msg: isArabic ? 'تم شراء اللعبة وإتاحتها للاستعارة' : 'Game purchased and available for borrowing',
        backgroundColor: AppTheme.successColor,
        toastLength: Toast.LENGTH_LONG,
      );
      
    } catch (e) {
      print('Error marking game as purchased: $e');
      Fluttertoast.showToast(
        msg: 'Error: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }
  
  // Generate vault game accounts structure matching regular games
  List<Map<String, dynamic>> _generateVaultGameAccounts(Map<String, dynamic> vaultData) {
    final contributors = Map<String, double>.from(vaultData['contributors'] ?? {});
    
    List<Map<String, dynamic>> accounts = [];
    
    // Create 4 accounts: PS5/PS4 × primary/secondary
    final platforms = ['PS5', 'PS4'];
    final accountTypes = ['primary', 'secondary'];
    
    for (var platform in platforms) {
      for (var accountType in accountTypes) {
        // Create single account entry matching regular game structure
        accounts.add({
          'accountId': '${platform.toLowerCase()}_${accountType}',
          'platform': platform.toLowerCase(),
          'accountType': accountType,
          'isVaultAccount': true,
          'contributors': contributors.keys.toList(),
          'status': 'available',
          'borrowerId': null,
          'borrowerName': null,
          'borrowedAt': null,
          'returnBy': null,
          'credentials': {
            'email': 'vault_${platform.toLowerCase()}_${accountType}@sharestation.com',
            'password': 'vault_${DateTime.now().millisecondsSinceEpoch}',
            'note': 'Vault game account - ${platform} ${accountType}',
          },
          'dateAdded': Timestamp.now(),
        });
      }
    }
    
    return accounts;
  }

  // Alternative simpler structure if your browse games screen expects a different format:
  Map<String, dynamic> _generateSimpleVaultGameStructure(Map<String, dynamic> vaultData) {
    final contributors = Map<String, double>.from(vaultData['contributors'] ?? {});
    
    // Create slots map similar to regular games
    Map<String, dynamic> slots = {};
    
    // PS5 Primary
    slots['ps5_primary'] = {
      'platform': 'ps5',
      'accountType': 'primary',
      'status': 'available',
      'borrowerId': null,
      'borrowerName': null,
      'borrowedAt': null,
      'returnBy': null,
      'isVaultSlot': true,
    };
    
    // PS5 Secondary
    slots['ps5_secondary'] = {
      'platform': 'ps5',
      'accountType': 'secondary',
      'status': 'available',
      'borrowerId': null,
      'borrowerName': null,
      'borrowedAt': null,
      'returnBy': null,
      'isVaultSlot': true,
    };
    
    // PS4 Primary
    slots['ps4_primary'] = {
      'platform': 'ps4',
      'accountType': 'primary',
      'status': 'available',
      'borrowerId': null,
      'borrowerName': null,
      'borrowedAt': null,
      'returnBy': null,
      'isVaultSlot': true,
    };
    
    // PS4 Secondary
    slots['ps4_secondary'] = {
      'platform': 'ps4',
      'accountType': 'secondary',
      'status': 'available',
      'borrowerId': null,
      'borrowerName': null,
      'borrowedAt': null,
      'returnBy': null,
      'isVaultSlot': true,
    };
    
    return slots;
  }

  // If your browse games screen expects a 'slots' field instead of 'accounts',
  // use this version of _markAsPurchased:
  Future<void> _markAsPurchasedWithSlots(String gameId, bool isArabic) async {
    try {
      // Get the vault game data first
      final vaultDoc = await _firestore.collection('games_vault').doc(gameId).get();
      if (!vaultDoc.exists) {
        throw Exception('Vault game not found');
      }
      
      final vaultData = vaultDoc.data()!;
      final batch = _firestore.batch();
      
      // Create game in main games collection matching regular game structure
      final gameRef = _firestore.collection('games').doc();
      
      batch.set(gameRef, {
        'title': vaultData['gameTitle'],
        'coverImageUrl': vaultData['coverImageUrl'],
        'gameValue': vaultData['targetAmount'] ?? 500,
        'lenderTier': 'vault',
        'isActive': true,
        'vaultGameId': gameId,
        'batchNumber': vaultData['batchNumber'],
        'contributors': vaultData['contributors'] ?? {},
        'platforms': ['PS5', 'PS4'],
        'accountTypes': ['primary', 'secondary'],
        'slots': _generateSimpleVaultGameStructure(vaultData), // Use slots instead of accounts
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'vault',
      });
      
      // Update vault game status
      batch.update(_firestore.collection('games_vault').doc(gameId), {
        'status': 'available',
        'purchasedAt': FieldValue.serverTimestamp(),
        'gameId': gameRef.id,
      });
      
      // Commit batch
      await batch.commit();
      
      Fluttertoast.showToast(
        msg: isArabic ? 'تم شراء اللعبة وإتاحتها للاستعارة' : 'Game purchased and available for borrowing',
        backgroundColor: AppTheme.successColor,
        toastLength: Toast.LENGTH_LONG,
      );
      
    } catch (e) {
      print('Error marking game as purchased: $e');
      Fluttertoast.showToast(
        msg: 'Error: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  // Build fund contribution card for approval
  Widget _buildFundContributionCard(String docId, Map<String, dynamic> data, bool isArabic, bool isDarkMode) {
    final isLateContribution = data['isLateContribution'] ?? false;
    final amount = data['amount']?.toDouble() ?? 0;
    final createdAt = data['createdAt'] as Timestamp?;
    
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with game title and amount
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['gameTitle'] ?? 'Unknown Game',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${amount.toStringAsFixed(0)} LE',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLateContribution)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4.r),
                      border: Border.all(color: AppTheme.warningColor),
                    ),
                    child: Text(
                      isArabic ? 'مساهمة متأخرة' : 'Late Contribution',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            SizedBox(height: 12.h),
            
            // User details
            Row(
              children: [
                Icon(Icons.person, size: 16.sp, color: Colors.grey),
                SizedBox(width: 8.w),
                Text(
                  data['userName'] ?? 'Unknown User',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            
            SizedBox(height: 8.h),
            
            // Payment method
            Row(
              children: [
                Icon(Icons.payment, size: 16.sp, color: Colors.grey),
                SizedBox(width: 8.w),
                Text(
                  data['paymentMethod'] ?? 'Unknown Method',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ],
            ),
            
            SizedBox(height: 8.h),
            
            // Date
            if (createdAt != null)
              Row(
                children: [
                  Icon(Icons.schedule, size: 16.sp, color: Colors.grey),
                  SizedBox(width: 8.w),
                  Text(
                    '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  ),
                ],
              ),
            
            SizedBox(height: 16.h),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Receipt button (if available)
                if (data['receiptUrl'] != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Show receipt image
                      Fluttertoast.showToast(msg: 'Receipt viewing coming soon');
                    },
                    icon: Icon(Icons.receipt, size: 16.sp),
                    label: Text(isArabic ? 'عرض الإيصال' : 'View Receipt'),
                  )
                else
                  SizedBox(),
                
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _approveFundContribution(docId, data, isArabic),
                      icon: Icon(Icons.check, size: 16.sp),
                      label: Text(isArabic ? 'موافقة' : 'Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    ElevatedButton.icon(
                      onPressed: () => _rejectFundContribution(docId, isArabic),
                      icon: Icon(Icons.close, size: 16.sp),
                      label: Text(isArabic ? 'رفض' : 'Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Approve fund contribution with complete logic
  Future<void> _approveFundContribution(String docId, Map<String, dynamic> data, bool isArabic) async {
    try {
      print('Approving fund contribution: $docId');
      
      // Extract contribution data
      final vaultGameId = data['vaultGameId'];
      final amount = data['amount']?.toDouble() ?? 0;
      final userId = data['userId'];
      final userName = data['userName'] ?? 'Unknown User';
      final isLateContribution = data['isLateContribution'] ?? false;
      
      final batch = _firestore.batch();
      
      // Update fund contribution status
      batch.update(
        _firestore.collection('fund_contributions').doc(docId),
        {
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
        },
      );
      
      // Get vault game data
      final vaultRef = _firestore.collection('games_vault').doc(vaultGameId);
      final vaultDoc = await vaultRef.get();
      
      if (!vaultDoc.exists) {
        throw Exception('Vault game not found');
      }
      
      final vaultData = vaultDoc.data()!;
      final currentContributors = Map<String, double>.from(vaultData['contributors'] ?? {});
      final currentFunding = vaultData['currentFunding']?.toDouble() ?? 0;
      final targetAmount = vaultData['targetAmount']?.toDouble() ?? 0;
      final gameTitle = vaultData['gameTitle'] ?? 'Unknown Game';
      
      // Process late contribution refunds BEFORE updating vault
      if (isLateContribution && currentContributors.isNotEmpty) {
        await _distributeRefunds(
          vaultGameId,
          gameTitle,
          amount,
          currentContributors,
          targetAmount,
          batch,
        );
      }
      
      // Add contributor to vault game
      final contributorKey = isLateContribution ? 'late_$userId' : userId;
      currentContributors[contributorKey] = (currentContributors[contributorKey] ?? 0) + amount;
      
      // Calculate contributor shares
      final newTotalFunding = currentFunding + amount;
      final contributorShares = <String, double>{};
      currentContributors.forEach((uid, contribution) {
        contributorShares[uid] = (contribution / newTotalFunding) * 100;
      });
      
      // Calculate next share value (decreasing)
      final currentShareValue = vaultData['currentShareValue']?.toDouble() ?? 250.0;
      final minimumShareValue = vaultData['minimumShareValue']?.toDouble() ?? 50.0;
      final nextShareValue = (currentShareValue - 10).clamp(minimumShareValue, currentShareValue);
      
      // Update vault game
      batch.update(vaultRef, {
        'currentFunding': newTotalFunding,
        'contributors': currentContributors,
        'contributorShares': contributorShares,
        'totalContributors': currentContributors.length,
        'currentShareValue': nextShareValue,
        'acceptingNewShares': nextShareValue > minimumShareValue,
        'lastContribution': {
          'userId': userId,
          'userName': userName,
          'amount': amount,
          'timestamp': FieldValue.serverTimestamp(),
          'isLate': isLateContribution,
        },
      });
      
      // Update user metrics
      final userRef = _firestore.collection('users').doc(userId);
      final fundShares = (amount / 100).floor(); // 1 share per 100 LE
      
      batch.update(userRef, {
        'fundShares': FieldValue.increment(fundShares),
        'totalShares': FieldValue.increment(fundShares),
        'totalSpent': FieldValue.increment(amount),
        'contributedGames': FieldValue.arrayUnion([vaultGameId]),
        'lastContributionDate': FieldValue.serverTimestamp(),
      });
      
      // Deduct from user's balance (if they have sufficient balance)
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final currentBalance = userData['balance']?.toDouble() ?? 0;
        
        if (currentBalance >= amount) {
          batch.update(userRef, {
            'balance': FieldValue.increment(-amount),
          });
        } else {
          // Create a debt entry if insufficient balance
          batch.update(userRef, {
            'debt': FieldValue.increment(amount - currentBalance),
            'balance': 0,
          });
        }
      }
      
      // Execute all updates
      await batch.commit();
      
      print('Fund contribution approved successfully');
      
      // Refresh pending count
      _loadPendingContributions();
      
      // Show success message with details
      final message = isLateContribution
          ? (isArabic 
              ? 'تمت الموافقة على المساهمة المتأخرة وتوزيع المبالغ المستردة'
              : 'Late contribution approved and refunds distributed')
          : (isArabic 
              ? 'تمت الموافقة على المساهمة بنجاح'
              : 'Fund contribution approved successfully');
      
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: AppTheme.successColor,
        toastLength: Toast.LENGTH_LONG,
      );
      
    } catch (e) {
      print('Error approving fund contribution: $e');
      Fluttertoast.showToast(
        msg: 'Error: ${e.toString()}',
        backgroundColor: AppTheme.errorColor,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }
  
  // Reject fund contribution
  Future<void> _rejectFundContribution(String docId, bool isArabic) async {
    try {
      await _firestore.collection('fund_contributions').doc(docId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      
      // Refresh pending count
      _loadPendingContributions();
      
      Fluttertoast.showToast(
        msg: isArabic ? 'تم رفض المساهمة' : 'Fund contribution rejected',
        backgroundColor: AppTheme.warningColor,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }
  
  // Show edit vault game dialog
  Future<void> _showEditVaultGameDialog(GamesVaultModel game, bool isArabic) async {
    final titleController = TextEditingController(text: game.gameTitle);
    final targetAmountController = TextEditingController(text: game.targetAmount.toString());
    final shareValueController = TextEditingController(text: game.currentShareValue.toString());
    final minShareValueController = TextEditingController(text: game.minimumShareValue.toString());
    final descriptionController = TextEditingController(text: game.description ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isArabic ? 'تعديل لعبة الخزنة' : 'Edit Vault Game',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: isArabic ? 'اسم اللعبة' : 'Game Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: targetAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isArabic ? 'المبلغ المستهدف' : 'Target Amount',
                  suffixText: 'LE',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: shareValueController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'قيمة السهم' : 'Share Value',
                        suffixText: 'LE',
                        hintText: isArabic ? 'اختياري' : 'Optional',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: TextField(
                      controller: minShareValueController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'الحد الأدنى' : 'Min Value',
                        suffixText: 'LE',
                        hintText: isArabic ? 'اختياري' : 'Optional',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الوصف' : 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _updateVaultGame(
                game.id,
                titleController.text,
                double.tryParse(targetAmountController.text) ?? game.targetAmount,
                double.tryParse(shareValueController.text),
                double.tryParse(minShareValueController.text),
                descriptionController.text.trim(),
                isArabic,
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text(
              isArabic ? 'حفظ' : 'Save',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  
  // Update vault game
  Future<void> _updateVaultGame(
    String gameId,
    String title,
    double targetAmount,
    double? shareValue,
    double? minShareValue,
    String description,
    bool isArabic,
  ) async {
    try {
      final updateData = <String, dynamic>{
        'gameTitle': title,
        'targetAmount': targetAmount,
        'description': description.isNotEmpty ? description : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Only update share values if provided
      if (shareValue != null && shareValue > 0) {
        updateData['currentShareValue'] = shareValue;
      }
      
      if (minShareValue != null && minShareValue > 0) {
        updateData['minimumShareValue'] = minShareValue;
        updateData['acceptingNewShares'] = shareValue == null || shareValue >= minShareValue;
      } else {
        // No minimum specified - always accepting
        updateData['acceptingNewShares'] = true;
      }
      
      await _firestore.collection('games_vault').doc(gameId).update(updateData);
      
      Fluttertoast.showToast(
        msg: isArabic ? 'تم تحديث اللعبة' : 'Game updated successfully',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }
  
  // Distribute refunds to original contributors for late contributions
  Future<void> _distributeRefunds(
    String vaultGameId,
    String gameTitle,
    double lateContributionAmount,
    Map<String, double> currentContributors,
    double targetAmount,
    WriteBatch batch,
  ) async {
    try {
      print('Distributing refunds for late contribution: $lateContributionAmount LE');
      
      // Get original contributors only (exclude late contributors)
      final originalContributors = <String, double>{};
      currentContributors.forEach((userId, amount) {
        if (!userId.startsWith('late_')) {
          originalContributors[userId] = amount;
        }
      });
      
      if (originalContributors.isEmpty) {
        print('No original contributors found for refund distribution');
        return;
      }
      
      final totalOriginalContribution = originalContributors.values.fold(0.0, (a, b) => a + b);
      print('Original contributors: ${originalContributors.length}, Total: $totalOriginalContribution LE');
      
      // Distribute refunds proportionally based on contribution percentage
      for (var entry in originalContributors.entries) {
        final userId = entry.key;
        final userContribution = entry.value;
        
        // Calculate refund percentage based on their contribution to the target
        final contributionPercentage = userContribution / targetAmount;
        final refundAmount = lateContributionAmount * contributionPercentage;
        
        if (refundAmount > 0) {
          print('Refunding $userId: ${refundAmount.toStringAsFixed(2)} LE (${(contributionPercentage * 100).toStringAsFixed(1)}%)');
          
          // Add to user's refunds balance
          batch.update(
            _firestore.collection('users').doc(userId),
            {
              'refunds': FieldValue.increment(refundAmount),
              'totalBalance': FieldValue.increment(refundAmount),
              'lastRefundDate': FieldValue.serverTimestamp(),
            },
          );
          
          // Create refund transaction record
          final refundRef = _firestore.collection('refund_transactions').doc();
          batch.set(refundRef, {
            'userId': userId,
            'vaultGameId': vaultGameId,
            'gameTitle': gameTitle,
            'refundAmount': refundAmount,
            'reason': 'Late contribution refund distribution',
            'originalContribution': userContribution,
            'contributionPercentage': contributionPercentage * 100,
            'lateContributionAmount': lateContributionAmount,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'completed',
          });
        }
      }
      
      print('Refund distribution completed for ${originalContributors.length} contributors');
    } catch (e) {
      print('Error distributing refunds: $e');
      throw e;
    }
  }
}