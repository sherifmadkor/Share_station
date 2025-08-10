// lib/presentation/screens/user/referral_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class ReferralDashboardScreen extends StatefulWidget {
  const ReferralDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ReferralDashboardScreen> createState() => _ReferralDashboardScreenState();
}

class _ReferralDashboardScreenState extends State<ReferralDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String _referralCode = '';
  double _totalEarnings = 0;
  List<Map<String, dynamic>> _referredUsers = [];
  List<Map<String, dynamic>> _earningsHistory = [];
  Map<String, dynamic> _earningsBreakdown = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReferralData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReferralData() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data()!;

      _referralCode = userData['memberId'] ?? 'N/A';
      _totalEarnings = (userData['referralEarnings'] ?? 0).toDouble();

      // Get referred users
      final referredUserIds = List<String>.from(userData['referredUsers'] ?? []);
      _referredUsers = [];

      for (String userId in referredUserIds) {
        final referredUserDoc = await _firestore.collection('users').doc(userId).get();
        if (referredUserDoc.exists) {
          final referredData = referredUserDoc.data()!;
          _referredUsers.add({
            'id': userId,
            'name': referredData['name'] ?? 'Unknown',
            'email': referredData['email'] ?? '',
            'tier': referredData['tier'] ?? 'member',
            'joinDate': referredData['joinDate'],
            'status': referredData['status'] ?? 'active',
            'totalBorrows': referredData['totalBorrowsCount'] ?? 0,
            'contributions': referredData['totalShares'] ?? 0,
          });
        }
      }

      // Load earnings history
      await _loadEarningsHistory(user.uid);

      // Calculate breakdown
      _calculateEarningsBreakdown();

    } catch (e) {
      print('Error loading referral data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadEarningsHistory(String userId) async {
    try {
      final historySnapshot = await _firestore
          .collection('referral_earnings')
          .where('referrerId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      _earningsHistory = historySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error loading earnings history: $e');
      _earningsHistory = [];
    }
  }

  void _calculateEarningsBreakdown() {
    double membershipEarnings = 0;
    double borrowingEarnings = 0;
    double contributionEarnings = 0;

    for (var earning in _earningsHistory) {
      final type = earning['type'] ?? '';
      final amount = (earning['amount'] ?? 0).toDouble();

      switch (type) {
        case 'membership':
          membershipEarnings += amount;
          break;
        case 'borrowing':
          borrowingEarnings += amount;
          break;
        case 'contribution':
          contributionEarnings += amount;
          break;
      }
    }

    _earningsBreakdown = {
      'membership': membershipEarnings,
      'borrowing': borrowingEarnings,
      'contribution': contributionEarnings,
    };
  }

  void _copyReferralCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    Fluttertoast.showToast(
      msg: 'Referral code copied!',
      backgroundColor: AppTheme.successColor,
    );
  }

  void _shareReferralCode() {
    final message = '''
Join Share Station using my referral code: $_referralCode

Download the app and enter my code during registration to get started!

Benefits:
✓ Access to premium game library
✓ Flexible borrowing options
✓ Earn points and rewards
✓ Join our gaming community

Sign up now!
''';

    Share.share(message, subject: 'Join Share Station!');
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          isArabic ? 'لوحة الإحالات' : 'Referral Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: Icon(Icons.dashboard, size: 20.sp),
              text: isArabic ? 'نظرة عامة' : 'Overview',
            ),
            Tab(
              icon: Icon(Icons.people, size: 20.sp),
              text: isArabic ? 'المُحالون' : 'Referred',
            ),
            Tab(
              icon: Icon(Icons.history, size: 20.sp),
              text: isArabic ? 'السجل' : 'History',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(isArabic, isDarkMode),
          _buildReferredUsersTab(isArabic, isDarkMode),
          _buildHistoryTab(isArabic, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(bool isArabic, bool isDarkMode) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Referral Code Card
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  offset: Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  isArabic ? 'كود الإحالة الخاص بك' : 'Your Referral Code',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    _referralCode,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _copyReferralCode,
                      icon: Icon(Icons.copy, size: 18.sp),
                      label: Text(isArabic ? 'نسخ' : 'Copy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 10.h,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    ElevatedButton.icon(
                      onPressed: _shareReferralCode,
                      icon: Icon(Icons.share, size: 18.sp),
                      label: Text(isArabic ? 'مشاركة' : 'Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 10.h,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                title: isArabic ? 'إجمالي الأرباح' : 'Total Earnings',
                value: '${_totalEarnings.toStringAsFixed(0)} LE',
                icon: FontAwesomeIcons.moneyBillWave,
                color: AppTheme.successColor,
                isDarkMode: isDarkMode,
              ),
              _buildStatCard(
                title: isArabic ? 'المستخدمون المُحالون' : 'Referred Users',
                value: _referredUsers.length.toString(),
                icon: Icons.people,
                color: AppTheme.primaryColor,
                isDarkMode: isDarkMode,
              ),
              _buildStatCard(
                title: isArabic ? 'النشطون' : 'Active',
                value: _referredUsers.where((u) => u['status'] == 'active').length.toString(),
                icon: Icons.person_add,
                color: AppTheme.infoColor,
                isDarkMode: isDarkMode,
              ),
              _buildStatCard(
                title: isArabic ? 'معدل النجاح' : 'Success Rate',
                value: _referredUsers.isEmpty
                    ? '0%'
                    : '${(_referredUsers.where((u) => u['status'] == 'active').length / _referredUsers.length * 100).toStringAsFixed(0)}%',
                icon: Icons.trending_up,
                color: AppTheme.warningColor,
                isDarkMode: isDarkMode,
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // Earnings Breakdown
          Text(
            isArabic ? 'تفصيل الأرباح' : 'Earnings Breakdown',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),

          _buildEarningsItem(
            title: isArabic ? 'رسوم العضوية' : 'Membership Fees',
            amount: _earningsBreakdown['membership'] ?? 0,
            icon: Icons.card_membership,
            color: AppTheme.primaryColor,
            isDarkMode: isDarkMode,
          ),
          _buildEarningsItem(
            title: isArabic ? 'رسوم الاستعارة' : 'Borrowing Fees',
            amount: _earningsBreakdown['borrowing'] ?? 0,
            icon: FontAwesomeIcons.gamepad,
            color: AppTheme.successColor,
            isDarkMode: isDarkMode,
          ),
          _buildEarningsItem(
            title: isArabic ? 'رسوم المساهمات' : 'Contribution Fees',
            amount: _earningsBreakdown['contribution'] ?? 0,
            icon: FontAwesomeIcons.handHoldingDollar,
            color: AppTheme.warningColor,
            isDarkMode: isDarkMode,
          ),

          SizedBox(height: 24.h),

          // How It Works Section
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.infoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppTheme.infoColor.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.infoColor,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      isArabic ? 'كيف يعمل؟' : 'How It Works',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.infoColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                _buildHowItWorksItem(
                  '1',
                  isArabic
                      ? 'شارك كود الإحالة الخاص بك'
                      : 'Share your referral code',
                  isDarkMode,
                ),
                _buildHowItWorksItem(
                  '2',
                  isArabic
                      ? 'يسجل الأصدقاء باستخدام الكود'
                      : 'Friends sign up using your code',
                  isDarkMode,
                ),
                _buildHowItWorksItem(
                  '3',
                  isArabic
                      ? 'احصل على 20% من جميع أنشطتهم'
                      : 'Earn 20% from all their activities',
                  isDarkMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferredUsersTab(bool isArabic, bool isDarkMode) {
    if (_referredUsers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: isArabic ? 'لا يوجد مستخدمون محالون' : 'No Referred Users',
        subtitle: isArabic
            ? 'شارك كود الإحالة الخاص بك لبدء الكسب'
            : 'Share your referral code to start earning',
        isDarkMode: isDarkMode,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _referredUsers.length,
      itemBuilder: (context, index) {
        final user = _referredUsers[index];
        return _buildReferredUserCard(user, isArabic, isDarkMode);
      },
    );
  }

  Widget _buildHistoryTab(bool isArabic, bool isDarkMode) {
    if (_earningsHistory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: isArabic ? 'لا يوجد سجل أرباح' : 'No Earnings History',
        subtitle: isArabic
            ? 'ستظهر أرباحك هنا'
            : 'Your earnings will appear here',
        isDarkMode: isDarkMode,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _earningsHistory.length,
      itemBuilder: (context, index) {
        final earning = _earningsHistory[index];
        return _buildEarningHistoryCard(earning, isArabic, isDarkMode);
      },
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
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24.sp),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDarkMode ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsItem({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
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
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(0)} LE',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksItem(String number, String text, bool isDarkMode) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            decoration: BoxDecoration(
              color: AppTheme.infoColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.sp,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferredUserCard(
      Map<String, dynamic> user,
      bool isArabic,
      bool isDarkMode,
      ) {
    final name = user['name'] ?? 'Unknown';
    final tier = user['tier'] ?? 'member';
    final status = user['status'] ?? 'active';
    final joinDate = (user['joinDate'] as Timestamp?)?.toDate();
    final totalBorrows = user['totalBorrows'] ?? 0;
    final contributions = (user['contributions'] ?? 0).toDouble();

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
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24.r,
                backgroundColor: _getTierColor(tier).withOpacity(0.2),
                child: Text(
                  name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: _getTierColor(tier),
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: _getTierColor(tier).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            tier.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: _getTierColor(tier),
                              fontWeight: FontWeight.bold,
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
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildUserStat(
                label: isArabic ? 'تاريخ الانضمام' : 'Joined',
                value: joinDate != null
                    ? DateFormat('dd/MM/yyyy').format(joinDate)
                    : 'N/A',
                icon: Icons.calendar_today,
              ),
              _buildUserStat(
                label: isArabic ? 'الاستعارات' : 'Borrows',
                value: totalBorrows.toString(),
                icon: FontAwesomeIcons.gamepad,
              ),
              _buildUserStat(
                label: isArabic ? 'المساهمات' : 'Shares',
                value: contributions.toStringAsFixed(0),
                icon: FontAwesomeIcons.handHoldingDollar,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16.sp, color: AppTheme.primaryColor),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildEarningHistoryCard(
      Map<String, dynamic> earning,
      bool isArabic,
      bool isDarkMode,
      ) {
    final amount = (earning['amount'] ?? 0).toDouble();
    final type = earning['type'] ?? '';
    final description = earning['description'] ?? '';
    final timestamp = (earning['timestamp'] as Timestamp?)?.toDate();
    final userName = earning['userName'] ?? 'Unknown User';

    IconData icon;
    Color color;

    switch (type) {
      case 'membership':
        icon = Icons.card_membership;
        color = AppTheme.primaryColor;
        break;
      case 'borrowing':
        icon = FontAwesomeIcons.gamepad;
        color = AppTheme.successColor;
        break;
      case 'contribution':
        icon = FontAwesomeIcons.handHoldingDollar;
        color = AppTheme.warningColor;
        break;
      default:
        icon = Icons.monetization_on;
        color = Colors.grey;
    }

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
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description.isNotEmpty ? description : type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '$userName • ${timestamp != null ? DateFormat('dd MMM yyyy').format(timestamp) : "N/A"}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${amount.toStringAsFixed(0)} LE',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.successColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64.sp,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: _shareReferralCode,
            icon: Icon(Icons.share),
            label: Text('Share Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 12.h,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'vip':
        return Colors.amber;
      case 'client':
        return Colors.blue;
      case 'member':
        return AppTheme.primaryColor;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppTheme.successColor;
      case 'suspended':
        return AppTheme.errorColor;
      case 'inactive':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }
}