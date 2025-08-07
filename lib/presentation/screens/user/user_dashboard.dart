import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({Key? key}) : super(key: key);

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic ? 'لوحة التحكم' : 'Dashboard',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.language),
            onPressed: () => appProvider.toggleLanguage(),
          ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => appProvider.toggleTheme(),
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic
                        ? 'مرحباً، ${user?.name ?? 'مستخدم'}'
                        : 'Welcome, ${user?.name ?? 'User'}',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: _getTierColor(user?.tier),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      user?.tier.displayName ?? 'User',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'ID: ${user?.memberId ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),

            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: isArabic ? 'الرصيد' : 'Balance',
                    value: '${user?.totalBalance.toStringAsFixed(2) ?? '0.00'} LE',
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
                    // Navigate to browse games
                  },
                ),
                _buildActionCard(
                  title: isArabic ? 'استعاراتي' : 'My Borrowings',
                  icon: FontAwesomeIcons.gamepad,
                  color: AppTheme.secondaryColor,
                  onTap: () {
                    // Navigate to borrowings
                  },
                ),
                _buildActionCard(
                  title: isArabic ? 'المساهمات' : 'Contributions',
                  icon: FontAwesomeIcons.handHoldingDollar,
                  color: AppTheme.successColor,
                  onTap: () {
                    // Navigate to contributions
                  },
                ),
                _buildActionCard(
                  title: isArabic ? 'الملف الشخصي' : 'Profile',
                  icon: FontAwesomeIcons.user,
                  color: AppTheme.warningColor,
                  onTap: () {
                    // Navigate to profile
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
                              : (isArabic
                              ? 'تفتح يوم الجمعة القادم'
                              : 'Opens next Friday'),
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
          ],
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
          Icon(
            icon,
            color: color,
            size: 24.sp,
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
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
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
    final isDarkMode = Provider.of<AppProvider>(context, listen: false).isDarkMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 28.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTierColor(UserTier? tier) {
    switch (tier) {
      case UserTier.admin:
        return AppTheme.adminColor;
      case UserTier.vip:
        return AppTheme.vipColor;
      case UserTier.member:
        return AppTheme.memberColor;
      case UserTier.client:
        return AppTheme.clientColor;
      default:
        return AppTheme.userColor;
    }
  }
}