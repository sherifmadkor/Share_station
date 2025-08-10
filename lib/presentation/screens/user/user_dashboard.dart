// lib/presentation/screens/user/user_dashboard.dart - Updated to match Admin style

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

// Import screens
import '../user/points_redemption_screen.dart';
import '../user/my_contributions_screen.dart';
import '../user/add_contribution_screen.dart';
import '../user/balance_details_screen.dart';
import '../user/queue_management_screen.dart';
import '../user/sell_game_screen.dart';
import '../user/referral_dashboard_screen.dart';
import '../user/leaderboard_screen.dart';
import '../user/net_metrics_dashboard_screen.dart';
import '../user/browse_games_screen.dart';
import '../user/my_borrowings_screen.dart';
import '../user/profile_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({Key? key}) : super(key: key);

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;

  // User Statistics
  double _totalBalance = 0;
  int _points = 0;
  double _gameShares = 0;
  double _fundShares = 0;
  double _totalShares = 0;
  double _referralEarnings = 0;
  int _totalBorrows = 0;
  int _activeBorrows = 0;
  int _queuePositions = 0;
  double _stationLimit = 0;
  double _remainingStationLimit = 0;
  String _tier = 'member';
  String _memberId = '';
  Timestamp? _coolDownEndDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser == null) return;

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        setState(() {
          _totalBalance = _calculateTotalBalance(userData);
          _points = (userData['points'] ?? 0).toInt();
          _gameShares = (userData['gameShares'] ?? 0).toDouble();
          _fundShares = (userData['fundShares'] ?? 0).toDouble();
          _totalShares = (userData['totalShares'] ?? 0).toDouble();
          _referralEarnings = (userData['referralEarnings'] ?? 0).toDouble();
          _totalBorrows = (userData['totalBorrowsCount'] ?? 0).toInt();
          _stationLimit = (userData['stationLimit'] ?? 0).toDouble();
          _remainingStationLimit = (userData['remainingStationLimit'] ?? _stationLimit).toDouble();
          _tier = userData['tier'] ?? 'member';
          _memberId = userData['memberId'] ?? 'N/A';
          _coolDownEndDate = userData['coolDownEndDate'] as Timestamp?;
        });

        // Load active borrows
        final borrowsQuery = await _firestore
            .collection('borrow_requests')
            .where('borrowerId', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'approved')
            .get();

        _activeBorrows = borrowsQuery.docs.length;

        // Load queue positions
        final queuesQuery = await _firestore
            .collection('game_queues')
            .where('userId', isEqualTo: currentUser.uid)
            .get();

        _queuePositions = queuesQuery.docs.length;
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _calculateTotalBalance(Map<String, dynamic> userData) {
    double total = 0;
    final entries = userData['balanceEntries'] as List<dynamic>? ?? [];

    for (var entry in entries) {
      if (entry['isExpired'] != true) {
        final amount = entry['amount'];
        if (amount != null) {
          total += amount is int ? amount.toDouble() : amount;
        }
      }
    }

    final cashIn = userData['cashIn'];
    if (cashIn != null) {
      total += cashIn is int ? cashIn.toDouble() : cashIn;
    }

    return total;
  }

  Future<void> _logout() async {
    final isArabic = Provider.of<AppProvider>(context, listen: false).locale.languageCode == 'ar';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تسجيل الخروج' : 'Logout'),
        content: Text(isArabic ? 'هل أنت متأكد من تسجيل الخروج؟' : 'Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = context.read<AuthProvider>();
              await authProvider.signOut();
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(isArabic ? 'خروج' : 'Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.locale.languageCode == 'ar';
    final isDarkMode = appProvider.isDarkMode;

    // Define pages for bottom navigation
    final List<Widget> _pages = [
      _buildDashboardContent(isArabic, isDarkMode, authProvider),
      const BrowseGamesScreen(), // Game Library
      const MyBorrowingsScreen(), // My Borrowings
      const EnhancedProfileScreen(), // Profile Screen
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          isArabic ? 'لوحة التحكم' : 'Dashboard',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          // Notifications
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.notifications, color: Colors.white),
                if (_queuePositions > 0)
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
                        '$_queuePositions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.queueManagement);
            },
          ),

          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadUserData,
          ),
        ],
      ),

      // Navigation Drawer
      drawer: _buildNavigationDrawer(isArabic, isDarkMode, authProvider),

      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _pages[_selectedIndex],

      // Bottom Navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black : Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(.1),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 8.h),
            child: GNav(
              rippleColor: AppTheme.primaryColor.withOpacity(0.3),
              hoverColor: AppTheme.primaryColor.withOpacity(0.1),
              gap: 8,
              activeColor: AppTheme.primaryColor,
              iconSize: 24.sp,
              padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              color: Colors.grey,
              tabs: [
                GButton(
                  icon: Icons.dashboard,
                  text: isArabic ? 'لوحة التحكم' : 'Dashboard',
                ),
                GButton(
                  icon: Icons.gamepad,
                  text: isArabic ? 'مكتبة الألعاب' : 'Game Library',
                ),
                GButton(
                  icon: FontAwesomeIcons.handHolding,
                  text: isArabic ? 'استعاراتي' : 'My Borrowings',
                ),
                GButton(
                  icon: Icons.person,
                  text: isArabic ? 'الملف الشخصي' : 'Profile',
                ),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer(bool isArabic, bool isDarkMode, AuthProvider authProvider) {
    final user = authProvider.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer Header
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    user?.name?.substring(0, 1).toUpperCase() ?? 'U',
                    style: TextStyle(
                      fontSize: 30,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  user?.name ?? 'User',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user?.email ?? '',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: _getTierColor(_tier),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    _tier.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quick Actions Section
          _buildDrawerSection(
            title: isArabic ? 'الإجراءات السريعة' : 'Quick Actions',
            isDarkMode: isDarkMode,
          ),

          ListTile(
            leading: Icon(Icons.add_circle, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'إضافة مساهمة' : 'Add Contribution'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.addContribution);
            },
          ),

          ListTile(
            leading: Icon(FontAwesomeIcons.tags, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'بيع لعبة' : 'Sell Game'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.sellGame);
            },
          ),

          ListTile(
            leading: Icon(FontAwesomeIcons.coins, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'استبدال النقاط' : 'Redeem Points'),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.warningColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_points',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.pointsRedemption);
            },
          ),

          Divider(),

          // Account Section
          _buildDrawerSection(
            title: isArabic ? 'الحساب' : 'Account',
            isDarkMode: isDarkMode,
          ),

          ListTile(
            leading: Icon(FontAwesomeIcons.wallet, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'تفاصيل الرصيد' : 'Balance Details'),
            trailing: Text(
              '${_totalBalance.toStringAsFixed(0)} LE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.successColor,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.balanceDetails);
            },
          ),

          ListTile(
            leading: Icon(FontAwesomeIcons.listCheck, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'قوائم الانتظار' : 'My Queues'),
            trailing: _queuePositions > 0
                ? Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_queuePositions',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            )
                : Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.queueManagement);
            },
          ),

          ListTile(
            leading: Icon(FontAwesomeIcons.userGroup, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'الإحالات' : 'Referrals'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.referralDashboard);
            },
          ),

          Divider(),

          // Analytics Section
          _buildDrawerSection(
            title: isArabic ? 'التحليلات' : 'Analytics',
            isDarkMode: isDarkMode,
          ),

          ListTile(
            leading: Icon(Icons.leaderboard, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'المتصدرين' : 'Leaderboard'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.leaderboard);
            },
          ),

          ListTile(
            leading: Icon(Icons.analytics, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'المقاييس الصافية' : 'Net Metrics'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.netMetrics);
            },
          ),

          Divider(),

          // Settings Section
          _buildDrawerSection(
            title: isArabic ? 'الإعدادات' : 'Settings',
            isDarkMode: isDarkMode,
          ),

          ListTile(
            leading: Icon(Icons.language, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'اللغة' : 'Language'),
            trailing: Text(isArabic ? 'العربية' : 'English'),
            onTap: () {
              final appProvider = context.read<AppProvider>();
              appProvider.toggleLanguage();
              Navigator.pop(context);
            },
          ),

          ListTile(
            leading: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: AppTheme.primaryColor,
            ),
            title: Text(isArabic ? 'المظهر' : 'Theme'),
            trailing: Switch(
              value: isDarkMode,
              onChanged: (value) {
                final appProvider = context.read<AppProvider>();
                appProvider.toggleTheme();
              },
            ),
          ),

          ListTile(
            leading: Icon(Icons.help, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'المساعدة والدعم' : 'Help & Support'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Support - Coming Soon')),
              );
            },
          ),

          Divider(),

          // Logout
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text(
              isArabic ? 'تسجيل الخروج' : 'Logout',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),

          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerSection({
    required String title,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDashboardContent(bool isArabic, bool isDarkMode, AuthProvider authProvider) {
    return RefreshIndicator(
      onRefresh: _loadUserData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Message
            Text(
              isArabic
                  ? 'مرحباً، ${authProvider.currentUser?.name ?? 'User'}!'
                  : 'Welcome, ${authProvider.currentUser?.name ?? 'User'}!',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: _getTierColor(_tier),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    _tier.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'ID: $_memberId',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Balance & Points Card - Prominent like Borrow Window
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.8),
                    AppTheme.primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              FontAwesomeIcons.wallet,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              isArabic ? 'الرصيد' : 'Balance',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        InkWell(
                          onTap: () => Navigator.pushNamed(context, AppRoutes.balanceDetails),
                          child: Text(
                            '${_totalBalance.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'LE'}',
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60.h,
                    color: Colors.white24,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              isArabic ? 'النقاط' : 'Points',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.white70,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Icon(
                              FontAwesomeIcons.coins,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        InkWell(
                          onTap: () => Navigator.pushNamed(context, AppRoutes.pointsRedemption),
                          child: Text(
                            _points.toString(),
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Cooldown Warning (if active)
            if (_coolDownEndDate != null) ...[
              SizedBox(height: 16.h),
              _buildCooldownWarning(isArabic, isDarkMode),
            ],

            SizedBox(height: 24.h),

            // Statistics Overview
            Text(
              isArabic ? 'نظرة عامة' : 'Overview',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),

            // Stats Grid - Clickable like Admin
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 1.2,
              children: [
                InkWell(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.myContributions),
                  borderRadius: BorderRadius.circular(12.r),
                  child: _buildStatCard(
                    title: isArabic ? 'المساهمات' : 'Contributions',
                    value: _totalShares.toStringAsFixed(1),
                    subtitle: '${_gameShares.toStringAsFixed(1)} ${isArabic ? "لعبة" : "games"}',
                    icon: FontAwesomeIcons.handHoldingDollar,
                    color: AppTheme.primaryColor,
                    isDarkMode: isDarkMode,
                    hasNotification: false,
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.queueManagement),
                  borderRadius: BorderRadius.circular(12.r),
                  child: _buildStatCard(
                    title: isArabic ? 'قوائم الانتظار' : 'Queues',
                    value: _queuePositions.toString(),
                    subtitle: isArabic ? 'موضع نشط' : 'active positions',
                    icon: FontAwesomeIcons.listCheck,
                    color: AppTheme.infoColor,
                    isDarkMode: isDarkMode,
                    hasNotification: _queuePositions > 0,
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.referralDashboard),
                  borderRadius: BorderRadius.circular(12.r),
                  child: _buildStatCard(
                    title: isArabic ? 'الإحالات' : 'Referrals',
                    value: _referralEarnings.toStringAsFixed(0),
                    subtitle: isArabic ? 'ج.م مكتسب' : 'LE earned',
                    icon: FontAwesomeIcons.userGroup,
                    color: AppTheme.secondaryColor,
                    isDarkMode: isDarkMode,
                    hasNotification: false,
                  ),
                ),
                InkWell(
                  onTap: () {
                    // Navigate to My Borrowings
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('My Borrowings - Coming Soon')),
                    );
                  },
                  borderRadius: BorderRadius.circular(12.r),
                  child: _buildStatCard(
                    title: isArabic ? 'الاستعارات' : 'Borrows',
                    value: _activeBorrows.toString(),
                    subtitle: '$_totalBorrows ${isArabic ? "إجمالي" : "total"}',
                    icon: FontAwesomeIcons.handHolding,
                    color: AppTheme.warningColor,
                    isDarkMode: isDarkMode,
                    hasNotification: _activeBorrows > 0,
                  ),
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Quick Actions
            Text(
              isArabic ? 'الإجراءات السريعة' : 'Quick Actions',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),

            _buildQuickActions(isArabic, isDarkMode),

            SizedBox(height: 24.h),

            // Station Limit Progress
            _buildStationLimitCard(isArabic, isDarkMode),

            // VIP Progress (if not VIP)
            if (_tier != 'vip') ...[
              SizedBox(height: 16.h),
              _buildVIPProgressCard(isArabic, isDarkMode),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCooldownWarning(bool isArabic, bool isDarkMode) {
    final endDate = _coolDownEndDate!.toDate();
    final now = DateTime.now();
    final difference = endDate.difference(now);

    if (difference.isNegative) return Container();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.warningColor.withOpacity(0.8),
            AppTheme.warningColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.warningColor.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.timer_off,
              color: Colors.white,
              size: 28.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'فترة الانتظار' : 'Cooldown Period',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  isArabic
                      ? '${difference.inDays} يوم، ${difference.inHours % 24} ساعة متبقية'
                      : '${difference.inDays} days, ${difference.inHours % 24} hours remaining',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
    bool hasNotification = false,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 24.sp,
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isDarkMode ? Colors.white60 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (hasNotification)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isArabic, bool isDarkMode) {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12.w,
      mainAxisSpacing: 12.h,
      childAspectRatio: 1.3,
      children: [
        _buildActionCard(
          title: isArabic ? 'إضافة مساهمة' : 'Add Contribution',
          subtitle: isArabic ? 'مساهمة جديدة' : 'New contribution',
          icon: Icons.add_circle,
          color: AppTheme.successColor,
          onTap: () => Navigator.pushNamed(context, AppRoutes.addContribution),
        ),
        _buildActionCard(
          title: isArabic ? 'بيع لعبة' : 'Sell Game',
          subtitle: isArabic ? 'بيع مساهمتك' : 'Sell your share',
          icon: FontAwesomeIcons.tags,
          color: AppTheme.errorColor,
          onTap: () => Navigator.pushNamed(context, AppRoutes.sellGame),
        ),
        _buildActionCard(
          title: isArabic ? 'تفاصيل الرصيد' : 'Balance Details',
          subtitle: isArabic ? 'عرض التفاصيل' : 'View breakdown',
          icon: FontAwesomeIcons.wallet,
          color: AppTheme.primaryColor,
          onTap: () => Navigator.pushNamed(context, AppRoutes.balanceDetails),
        ),
        _buildActionCard(
          title: isArabic ? 'المتصدرين' : 'Leaderboard',
          subtitle: isArabic ? 'عرض الترتيب' : 'View rankings',
          icon: Icons.leaderboard,
          color: Colors.amber,
          onTap: () => Navigator.pushNamed(context, AppRoutes.leaderboard),
        ),
        _buildActionCard(
          title: isArabic ? 'المقاييس' : 'Net Metrics',
          subtitle: isArabic ? 'التحليلات' : 'Analytics',
          icon: Icons.analytics,
          color: AppTheme.infoColor,
          onTap: () => Navigator.pushNamed(context, AppRoutes.netMetrics),
        ),
        _buildActionCard(
          title: isArabic ? 'الدعم' : 'Support',
          subtitle: isArabic ? 'احصل على المساعدة' : 'Get help',
          icon: Icons.help,
          color: Colors.grey,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Support - Coming Soon')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Provider.of<AppProvider>(context).isDarkMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24.sp,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationLimitCard(bool isArabic, bool isDarkMode) {
    final progress = _stationLimit > 0
        ? ((_stationLimit - _remainingStationLimit) / _stationLimit).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'حد المحطة' : 'Station Limit',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(_stationLimit - _remainingStationLimit).toStringAsFixed(0)}/${_stationLimit.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            minHeight: 8.h,
          ),
          SizedBox(height: 8.h),
          Text(
            isArabic
                ? 'متبقي ${_remainingStationLimit.toStringAsFixed(0)} من الحد'
                : '${_remainingStationLimit.toStringAsFixed(0)} remaining',
            style: TextStyle(
              fontSize: 12.sp,
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVIPProgressCard(bool isArabic, bool isDarkMode) {
    final needsGameShares = (15 - _gameShares).clamp(0, 15);
    final needsFundShares = (5 - _fundShares).clamp(0, 5);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.1),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Colors.amber,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                FontAwesomeIcons.crown,
                color: Colors.amber,
                size: 20.sp,
              ),
              SizedBox(width: 12.w),
              Text(
                isArabic ? 'التقدم نحو VIP' : 'VIP Progress',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'مساهمات الألعاب' : 'Game Shares',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                    SizedBox(height: 4.h),
                    LinearProgressIndicator(
                      value: (_gameShares / 15).clamp(0.0, 1.0),
                      backgroundColor: Colors.amber.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                      minHeight: 6.h,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${_gameShares.toStringAsFixed(1)}/15',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'مساهمات الصندوق' : 'Fund Shares',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                    SizedBox(height: 4.h),
                    LinearProgressIndicator(
                      value: (_fundShares / 5).clamp(0.0, 1.0),
                      backgroundColor: Colors.orange.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      minHeight: 6.h,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${_fundShares.toStringAsFixed(0)}/5',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (needsGameShares > 0 || needsFundShares > 0) ...[
            SizedBox(height: 8.h),
            Text(
              isArabic
                  ? 'تحتاج ${needsGameShares.toStringAsFixed(0)} مساهمة لعبة و ${needsFundShares.toStringAsFixed(0)} مساهمة صندوق'
                  : 'Need ${needsGameShares.toStringAsFixed(0)} game shares & ${needsFundShares.toStringAsFixed(0)} fund shares',
              style: TextStyle(
                fontSize: 11.sp,
                color: isDarkMode ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'vip':
        return Colors.amber;
      case 'client':
        return Colors.blue;
      case 'member':
        return AppTheme.primaryColor;
      default:
        return Colors.grey;
    }
  }
}