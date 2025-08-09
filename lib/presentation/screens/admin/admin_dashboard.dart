// lib/presentation/screens/admin/admin_dashboard.dart - Updated with Borrow Window Control

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_loading.dart';
import '../admin/manage_contributions_screen.dart';
import '../admin/manage_borrow_requests_screen.dart';
import '../admin/manage_users_screen.dart';
import '../admin/manage_games_screen.dart';
import '../../../services/suspension_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SuspensionService _suspensionService = SuspensionService();

  // Statistics
  int _totalMembers = 0;
  int _activeMembers = 0;
  int _totalGames = 0;
  int _activeGames = 0;
  int _pendingContributions = 0;
  int _pendingBorrows = 0;
  int _activeBorrows = 0;

  // Borrow Window Status
  bool _isBorrowWindowOpen = false;
  bool _isUpdatingWindow = false;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    _loadBorrowWindowStatus();
    _runPeriodicSuspensionCheck();
  }

  Future<void> _loadStatistics() async {
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
    final isArabic = appProvider.isArabic;

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

  // Run periodic suspension checks and VIP promotions
  Future<void> _runPeriodicSuspensionCheck() async {
    try {
      // Run suspension checks
      final suspensionResult = await _suspensionService.checkAndApplySuspensions();
      
      // Run VIP promotion checks
      final vipResult = await _suspensionService.batchCheckVIPPromotions();
      
      // Show notifications if there are changes
      if (mounted) {
        if (suspensionResult['suspended'] > 0) {
          print('Suspension check completed: ${suspensionResult['suspended']} users suspended out of ${suspensionResult['checked']} checked');
          
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
          print('VIP promotion check completed: ${vipResult['promoted']} users promoted out of ${vipResult['checked']} checked');
          
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
        if (suspensionResult['suspended'] > 0 || vipResult['promoted'] > 0) {
          _loadStatistics();
        }
      }
    } catch (e) {
      print('Error running periodic checks: $e');
    }
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
          isArabic ? 'لوحة تحكم المسؤول' : 'Admin Dashboard',
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
            onPressed: () {
              _loadStatistics();
              _loadBorrowWindowStatus();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
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

              // Stats Grid
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                childAspectRatio: 1.2,
                children: [
                  _buildStatCard(
                    title: isArabic ? 'الأعضاء' : 'Members',
                    value: _totalMembers.toString(),
                    subtitle: '$_activeMembers ${isArabic ? "نشط" : "active"}',
                    icon: FontAwesomeIcons.users,
                    color: AppTheme.primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                  _buildStatCard(
                    title: isArabic ? 'الألعاب' : 'Games',
                    value: _totalGames.toString(),
                    subtitle: '$_activeGames ${isArabic ? "متاح" : "available"}',
                    icon: FontAwesomeIcons.gamepad,
                    color: AppTheme.secondaryColor,
                    isDarkMode: isDarkMode,
                  ),
                  _buildStatCard(
                    title: isArabic ? 'مساهمات معلقة' : 'Pending Contributions',
                    value: _pendingContributions.toString(),
                    subtitle: isArabic ? 'بانتظار الموافقة' : 'Awaiting approval',
                    icon: FontAwesomeIcons.clock,
                    color: AppTheme.warningColor,
                    isDarkMode: isDarkMode,
                    hasNotification: _pendingContributions > 0,
                  ),
                  _buildStatCard(
                    title: isArabic ? 'الاستعارات' : 'Borrows',
                    value: _activeBorrows.toString(),
                    subtitle: '$_pendingBorrows ${isArabic ? "معلق" : "pending"}',
                    icon: FontAwesomeIcons.handHolding,
                    color: AppTheme.infoColor,
                    isDarkMode: isDarkMode,
                    hasNotification: _pendingBorrows > 0,
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

              Column(
                children: [
                  _buildActionTile(
                    title: isArabic ? 'إدارة المساهمات' : 'Manage Contributions',
                    subtitle: _pendingContributions > 0
                        ? '$_pendingContributions ${isArabic ? "بانتظار الموافقة" : "pending approval"}'
                        : (isArabic ? 'مراجعة وإدارة المساهمات' : 'Review and manage contributions'),
                    icon: FontAwesomeIcons.folderOpen,
                    color: AppTheme.warningColor,
                    hasNotification: _pendingContributions > 0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageContributionsScreen(),
                        ),
                      ).then((_) => _loadStatistics());
                    },
                  ),
                  SizedBox(height: 12.h),
                  _buildActionTile(
                    title: isArabic ? 'إدارة الاستعارات' : 'Manage Borrow Requests',
                    subtitle: _pendingBorrows > 0
                        ? '$_pendingBorrows ${isArabic ? "طلب معلق" : "pending requests"}'
                        : (isArabic ? 'مراجعة طلبات الاستعارة' : 'Review borrow requests'),
                    icon: FontAwesomeIcons.handHolding,
                    color: AppTheme.infoColor,
                    hasNotification: _pendingBorrows > 0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageBorrowRequestsScreen(),
                        ),
                      ).then((_) => _loadStatistics());
                    },
                  ),
                  SizedBox(height: 12.h),
                  _buildActionTile(
                    title: isArabic ? 'إدارة المستخدمين' : 'Manage Users',
                    subtitle: isArabic ? 'عرض وإدارة حسابات المستخدمين' : 'View and manage user accounts',
                    icon: FontAwesomeIcons.usersCog,
                    color: AppTheme.primaryColor,
                    onTap: () {
                      // Navigate to manage users screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isArabic ? 'قريباً' : 'Coming soon'),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 12.h),
                  _buildActionTile(
                    title: isArabic ? 'إدارة الألعاب' : 'Manage Games',
                    subtitle: isArabic ? 'إدارة مكتبة الألعاب والحسابات' : 'Manage game library and accounts',
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
                ],
              ),
            ],
          ),
        ),
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

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool hasNotification = false,
  }) {
    final isDarkMode = Provider.of<AppProvider>(context).isDarkMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
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
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasNotification) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: isDarkMode ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16.sp,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}