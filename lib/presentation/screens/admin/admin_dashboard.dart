// lib/presentation/screens/admin/admin_dashboard.dart - Complete Merged Version

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../widgets/custom_loading.dart';
import '../admin/manage_contributions_screen.dart';
import '../admin/manage_borrow_requests_screen.dart';
import '../admin/manage_users_screen.dart';
import '../admin/manage_games_screen.dart';
import '../admin/analytics_screen.dart';
import '../admin/settings_screen.dart';
import '../../../services/suspension_service.dart';
import '../../../services/balance_service.dart';
import '../user/browse_games_screen.dart';
import '../user/my_borrowings_screen.dart';
import '../user/profile_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SuspensionService _suspensionService = SuspensionService();
  final BalanceService _balanceService = BalanceService();

  int _selectedIndex = 0;

  // Statistics
  int _totalMembers = 0;
  int _activeMembers = 0;
  int _totalGames = 0;
  int _activeGames = 0;
  int _pendingContributions = 0;
  int _pendingBorrows = 0;
  int _activeBorrows = 0;
  double _totalRevenue = 0;

  // Borrow Window Status
  bool _isBorrowWindowOpen = false;
  bool _isUpdatingWindow = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    _loadBorrowWindowStatus();
    _runPeriodicSuspensionCheck();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      // Get member count
      final usersQuery = await _firestore
          .collection('users')
          .where('tier', whereIn: ['member', 'vip', 'client'])
          .get();

      final activeUsersQuery = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'active')
          .get();

      // Get games count
      final gamesQuery = await _firestore.collection('games').get();

      int availableGamesCount = 0;
      for (var doc in gamesQuery.docs) {
        final data = doc.data();
        if (data['accounts'] != null) {
          final accounts = data['accounts'] as List<dynamic>;
          for (var account in accounts) {
            final slots = account['slots'] as Map<String, dynamic>?;
            if (slots != null) {
              final hasAvailable = slots.values.any((slot) =>
              slot['status'] == 'available'
              );
              if (hasAvailable) {
                availableGamesCount++;
                break;
              }
            }
          }
        }
      }

      // Get pending contributions
      final pendingContribQuery = await _firestore
          .collection('contribution_requests')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      // Get pending borrows
      final pendingBorrowQuery = await _firestore
          .collection('borrow_requests')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      // Get active borrows
      final activeBorrowQuery = await _firestore
          .collection('borrow_requests')
          .where('status', isEqualTo: 'approved')
          .count()
          .get();

      // Calculate revenue
      _totalRevenue = 0;
      for (var doc in usersQuery.docs) {
        _totalRevenue += (doc.data()['totalSpent'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _totalMembers = usersQuery.docs.length;
          _activeMembers = activeUsersQuery.docs.length;
          _totalGames = gamesQuery.docs.length;
          _activeGames = availableGamesCount;
          _pendingContributions = pendingContribQuery.count ?? 0;
          _pendingBorrows = pendingBorrowQuery.count ?? 0;
          _activeBorrows = activeBorrowQuery.count ?? 0;
        });
      }
    } catch (e) {
      print('Error loading statistics: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBorrowWindowStatus() async {
    try {
      final doc = await _firestore
          .collection('settings')
          .doc('borrow_window')
          .get();

      if (doc.exists) {
        setState(() {
          _isBorrowWindowOpen = doc.data()?['isOpen'] ?? false;
        });
      } else {
        // Create the document if it doesn't exist
        await _firestore.collection('settings').doc('borrow_window').set({
          'isOpen': false,
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': 'system',
        });
      }
    } catch (e) {
      print('Error loading borrow window status: $e');
    }
  }

  Future<void> _toggleBorrowWindow() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isArabic = appProvider.locale.languageCode == 'ar';

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _isBorrowWindowOpen
              ? (isArabic ? 'إغلاق نافذة الاستعارة' : 'Close Borrow Window')
              : (isArabic ? 'فتح نافذة الاستعارة' : 'Open Borrow Window'),
        ),
        content: Text(
          _isBorrowWindowOpen
              ? (isArabic
              ? 'هل أنت متأكد من إغلاق نافذة الاستعارة؟ لن يتمكن الأعضاء من تقديم طلبات استعارة جديدة.'
              : 'Are you sure you want to close the borrow window? Members will not be able to submit new borrow requests.')
              : (isArabic
              ? 'هل أنت متأكد من فتح نافذة الاستعارة؟ سيتمكن الأعضاء من تقديم طلبات استعارة جديدة.'
              : 'Are you sure you want to open the borrow window? Members will be able to submit new borrow requests.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isBorrowWindowOpen
                  ? AppTheme.errorColor
                  : AppTheme.successColor,
            ),
            child: Text(
              _isBorrowWindowOpen
                  ? (isArabic ? 'إغلاق' : 'Close')
                  : (isArabic ? 'فتح' : 'Open'),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpdatingWindow = true);

    try {
      await _firestore.collection('settings').doc('borrow_window').set({
        'isOpen': !_isBorrowWindowOpen,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': authProvider.currentUser?.name ?? 'admin',
        'adminId': authProvider.currentUser?.uid,
      });

      setState(() {
        _isBorrowWindowOpen = !_isBorrowWindowOpen;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isBorrowWindowOpen
                ? (isArabic ? 'تم فتح نافذة الاستعارة' : 'Borrow window opened')
                : (isArabic ? 'تم إغلاق نافذة الاستعارة' : 'Borrow window closed'),
          ),
          backgroundColor: _isBorrowWindowOpen
              ? AppTheme.successColor
              : AppTheme.warningColor,
        ),
      );
    } catch (e) {
      print('Error updating borrow window: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'خطأ في تحديث نافذة الاستعارة' : 'Error updating borrow window',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() => _isUpdatingWindow = false);
    }
  }

  // Run periodic suspension checks, balance expiry checks, and VIP promotions
  Future<void> _runPeriodicSuspensionCheck() async {
    try {
      // Run balance expiry checks first
      final balanceResult = await _balanceService.checkAndExpireBalances();

      // Run suspension checks
      final suspensionResult = await _suspensionService.checkAndApplySuspensions();

      // Run VIP promotion checks
      final vipResult = await _suspensionService.batchCheckVIPPromotions();

      // Show notifications if there are changes
      if (mounted) {
        if (balanceResult['expired'] > 0) {
          print('Balance expiry check completed: ${balanceResult['expired']} entries expired');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Balance expiry: ${balanceResult['expired']} entries expired (${balanceResult['totalExpired'].toStringAsFixed(0)} LE)',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }

        if (suspensionResult['suspended'] > 0) {
          print('Suspension check completed: ${suspensionResult['suspended']} users suspended');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Suspension check: ${suspensionResult['suspended']} inactive users were suspended',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }

        if (vipResult['promoted'] > 0) {
          print('VIP promotion check completed: ${vipResult['promoted']} users promoted');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'VIP promotions: ${vipResult['promoted']} users promoted to VIP',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }

        // Refresh statistics if there were any changes
        if (balanceResult['expired'] > 0 || suspensionResult['suspended'] > 0 || vipResult['promoted'] > 0) {
          _loadStatistics();
        }
      }
    } catch (e) {
      print('Error running periodic checks: $e');
    }
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

  // Initialize system settings (one-time setup) - KEEPING YOUR ORIGINAL VALUES
  Future<void> _initializeSystemSettings() async {
    try {
      await _firestore.collection('settings').doc('system').set({
        'membershipFee': 1500,
        'clientFee': 750,
        'vipWithdrawalFeePercentage': 20,
        'adminFeePercentage': 10,
        'pointsConversionRate': 25,
        'balanceExpiryDays': 90,
        'suspensionPeriodDays': 180,
        'borrowWindowDay': 'thursday',
        'isBorrowWindowOpen': true,
        'allowNewRegistrations': true,
        'maintenanceMode': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('System settings initialized successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing settings: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.locale.languageCode == 'ar';
    final isDarkMode = appProvider.isDarkMode;

    // Define pages for bottom navigation
    final List<Widget> _pages = [
      _buildOriginalDashboardContent(isArabic, isDarkMode, authProvider),
      const BrowseGamesScreen(), // Game Library
      const MyBorrowingsScreen(), // My Borrowings
      const EnhancedProfileScreen(), // Existing Profile Screen
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          isArabic ? 'لوحة تحكم المسؤول' : 'Admin Dashboard',
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
          // Notifications with badge
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.notifications, color: Colors.white),
                if (_pendingContributions + _pendingBorrows > 0)
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
                        '${_pendingContributions + _pendingBorrows}',
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
              if (_pendingContributions >= _pendingBorrows) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageContributionsScreen(),
                  ),
                ).then((_) => _loadStatistics());
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageBorrowRequestsScreen(),
                  ),
                ).then((_) => _loadStatistics());
              }
            },
          ),

          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadStatistics();
              _loadBorrowWindowStatus();
            },
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
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 35,
                    color: AppTheme.primaryColor,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  user?.name ?? 'Admin',
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
              ],
            ),
          ),

          // Management Section
          _buildDrawerSection(
            title: isArabic ? 'الإدارة' : 'Management',
            isDarkMode: isDarkMode,
          ),

          ListTile(
            leading: Icon(FontAwesomeIcons.clipboardCheck, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'الموافقات' : 'Approvals'),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_pendingContributions + _pendingBorrows}',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              if (_pendingContributions >= _pendingBorrows) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageContributionsScreen(),
                  ),
                ).then((_) => _loadStatistics());
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageBorrowRequestsScreen(),
                  ),
                ).then((_) => _loadStatistics());
              }
            },
          ),

          ListTile(
            leading: Icon(Icons.people, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'إدارة المستخدمين' : 'Manage Users'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageUsersScreen(),
                ),
              ).then((_) => _loadStatistics());
            },
          ),

          ListTile(
            leading: Icon(Icons.gamepad, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'إدارة الألعاب' : 'Manage Games'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageGamesScreen(),
                ),
              ).then((_) => _loadStatistics());
            },
          ),

          Divider(),

          // Analytics Section
          _buildDrawerSection(
            title: isArabic ? 'التحليلات' : 'Analytics',
            isDarkMode: isDarkMode,
          ),

          ListTile(
            leading: Icon(Icons.analytics, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'التحليلات' : 'Analytics'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsScreen(),
                ),
              ).then((_) => _loadStatistics());
            },
          ),

          ListTile(
            leading: Icon(Icons.assessment, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'التقارير' : 'Reports'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedIndex = 2); // Switch to reports tab
            },
          ),

          Divider(),

          // Settings Section
          _buildDrawerSection(
            title: isArabic ? 'النظام' : 'System',
            isDarkMode: isDarkMode,
          ),

          ListTile(
            leading: Icon(Icons.settings, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'الإعدادات' : 'Settings'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              ).then((_) => _loadStatistics());
            },
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

          Divider(),

          // User Section
          ListTile(
            leading: Icon(Icons.person, color: AppTheme.primaryColor),
            title: Text(isArabic ? 'الملف الشخصي' : 'Profile'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.profileScreen);
            },
          ),

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

  // YOUR ORIGINAL DASHBOARD CONTENT
  Widget _buildOriginalDashboardContent(bool isArabic, bool isDarkMode, AuthProvider authProvider) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadStatistics();
        await _loadBorrowWindowStatus();
      },
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Message
            Text(
              isArabic
                  ? 'مرحباً، ${authProvider.currentUser?.name ?? 'Admin'}!'
                  : 'Welcome, ${authProvider.currentUser?.name ?? 'Admin'}!',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              isArabic ? 'إدارة النظام' : 'System Management',
              style: TextStyle(
                fontSize: 16.sp,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),

            SizedBox(height: 24.h),

            // Borrow Window Control - PROMINENT PLACEMENT
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isBorrowWindowOpen
                      ? [AppTheme.successColor.withOpacity(0.8), AppTheme.successColor]
                      : [AppTheme.warningColor.withOpacity(0.8), AppTheme.warningColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: (_isBorrowWindowOpen ? AppTheme.successColor : AppTheme.warningColor)
                        .withOpacity(0.3),
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
                      _isBorrowWindowOpen ? Icons.lock_open : Icons.lock,
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
                          isArabic ? 'نافذة الاستعارة' : 'Borrow Window',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _isBorrowWindowOpen
                              ? (isArabic ? 'مفتوحة - يمكن للأعضاء الاستعارة' : 'Open - Members can borrow')
                              : (isArabic ? 'مغلقة - لا يمكن الاستعارة' : 'Closed - Borrowing disabled'),
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isBorrowWindowOpen,
                    onChanged: _isUpdatingWindow ? null : (_) => _toggleBorrowWindow(),
                    activeColor: Colors.white,
                    activeTrackColor: Colors.white.withOpacity(0.5),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                  ),
                ],
              ),
            ),

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

            // Stats Grid - YOUR ORIGINAL WITH CLICKABLE CARDS
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 1.2,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageUsersScreen(),
                      ),
                    ).then((_) => _loadStatistics());
                  },
                  borderRadius: BorderRadius.circular(12.r),
                  child: _buildStatCard(
                    title: isArabic ? 'الأعضاء' : 'Members',
                    value: _totalMembers.toString(),
                    subtitle: '$_activeMembers ${isArabic ? "نشط" : "active"}',
                    icon: FontAwesomeIcons.users,
                    color: AppTheme.primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageGamesScreen(),
                      ),
                    ).then((_) => _loadStatistics());
                  },
                  borderRadius: BorderRadius.circular(12.r),
                  child: _buildStatCard(
                    title: isArabic ? 'الألعاب' : 'Games',
                    value: _totalGames.toString(),
                    subtitle: '$_activeGames ${isArabic ? "متاح" : "available"}',
                    icon: FontAwesomeIcons.gamepad,
                    color: AppTheme.secondaryColor,
                    isDarkMode: isDarkMode,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageContributionsScreen(),
                      ),
                    ).then((_) => _loadStatistics());
                  },
                  borderRadius: BorderRadius.circular(12.r),
                  child: _buildStatCard(
                    title: isArabic ? 'مساهمات معلقة' : 'Pending Contributions',
                    value: _pendingContributions.toString(),
                    subtitle: isArabic ? 'بانتظار الموافقة' : 'Awaiting approval',
                    icon: FontAwesomeIcons.clock,
                    color: AppTheme.warningColor,
                    isDarkMode: isDarkMode,
                    hasNotification: _pendingContributions > 0,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageBorrowRequestsScreen(),
                      ),
                    ).then((_) => _loadStatistics());
                  },
                  borderRadius: BorderRadius.circular(12.r),
                  child: _buildStatCard(
                    title: isArabic ? 'الاستعارات' : 'Borrows',
                    value: _activeBorrows.toString(),
                    subtitle: '$_pendingBorrows ${isArabic ? "معلق" : "pending"}',
                    icon: FontAwesomeIcons.handHolding,
                    color: AppTheme.infoColor,
                    isDarkMode: isDarkMode,
                    hasNotification: _pendingBorrows > 0,
                  ),
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Quick Actions Grid - YOUR ORIGINAL
            Text(
              isArabic ? 'الإجراءات السريعة' : 'Quick Actions',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),

            _buildAdminQuickActions(),

            SizedBox(height: 24.h),

            // System Maintenance Buttons - YOUR ORIGINAL
            Text(
              isArabic ? 'صيانة النظام' : 'System Maintenance',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),

            _buildAdminQuickButtons(),
          ],
        ),
      ),
    );
  }

  // YOUR ORIGINAL WIDGETS - UNCHANGED
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

  // Admin Quick Actions Grid - YOUR ORIGINAL
  Widget _buildAdminQuickActions() {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.locale.languageCode == 'ar';

    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12.w,
      mainAxisSpacing: 12.h,
      childAspectRatio: 1.3,
      children: [
        _buildAdminActionCard(
          title: isArabic ? 'لوحة الموافقات' : 'Approvals',
          subtitle: '${_pendingContributions + _pendingBorrows} pending',
          icon: FontAwesomeIcons.clipboardCheck,
          color: AppTheme.warningColor,
          badge: (_pendingContributions + _pendingBorrows).toString(),
          onTap: () {
            if (_pendingContributions >= _pendingBorrows) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageContributionsScreen(),
                ),
              ).then((_) => _loadStatistics());
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageBorrowRequestsScreen(),
                ),
              ).then((_) => _loadStatistics());
            }
          },
        ),

        _buildAdminActionCard(
          title: isArabic ? 'إدارة الألعاب' : 'Manage Games',
          subtitle: '$_totalGames games',
          icon: FontAwesomeIcons.gamepad,
          color: AppTheme.successColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManageGamesScreen(),
              ),
            ).then((_) => _loadStatistics());
          },
        ),

        _buildAdminActionCard(
          title: isArabic ? 'إدارة المستخدمين' : 'Manage Users',
          subtitle: '$_totalMembers members',
          icon: FontAwesomeIcons.usersCog,
          color: AppTheme.primaryColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManageUsersScreen(),
              ),
            ).then((_) => _loadStatistics());
          },
        ),

        _buildAdminActionCard(
          title: isArabic ? 'التحليلات' : 'Analytics',
          subtitle: isArabic ? 'عرض الإحصائيات' : 'View statistics',
          icon: Icons.analytics,
          color: AppTheme.infoColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AnalyticsScreen(),
              ),
            ).then((_) => _loadStatistics());
          },
        ),

        _buildAdminActionCard(
          title: isArabic ? 'الإعدادات' : 'Settings',
          subtitle: isArabic ? 'إعدادات النظام' : 'System settings',
          icon: Icons.settings,
          color: Colors.grey,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            ).then((_) => _loadStatistics());
          },
        ),
      ],
    );
  }

  // Admin Action Card Widget - YOUR ORIGINAL
  Widget _buildAdminActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
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
        child: Stack(
          children: [
            Column(
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
            if (badge != null && badge != "0")
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // System Maintenance Quick Buttons - YOUR ORIGINAL
  Widget _buildAdminQuickButtons() {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.locale.languageCode == 'ar';

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            try {
              final result = await _suspensionService.checkAndApplySuspensions();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Checked ${result['checked']} users, suspended ${result['suspended']}',
                    ),
                    backgroundColor: AppTheme.warningColor,
                  ),
                );
                if (result['suspended'] > 0) {
                  _loadStatistics();
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            }
          },
          icon: Icon(Icons.person_off, size: 16.sp),
          label: Text(
            isArabic ? 'فحص التعليق' : 'Check Suspensions',
            style: TextStyle(fontSize: 12.sp),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warningColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          ),
        ),

        ElevatedButton.icon(
          onPressed: () async {
            try {
              final result = await _balanceService.checkAndExpireBalances();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Expired ${result['expired']} balance entries',
                    ),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                if (result['expired'] > 0) {
                  _loadStatistics();
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            }
          },
          icon: Icon(Icons.timer_off, size: 16.sp),
          label: Text(
            isArabic ? 'فحص انتهاء الرصيد' : 'Check Expiry',
            style: TextStyle(fontSize: 12.sp),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          ),
        ),

        ElevatedButton.icon(
          onPressed: () async {
            try {
              final result = await _suspensionService.batchCheckVIPPromotions();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Checked ${result['checked']} users, promoted ${result['promoted']} to VIP',
                    ),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
                if (result['promoted'] > 0) {
                  _loadStatistics();
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            }
          },
          icon: Icon(FontAwesomeIcons.crown, size: 16.sp),
          label: Text(
            isArabic ? 'فحص ترقيات VIP' : 'Check VIP Promotions',
            style: TextStyle(fontSize: 12.sp),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          ),
        ),

        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Points Management - Coming Soon')),
            );
          },
          icon: Icon(FontAwesomeIcons.coins, size: 16.sp),
          label: Text(
            isArabic ? 'إدارة النقاط' : 'Points Management',
            style: TextStyle(fontSize: 12.sp),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          ),
        ),

        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Queue Monitoring - Coming Soon')),
            );
          },
          icon: Icon(Icons.queue, size: 16.sp),
          label: Text(
            isArabic ? 'مراقبة القوائم' : 'Queue Monitor',
            style: TextStyle(fontSize: 12.sp),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.infoColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          ),
        ),
      ],
    );
  }
}