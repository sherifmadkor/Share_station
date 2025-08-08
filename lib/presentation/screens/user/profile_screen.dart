import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../user/add_contribution_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final user = authProvider.currentUser;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Profile Header
          SliverAppBar(
            expandedHeight: 250.h,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Profile Picture
                      CircleAvatar(
                        radius: 50.r,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 60.sp,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // User Name
                      Text(
                        user?.name ?? 'User',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      // Member ID and Tier
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          'ID: ${user?.memberId ?? '000'} • ${_getTierText(user?.tier, isArabic)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Profile Content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistics Section
                  Text(
                    isArabic ? 'الإحصائيات' : 'Statistics',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.account_balance_wallet,
                          label: isArabic ? 'الرصيد' : 'Balance',
                          value: '${user?.totalBalance.toStringAsFixed(0) ?? '0'} LE',
                          color: AppTheme.successColor,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.stars,
                          label: isArabic ? 'النقاط' : 'Points',
                          value: '${user?.points ?? 0}',
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
                          icon: Icons.trending_up,
                          label: isArabic ? 'حد المحطة' : 'Station Limit',
                          value: '${user?.stationLimit ?? 0}',
                          color: AppTheme.primaryColor,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.gamepad,
                          label: isArabic ? 'المساهمات' : 'Contributions',
                          value: '${user?.totalShares ?? 0}',
                          color: AppTheme.infoColor,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  // Quick Actions Section
                  Text(
                    isArabic ? 'الإجراءات السريعة' : 'Quick Actions',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Add Contribution Button
                  _buildActionButton(
                    icon: FontAwesomeIcons.plus,
                    title: isArabic ? 'إضافة مساهمة' : 'Add Contribution',
                    subtitle: isArabic
                        ? 'ساهم بلعبة أو مبلغ مالي'
                        : 'Contribute a game or fund',
                    color: AppTheme.successColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddContributionScreen(),
                        ),
                      );
                    },
                    isDarkMode: isDarkMode,
                  ),

                  SizedBox(height: 12.h),

                  // Menu Items
                  Text(
                    isArabic ? 'الإعدادات' : 'Settings',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12.h),

                  _buildMenuItem(
                    icon: Icons.person_outline,
                    title: isArabic ? 'معلومات الحساب' : 'Account Information',
                    onTap: () {
                      // Navigate to account info
                    },
                    isDarkMode: isDarkMode,
                  ),
                  _buildMenuItem(
                    icon: Icons.history,
                    title: isArabic ? 'سجل المعاملات' : 'Transaction History',
                    onTap: () {
                      // Navigate to transaction history
                    },
                    isDarkMode: isDarkMode,
                  ),
                  _buildMenuItem(
                    icon: Icons.card_giftcard,
                    title: isArabic ? 'المكافآت والإحالات' : 'Rewards & Referrals',
                    onTap: () {
                      // Navigate to rewards
                    },
                    isDarkMode: isDarkMode,
                  ),
                  _buildMenuItem(
                    icon: Icons.notifications_outlined,
                    title: isArabic ? 'الإشعارات' : 'Notifications',
                    onTap: () {
                      // Navigate to notifications
                    },
                    isDarkMode: isDarkMode,
                  ),
                  _buildMenuItem(
                    icon: Icons.language,
                    title: isArabic ? 'اللغة' : 'Language',
                    trailing: Text(
                      isArabic ? 'العربية' : 'English',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 14.sp,
                      ),
                    ),
                    onTap: () {
                      appProvider.toggleLanguage();
                    },
                    isDarkMode: isDarkMode,
                  ),
                  _buildMenuItem(
                    icon: isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    title: isArabic ? 'المظهر' : 'Theme',
                    trailing: Switch(
                      value: isDarkMode,
                      onChanged: (value) {
                        appProvider.toggleTheme();
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    onTap: () {
                      appProvider.toggleTheme();
                    },
                    isDarkMode: isDarkMode,
                  ),
                  _buildMenuItem(
                    icon: Icons.help_outline,
                    title: isArabic ? 'المساعدة والدعم' : 'Help & Support',
                    onTap: () {
                      // Navigate to help
                    },
                    isDarkMode: isDarkMode,
                  ),
                  _buildMenuItem(
                    icon: Icons.info_outline,
                    title: isArabic ? 'حول التطبيق' : 'About App',
                    onTap: () {
                      // Navigate to about
                    },
                    isDarkMode: isDarkMode,
                  ),

                  SizedBox(height: 24.h),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 56.h,
                    child: ElevatedButton(
                      onPressed: () {
                        _showLogoutDialog(context, isArabic);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.white),
                          SizedBox(width: 8.w),
                          Text(
                            isArabic ? 'تسجيل الخروج' : 'Logout',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode
            ? color.withOpacity(0.2)
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 28.sp,
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
            label,
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

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
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
                icon,
                color: Colors.white,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppTheme.darkSurface
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: AppTheme.primaryColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
          ),
        ),
        trailing: trailing ?? Icon(
          Icons.chevron_right,
          color: Colors.grey,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  String _getTierText(UserTier? tier, bool isArabic) {
    if (tier == null) return '';

    switch (tier) {
      case UserTier.admin:
        return isArabic ? 'مدير' : 'Admin';
      case UserTier.vip:
        return isArabic ? 'VIP' : 'VIP';
      case UserTier.member:
        return isArabic ? 'عضو' : 'Member';
      case UserTier.client:
        return isArabic ? 'عميل' : 'Client';
      case UserTier.user:
        return isArabic ? 'مستخدم' : 'User';
    }
  }

  void _showLogoutDialog(BuildContext context, bool isArabic) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            isArabic ? 'تسجيل الخروج' : 'Logout',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            isArabic
                ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟'
                : 'Are you sure you want to logout?',
            style: TextStyle(fontSize: 16.sp),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                isArabic ? 'إلغاء' : 'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16.sp,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                await authProvider.signOut();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                      (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                isArabic ? 'تسجيل الخروج' : 'Logout',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}