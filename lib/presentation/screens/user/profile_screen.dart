import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../routes/app_routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
          isArabic ? 'الملف الشخصي' : 'Profile',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              // Navigate to edit profile
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.secondaryColor,
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 100.w,
                    height: 100.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      FontAwesomeIcons.user,
                      size: 50.sp,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Name
                  Text(
                    user?.name ?? 'User',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // Member ID & Tier
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ID: ${user?.memberId ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: _getTierColor(user?.tier),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            user?.tier.displayName ?? 'User',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Stats Section
            Container(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'الإحصائيات' : 'Statistics',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: FontAwesomeIcons.coins,
                          label: isArabic ? 'الرصيد' : 'Balance',
                          value: '${user?.totalBalance.toStringAsFixed(2) ?? '0.00'} LE',
                          color: AppTheme.successColor,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatCard(
                          icon: FontAwesomeIcons.star,
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
                          icon: FontAwesomeIcons.handHoldingDollar,
                          label: isArabic ? 'المساهمات' : 'Contributions',
                          value: '${user?.totalShares ?? 0}',
                          color: AppTheme.primaryColor,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatCard(
                          icon: FontAwesomeIcons.gamepad,
                          label: isArabic ? 'الاستعارات' : 'Borrows',
                          value: '${user?.currentBorrows ?? 0}/${user?.borrowLimit ?? 1}',
                          color: AppTheme.infoColor,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu Items
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: FontAwesomeIcons.userPen,
                    title: isArabic ? 'تعديل الملف الشخصي' : 'Edit Profile',
                    onTap: () {
                      // Navigate to edit profile
                    },
                  ),
                  _buildMenuItem(
                    icon: FontAwesomeIcons.clockRotateLeft,
                    title: isArabic ? 'سجل المعاملات' : 'Transaction History',
                    onTap: () {
                      // Navigate to transaction history
                    },
                  ),
                  _buildMenuItem(
                    icon: FontAwesomeIcons.userGroup,
                    title: isArabic ? 'الإحالات' : 'Referrals',
                    subtitle: isArabic
                        ? '${user?.referredUsers.length ?? 0} إحالة'
                        : '${user?.referredUsers.length ?? 0} referrals',
                    onTap: () {
                      // Navigate to referrals
                    },
                  ),
                  _buildMenuItem(
                    icon: FontAwesomeIcons.gear,
                    title: isArabic ? 'الإعدادات' : 'Settings',
                    onTap: () {
                      // Navigate to settings
                    },
                  ),
                  _buildMenuItem(
                    icon: FontAwesomeIcons.circleQuestion,
                    title: isArabic ? 'المساعدة والدعم' : 'Help & Support',
                    onTap: () {
                      // Navigate to help
                    },
                  ),
                  _buildMenuItem(
                    icon: FontAwesomeIcons.shield,
                    title: isArabic ? 'الشروط والأحكام' : 'Terms & Conditions',
                    onTap: () {
                      // Navigate to terms
                    },
                  ),
                  SizedBox(height: 16.h),
                  // Logout Button
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Show confirmation dialog
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              isArabic ? 'تسجيل الخروج' : 'Logout',
                            ),
                            content: Text(
                              isArabic
                                  ? 'هل أنت متأكد من تسجيل الخروج؟'
                                  : 'Are you sure you want to logout?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.errorColor,
                                ),
                                child: Text(isArabic ? 'خروج' : 'Logout'),
                              ),
                            ],
                          ),
                        );

                        if (shouldLogout == true) {
                          await authProvider.signOut();
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.login,
                                (route) => false,
                          );
                        }
                      },
                      icon: Icon(FontAwesomeIcons.rightFromBracket),
                      label: Text(
                        isArabic ? 'تسجيل الخروج' : 'Logout',
                        style: TextStyle(fontSize: 16.sp),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ],
        ),
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
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
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

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Provider.of<AppProvider>(context, listen: false).isDarkMode;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 20.sp,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.sp,
            color: isDarkMode
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        )
            : null,
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16.sp,
          color: isDarkMode
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
        ),
        tileColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
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