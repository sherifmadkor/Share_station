import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
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
          isArabic ? 'لوحة تحكم المدير' : 'Admin Dashboard',
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
            // Admin Info Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.adminColor, AppTheme.adminColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic
                        ? 'مرحباً، ${user?.name ?? 'مدير'}'
                        : 'Welcome, ${user?.name ?? 'Admin'}',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.shieldHalved,
                        color: Colors.white70,
                        size: 16.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        isArabic ? 'صلاحيات كاملة' : 'Full Access',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Borrow Window Control
            Container(
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
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: AppTheme.primaryColor,
                    size: 32.sp,
                  ),
                  SizedBox(width: 16.w),
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
                          isArabic
                              ? 'التحكم في توقيت الاستعارة'
                              : 'Control borrowing availability',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDarkMode
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: appProvider.isBorrowWindowOpen,
                    onChanged: (value) {
                      appProvider.toggleBorrowWindow(value);
                    },
                    activeColor: AppTheme.successColor,
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Quick Stats
            Text(
              isArabic ? 'إحصائيات سريعة' : 'Quick Stats',
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
              childAspectRatio: 1.4, // FIXED: Changed from 1.5 to give more height
              children: [
                _buildStatCard(
                  title: isArabic ? 'المستخدمون' : 'Total Users',
                  value: '250+',
                  icon: FontAwesomeIcons.users,
                  color: AppTheme.primaryColor,
                  isDarkMode: isDarkMode,
                ),
                _buildStatCard(
                  title: isArabic ? 'الألعاب' : 'Total Games',
                  value: '150+',
                  icon: FontAwesomeIcons.gamepad,
                  color: AppTheme.secondaryColor,
                  isDarkMode: isDarkMode,
                ),
                _buildStatCard(
                  title: isArabic ? 'في الانتظار' : 'Pending',
                  value: '5',
                  icon: FontAwesomeIcons.clock,
                  color: AppTheme.warningColor,
                  isDarkMode: isDarkMode,
                ),
                _buildStatCard(
                  title: isArabic ? 'الإيرادات' : 'Revenue',
                  value: '15,000 LE',
                  icon: FontAwesomeIcons.dollarSign,
                  color: AppTheme.successColor,
                  isDarkMode: isDarkMode,
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

            _buildActionTile(
              title: isArabic ? 'إدارة المستخدمين' : 'Manage Users',
              subtitle: isArabic
                  ? 'عرض وتعديل بيانات المستخدمين'
                  : 'View and edit user information',
              icon: FontAwesomeIcons.userGear,
              color: AppTheme.primaryColor,
              onTap: () {
                // Navigate to manage users
              },
            ),

            _buildActionTile(
              title: isArabic ? 'إدارة الألعاب' : 'Manage Games',
              subtitle: isArabic
                  ? 'إضافة وتعديل الألعاب'
                  : 'Add and edit games',
              icon: FontAwesomeIcons.gamepad,
              color: AppTheme.secondaryColor,
              onTap: () {
                // Navigate to manage games
              },
            ),

            _buildActionTile(
              title: isArabic ? 'الموافقات المعلقة' : 'Pending Approvals',
              subtitle: isArabic
                  ? 'مراجعة طلبات العضوية الجديدة'
                  : 'Review new membership requests',
              icon: FontAwesomeIcons.userCheck,
              color: AppTheme.warningColor,
              onTap: () {
                // Navigate to pending approvals
              },
            ),

            _buildActionTile(
              title: isArabic ? 'التحليلات' : 'Analytics',
              subtitle: isArabic
                  ? 'عرض التقارير والإحصائيات'
                  : 'View reports and statistics',
              icon: FontAwesomeIcons.chartLine,
              color: AppTheme.infoColor,
              onTap: () {
                // Navigate to analytics
              },
            ),

            _buildActionTile(
              title: isArabic ? 'ترحيل البيانات' : 'Data Migration',
              subtitle: isArabic
                  ? 'استيراد البيانات من Excel'
                  : 'Import data from Excel',
              icon: FontAwesomeIcons.fileImport,
              color: AppTheme.successColor,
              onTap: () {
                // Navigate to data migration
              },
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
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h), // FIXED: Reduced spacing from 4.h
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

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Provider.of<AppProvider>(context, listen: false).isDarkMode;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24.sp,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.sp,
            color: isDarkMode
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
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
}