import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../user/browse_games_screen.dart';
import '../user/my_borrowings_screen.dart';
import '../user/my_contributions_screen.dart';
import '../user/profile_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({Key? key}) : super(key: key);

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Real-time statistics
  int _totalGames = 0;
  int _activeGames = 0;
  int _pendingRequests = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    try {
      // Count total games in library
      final games = await _firestore.collection('games').get();

      // Count active games (available to borrow)
      final activeGames = games.docs.where((doc) {
        final data = doc.data();
        return data['isActive'] == true;
      }).length;

      // Count user's pending requests
      final borrowRequests = await _firestore
          .collection('borrow_requests')
          .where('borrowerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      final contributionRequests = await _firestore
          .collection('contribution_requests')
          .where('contributorId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (mounted) {
        setState(() {
          _totalGames = games.docs.length;
          _activeGames = activeGames;
          _pendingRequests = borrowRequests.docs.length + contributionRequests.docs.length;
        });
      }
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          isArabic ? 'لوحة التحكم' : 'Dashboard',
          style: TextStyle(
            color: isDarkMode ? Colors.white : AppTheme.darkBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: isDarkMode ? Colors.white : AppTheme.darkBackground,
            ),
            onPressed: () {
              // Navigate to notifications
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Message
              Text(
                isArabic
                    ? 'مرحباً، ${user?.name ?? 'User'}!'
                    : 'Welcome, ${user?.name ?? 'User'}!',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 8.h),

              // User Tier Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _getTierColor(user?.tier).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  user?.tier.displayName ?? 'Member',
                  style: TextStyle(
                    color: _getTierColor(user?.tier),
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              // Quick Stats from User Model
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: isArabic ? 'الرصيد' : 'Balance',
                      value: '${user?.totalBalance.toStringAsFixed(0) ?? '0'} LE',
                      icon: FontAwesomeIcons.wallet,
                      color: AppTheme.successColor,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildStatCard(
                      title: isArabic ? 'النقاط' : 'Points',
                      value: '${user?.points ?? 0}',
                      icon: FontAwesomeIcons.star,
                      color: AppTheme.warningColor,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12.h),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: isArabic ? 'حد المحطة' : 'Station Limit',
                      value: '${user?.remainingStationLimit.toStringAsFixed(0) ?? '0'} LE',
                      icon: FontAwesomeIcons.gauge,
                      color: AppTheme.primaryColor,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildStatCard(
                      title: isArabic ? 'الاستعارات' : 'Borrows',
                      value: '${user?.currentBorrows ?? 0}/${user?.borrowLimit ?? 1}',
                      icon: FontAwesomeIcons.gamepad,
                      color: AppTheme.infoColor,
                      isDarkMode: isDarkMode,
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

              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 1.5,
                children: [
                  _buildActionCard(
                    title: isArabic ? 'تصفح الألعاب' : 'Browse Games',
                    icon: FontAwesomeIcons.magnifyingGlass,
                    color: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BrowseGamesScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    title: isArabic ? 'استعاراتي' : 'My Borrowings',
                    icon: FontAwesomeIcons.gamepad,
                    color: AppTheme.secondaryColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyBorrowingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    title: isArabic ? 'المساهمات' : 'Contributions',
                    icon: FontAwesomeIcons.handHoldingDollar,
                    color: AppTheme.successColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyContributionsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    title: isArabic ? 'الملف الشخصي' : 'Profile',
                    icon: FontAwesomeIcons.user,
                    color: AppTheme.warningColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              // Borrow Window Status
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: appProvider.isBorrowWindowCurrentlyOpen()
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: appProvider.isBorrowWindowCurrentlyOpen()
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      appProvider.isBorrowWindowCurrentlyOpen()
                          ? Icons.lock_open
                          : Icons.lock,
                      color: appProvider.isBorrowWindowCurrentlyOpen()
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'نافذة الاستعارة' : 'Borrow Window',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            appProvider.isBorrowWindowCurrentlyOpen()
                                ? (isArabic ? 'مفتوحة الآن' : 'Open Now')
                                : (isArabic ? 'مغلقة - تفتح الخميس' : 'Closed - Opens Thursday'),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: isDarkMode
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // Library Statistics
              Text(
                isArabic ? 'إحصائيات المكتبة' : 'Library Statistics',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 12.h),

              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      title: isArabic ? 'إجمالي الألعاب' : 'Total Games',
                      value: _totalGames.toString(),
                      icon: FontAwesomeIcons.gamepad,
                      color: AppTheme.primaryColor,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildInfoCard(
                      title: isArabic ? 'متاح للاستعارة' : 'Available',
                      value: _activeGames.toString(),
                      icon: FontAwesomeIcons.circleCheck,
                      color: AppTheme.successColor,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildInfoCard(
                      title: isArabic ? 'طلبات معلقة' : 'Pending',
                      value: _pendingRequests.toString(),
                      icon: FontAwesomeIcons.clock,
                      color: AppTheme.warningColor,
                      isDarkMode: isDarkMode,
                    ),
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
    required IconData icon,
    required Color color,
    required bool isDarkMode,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: color,
                size: 20.sp,
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: isDarkMode
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
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
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 32.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
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
        children: [
          Icon(
            icon,
            color: color,
            size: 24.sp,
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.sp,
              color: isDarkMode
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(tier) {
    if (tier == null) return AppTheme.primaryColor;
    switch (tier.name) {
      case 'admin':
        return Colors.red;
      case 'vip':
        return Colors.amber;
      case 'member':
        return AppTheme.primaryColor;
      case 'client':
        return AppTheme.secondaryColor;
      case 'user':
        return AppTheme.infoColor;
      default:
        return AppTheme.primaryColor;
    }
  }
}