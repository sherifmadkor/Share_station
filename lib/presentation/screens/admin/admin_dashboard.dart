// lib/presentation/screens/admin/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({Key? key}) : super(key: key);

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
          isArabic ? 'لوحة التحكم الإدارية' : 'Admin Dashboard',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.notifications);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30.r,
                    backgroundColor: Colors.white,
                    child: Icon(
                      FontAwesomeIcons.userShield,
                      color: AppTheme.primaryColor,
                      size: 28.sp,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic
                              ? 'مرحباً، ${authProvider.currentUser?.name ?? "المشرف"}'
                              : 'Welcome, ${authProvider.currentUser?.name ?? "Admin"}',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          isArabic ? 'لوحة التحكم الكاملة' : 'Full Control Panel',
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
            ),

            SizedBox(height: 24.h),

            // Statistics Section
            Text(
              isArabic ? 'الإحصائيات' : 'Statistics',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 12.h),

            // Real-time stats grid
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              children: [
                // Total Members - Fixed query
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('tier', whereIn: ['member', 'vip', 'client'])
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return _buildStatCard(
                      title: isArabic ? 'الأعضاء' : 'Members',
                      value: count.toString(),
                      icon: FontAwesomeIcons.users,
                      color: AppTheme.primaryColor,
                      isDarkMode: isDarkMode,
                    );
                  },
                ),

                // Total Game Accounts - Fixed query
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('games')
                      .snapshots(),
                  builder: (context, snapshot) {
                    int totalAccounts = 0;
                    if (snapshot.hasData) {
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        // Count accounts if they exist, otherwise count as 1
                        if (data['accounts'] != null && data['accounts'] is List) {
                          totalAccounts += (data['accounts'] as List).length;
                        } else {
                          totalAccounts += 1; // Old structure, count as single account
                        }
                      }
                    }
                    return _buildStatCard(
                      title: isArabic ? 'الألعاب' : 'Game Accounts',
                      value: totalAccounts.toString(),
                      icon: FontAwesomeIcons.gamepad,
                      color: AppTheme.secondaryColor,
                      isDarkMode: isDarkMode,
                    );
                  },
                ),

                // Pending Contributions
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('contribution_requests')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return _buildStatCard(
                      title: isArabic ? 'مساهمات معلقة' : 'Pending Contrib.',
                      value: count.toString(),
                      icon: FontAwesomeIcons.clock,
                      color: AppTheme.warningColor,
                      isDarkMode: isDarkMode,
                    );
                  },
                ),

                // Active Borrows
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('borrow_requests')
                      .where('status', isEqualTo: 'approved')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return _buildStatCard(
                      title: isArabic ? 'استعارات نشطة' : 'Active Borrows',
                      value: count.toString(),
                      icon: FontAwesomeIcons.handHoldingUsd,
                      color: AppTheme.successColor,
                      isDarkMode: isDarkMode,
                    );
                  },
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Admin Actions
            Text(
              isArabic ? 'الإجراءات الإدارية' : 'Admin Actions',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 12.h),

            // Action tiles
            _buildActionTile(
              title: isArabic ? 'إدارة المستخدمين' : 'Manage Users',
              subtitle: isArabic
                  ? 'عرض وتعديل بيانات المستخدمين'
                  : 'View and edit user information',
              icon: FontAwesomeIcons.userGear,
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.manageUsers);
              },
              context: context,
            ),

            _buildActionTile(
              title: isArabic ? 'إدارة المساهمات' : 'Manage Contributions',
              subtitle: isArabic
                  ? 'الموافقة على المساهمات الجديدة'
                  : 'Approve new game contributions',
              icon: FontAwesomeIcons.handHoldingUsd,
              color: AppTheme.warningColor,
              badge: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('contribution_requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return count > 0
                      ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                      : SizedBox.shrink();
                },
              ),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.manageContributions);
              },
              context: context,
            ),

            _buildActionTile(
              title: isArabic ? 'طلبات الاستعارة' : 'Borrow Requests',
              subtitle: isArabic
                  ? 'إدارة طلبات الاستعارة والإرجاع'
                  : 'Manage borrow and return requests',
              icon: FontAwesomeIcons.exchange,
              color: AppTheme.infoColor,
              badge: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('borrow_requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return count > 0
                      ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                      : SizedBox.shrink();
                },
              ),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.borrowRequests);
              },
              context: context,
            ),

            _buildActionTile(
              title: isArabic ? 'إدارة الألعاب' : 'Manage Games',
              subtitle: isArabic
                  ? 'إضافة وتعديل الألعاب'
                  : 'Add and edit games',
              icon: FontAwesomeIcons.gamepad,
              color: AppTheme.secondaryColor,
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.manageGames);
              },
              context: context,
            ),

            _buildActionTile(
              title: isArabic ? 'التحليلات' : 'Analytics',
              subtitle: isArabic
                  ? 'عرض التقارير والإحصائيات'
                  : 'View reports and statistics',
              icon: FontAwesomeIcons.chartLine,
              color: AppTheme.successColor,
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.analytics);
              },
              context: context,
            ),

            _buildActionTile(
              title: isArabic ? 'الإعدادات' : 'Settings',
              subtitle: isArabic
                  ? 'إعدادات النظام والتكوين'
                  : 'System settings and configuration',
              icon: FontAwesomeIcons.cog,
              color: Colors.grey,
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.adminSettings);
              },
              context: context,
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
            offset: Offset(0, 4),
          ),
        ],
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
            value,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
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
    required BuildContext context,
    Widget? badge,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
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
                          if (badge != null) ...[
                            SizedBox(width: 8.w),
                            badge,
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}