// lib/presentation/screens/user/transaction_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> with SingleTickerProviderStateMixin {
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
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          isArabic ? 'سجل المعاملات' : 'Transaction History',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: isArabic ? 'الكل' : 'All',
              icon: Icon(Icons.list, size: 20.sp),
            ),
            Tab(
              text: isArabic ? 'المساهمات' : 'Contributions',
              icon: Icon(FontAwesomeIcons.plus, size: 18.sp),
            ),
            Tab(
              text: isArabic ? 'الاستعارات' : 'Borrowings',
              icon: Icon(FontAwesomeIcons.handHolding, size: 18.sp),
            ),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: false,
        ),
      ),
      body: user == null
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllTransactionsTab(isArabic, isDarkMode, user),
                _buildContributionsTab(isArabic, isDarkMode, user),
                _buildBorrowingsTab(isArabic, isDarkMode, user),
              ],
            ),
    );
  }

  Widget _buildAllTransactionsTab(bool isArabic, bool isDarkMode, dynamic user) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // Summary Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
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
            child: Column(
              children: [
                Icon(FontAwesomeIcons.chartLine, color: Colors.white, size: 32.sp),
                SizedBox(height: 12.h),
                Text(
                  isArabic ? 'إجمالي المعاملات' : 'Total Transactions',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '0', // Replace with actual count
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Transactions List
          _buildTransactionsList(isArabic, isDarkMode, 'all'),
        ],
      ),
    );
  }

  Widget _buildContributionsTab(bool isArabic, bool isDarkMode, dynamic user) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // Contributions Summary
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: isArabic ? 'مساهمات الألعاب' : 'Game Contributions',
                  value: '0', // Replace with actual data
                  icon: FontAwesomeIcons.gamepad,
                  color: AppTheme.infoColor,
                  isDarkMode: isDarkMode,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildStatCard(
                  title: isArabic ? 'مساهمات الصندوق' : 'Fund Contributions',
                  value: '0 LE', // Replace with actual data
                  icon: FontAwesomeIcons.coins,
                  color: AppTheme.successColor,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          _buildTransactionsList(isArabic, isDarkMode, 'contributions'),
        ],
      ),
    );
  }

  Widget _buildBorrowingsTab(bool isArabic, bool isDarkMode, dynamic user) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // Borrowings Summary
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: isArabic ? 'إجمالي الاستعارات' : 'Total Borrowings',
                  value: '0', // Replace with actual data
                  icon: FontAwesomeIcons.handHolding,
                  color: AppTheme.warningColor,
                  isDarkMode: isDarkMode,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildStatCard(
                  title: isArabic ? 'الاستعارات النشطة' : 'Active Borrowings',
                  value: '0', // Replace with actual data
                  icon: FontAwesomeIcons.clock,
                  color: AppTheme.primaryColor,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          _buildTransactionsList(isArabic, isDarkMode, 'borrowings'),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(bool isArabic, bool isDarkMode, String type) {
    // For now, show empty state with sample transactions
    final sampleTransactions = [
      {
        'type': 'contribution',
        'title': isArabic ? 'مساهمة لعبة' : 'Game Contribution',
        'description': 'FIFA 24 - PS5',
        'amount': '+1.0',
        'date': DateTime.now().subtract(Duration(days: 1)),
        'icon': FontAwesomeIcons.gamepad,
        'color': AppTheme.successColor,
      },
      {
        'type': 'borrowing',
        'title': isArabic ? 'استعارة لعبة' : 'Game Borrowing',
        'description': 'Call of Duty - PS5',
        'amount': '-0.5',
        'date': DateTime.now().subtract(Duration(days: 3)),
        'icon': FontAwesomeIcons.handHolding,
        'color': AppTheme.warningColor,
      },
      {
        'type': 'points',
        'title': isArabic ? 'نقاط مكافأة' : 'Reward Points',
        'description': isArabic ? 'مكافأة شهرية' : 'Monthly reward',
        'amount': '+50',
        'date': DateTime.now().subtract(Duration(days: 5)),
        'icon': FontAwesomeIcons.star,
        'color': AppTheme.infoColor,
      },
    ];

    // Filter based on type
    final filteredTransactions = type == 'all' 
        ? sampleTransactions
        : sampleTransactions.where((t) => t['type'] == type).toList();

    if (filteredTransactions.isEmpty) {
      return _buildEmptyState(isArabic);
    }

    return Column(
      children: filteredTransactions.map((transaction) {
        return _buildTransactionItem(
          title: transaction['title'] as String,
          description: transaction['description'] as String,
          amount: transaction['amount'] as String,
          date: transaction['date'] as DateTime,
          icon: transaction['icon'] as IconData,
          color: transaction['color'] as Color,
          isArabic: isArabic,
          isDarkMode: isDarkMode,
        );
      }).toList(),
    );
  }

  Widget _buildTransactionItem({
    required String title,
    required String description,
    required String amount,
    required DateTime date,
    required IconData icon,
    required Color color,
    required bool isArabic,
    required bool isDarkMode,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
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
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _formatDate(date, isArabic),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: amount.startsWith('+') ? AppTheme.successColor : color,
            ),
          ),
        ],
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
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isArabic) {
    return Container(
      padding: EdgeInsets.all(40.w),
      child: Column(
        children: [
          Icon(
            FontAwesomeIcons.receipt,
            size: 64.sp,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16.h),
          Text(
            isArabic ? 'لا توجد معاملات' : 'No Transactions',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            isArabic 
                ? 'ستظهر معاملاتك هنا'
                : 'Your transactions will appear here',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date, bool isArabic) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return isArabic ? 'اليوم' : 'Today';
    } else if (difference.inDays == 1) {
      return isArabic ? 'أمس' : 'Yesterday';
    } else if (difference.inDays < 30) {
      return isArabic 
          ? 'منذ ${difference.inDays} أيام'
          : '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}