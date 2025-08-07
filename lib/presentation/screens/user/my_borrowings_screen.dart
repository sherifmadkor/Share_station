import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class MyBorrowingsScreen extends StatefulWidget {
  const MyBorrowingsScreen({Key? key}) : super(key: key);

  @override
  State<MyBorrowingsScreen> createState() => _MyBorrowingsScreenState();
}

class _MyBorrowingsScreenState extends State<MyBorrowingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          isArabic ? 'استعاراتي' : 'My Borrowings',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: isDarkMode
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
          tabs: [
            Tab(text: isArabic ? 'الحالية' : 'Current'),
            Tab(text: isArabic ? 'في الانتظار' : 'Pending'),
            Tab(text: isArabic ? 'السابقة' : 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Current Borrowings
          _buildCurrentBorrowings(),
          // Pending/Reserved
          _buildPendingBorrowings(),
          // History
          _buildBorrowingHistory(),
        ],
      ),
    );
  }

  Widget _buildCurrentBorrowings() {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final user = authProvider.currentUser;

    // Dummy data for testing
    final hasCurrentBorrowings = true;

    if (!hasCurrentBorrowings) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.gamepad,
              size: 64.sp,
              color: Colors.grey,
            ),
            SizedBox(height: 16.h),
            Text(
              isArabic ? 'لا توجد استعارات حالية' : 'No current borrowings',
              style: TextStyle(
                fontSize: 18.sp,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              isArabic
                  ? 'تصفح الألعاب المتاحة للاستعارة'
                  : 'Browse available games to borrow',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: 2, // Dummy count
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 16.h),
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
          child: ListTile(
            contentPadding: EdgeInsets.all(12.w),
            leading: Container(
              width: 60.w,
              height: 60.h,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                FontAwesomeIcons.gamepad,
                color: AppTheme.primaryColor,
                size: 28.sp,
              ),
            ),
            title: Text(
              index == 0 ? 'Spider-Man 2' : 'FC 24',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        'PS5',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.memberColor,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        'Primary',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14.sp,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      isArabic
                          ? 'مستعار منذ: 2 أيام'
                          : 'Borrowed: 2 days ago',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(
                      Icons.timer,
                      size: 14.sp,
                      color: AppTheme.warningColor,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      isArabic
                          ? 'متبقي: 28 يوم'
                          : 'Remaining: 28 days',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              icon: Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20.sp),
                      SizedBox(width: 8.w),
                      Text(isArabic ? 'التفاصيل' : 'Details'),
                    ],
                  ),
                  value: 'details',
                ),
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.assignment_return, size: 20.sp),
                      SizedBox(width: 8.w),
                      Text(isArabic ? 'إرجاع' : 'Return'),
                    ],
                  ),
                  value: 'return',
                ),
              ],
              onSelected: (value) {
                // Handle menu selection
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingBorrowings() {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.clock,
            size: 64.sp,
            color: Colors.grey,
          ),
          SizedBox(height: 16.h),
          Text(
            isArabic ? 'لا توجد طلبات معلقة' : 'No pending requests',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowingHistory() {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: 5, // Dummy count
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50.w,
                height: 50.h,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  FontAwesomeIcons.gamepad,
                  color: Colors.grey,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Game Title ${index + 1}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      isArabic
                          ? 'تم الإرجاع: ${30 - index * 5} يوم مضت'
                          : 'Returned: ${30 - index * 5} days ago',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8.w,
                  vertical: 4.h,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  isArabic ? 'مكتمل' : 'Completed',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}