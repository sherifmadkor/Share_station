// lib/presentation/screens/user/enhanced_referral_dashboard.dart

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
import '../../../services/referral_service.dart';

class EnhancedReferralDashboard extends StatefulWidget {
  const EnhancedReferralDashboard({Key? key}) : super(key: key);

  @override
  State<EnhancedReferralDashboard> createState() => _EnhancedReferralDashboardState();
}

class _EnhancedReferralDashboardState extends State<EnhancedReferralDashboard> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  final ReferralService _referralService = ReferralService();
  
  bool _isLoading = true;
  Map<String, dynamic> _referralStats = {};
  
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
    setState(() => _isLoading = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;
      
      if (currentUser != null) {
        print('=== ENHANCED REFERRAL DASHBOARD DEBUG ===');
        print('Loading referral data for user: ${currentUser.uid}');
        print('User email: ${currentUser.email}');
        print('User name: ${currentUser.name}');
        print('User memberId: ${currentUser.memberId}');
        
        // First, get the referral code directly
        final referralCode = await _referralService.getUserReferralCode(currentUser.uid);
        print('Got referral code directly: $referralCode');
        
        // Then get the full stats
        final stats = await _referralService.getReferralStats(currentUser.uid);
        print('Received full stats from getReferralStats:');
        print('  - totalReferrals: ${stats['totalReferrals']}');
        print('  - totalRevenue: ${stats['totalRevenue']}');
        print('  - pendingRevenue: ${stats['pendingRevenue']}');
        print('  - paidRevenue: ${stats['paidRevenue']}');
        print('  - referralHistory length: ${stats['referralHistory']?.length ?? 0}');
        print('  - referralCode from stats: ${stats['referralCode']}');
        
        // Check if there are any users with this user as recruiter
        final referredUsersQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('recruiterId', isEqualTo: referralCode)
            .get();
        
        print('Direct DB query for referred users:');
        print('  - Query: users where recruiterId == "$referralCode"');
        print('  - Found ${referredUsersQuery.docs.length} referred users');
        for (var doc in referredUsersQuery.docs) {
          final data = doc.data();
          print('  - Referred user: ${data['name']} (${data['email']}) - Member ID: ${data['memberId']}');
        }
        
        // Check referral records directly
        final referralRecordsQuery = await FirebaseFirestore.instance
            .collection('referrals')
            .where('referrerId', isEqualTo: currentUser.uid)
            .get();
        
        print('Direct DB query for referral records:');
        print('  - Query: referrals where referrerId == "${currentUser.uid}"');
        print('  - Found ${referralRecordsQuery.docs.length} referral records');
        for (var doc in referralRecordsQuery.docs) {
          final data = doc.data();
          print('  - Referral: ${data['referredUserId']} - Revenue: ${data['referralRevenue']} - Status: ${data['revenueStatus']}');
        }
        
        // Ensure the referral code is set correctly
        stats['referralCode'] = referralCode;
        
        print('Final stats being set to state: $stats');
        print('=== END ENHANCED REFERRAL DASHBOARD DEBUG ===');
        
        setState(() {
          _referralStats = stats;
          _isLoading = false;
        });
      } else {
        print('No current user found');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading referral data: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _referralStats = {
          'referralCode': '',
          'totalReferrals': 0,
          'totalRevenue': 0.0,
          'pendingRevenue': 0.0,
          'paidRevenue': 0.0,
          'referralHistory': [],
        };
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.locale.languageCode == 'ar';
    final isDarkMode = appProvider.isDarkMode;
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          isArabic ? 'لوحة الإحالات' : 'Referral Dashboard',
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadReferralData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: isArabic ? 'نظرة عامة' : 'Overview',
              icon: Icon(Icons.dashboard, size: 20.sp),
            ),
            Tab(
              text: isArabic ? 'الإحالات' : 'Referrals',
              icon: Icon(FontAwesomeIcons.users, size: 18.sp),
            ),
            Tab(
              text: isArabic ? 'الأرباح' : 'Earnings',
              icon: Icon(FontAwesomeIcons.chartLine, size: 18.sp),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(isArabic, isDarkMode, user),
                _buildReferralsTab(isArabic, isDarkMode, user),
                _buildEarningsTab(isArabic, isDarkMode, user),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(bool isArabic, bool isDarkMode, dynamic user) {
    final referralCode = _referralStats['referralCode'] ?? '';
    final totalReferrals = _referralStats['totalReferrals'] ?? 0;
    final totalRevenue = _referralStats['totalRevenue'] ?? 0.0;
    final pendingRevenue = _referralStats['pendingRevenue'] ?? 0.0;
    final paidRevenue = _referralStats['paidRevenue'] ?? 0.0;

    return RefreshIndicator(
      onRefresh: _loadReferralData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Referral Code Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.secondaryColor,
                    AppTheme.secondaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    FontAwesomeIcons.qrcode,
                    color: Colors.white,
                    size: 32.sp,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    isArabic ? 'كود الإحالة الخاص بك' : 'Your Referral Code',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: _isLoading 
                        ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Text(
                            referralCode.isEmpty ? 'No Code' : referralCode,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: referralCode.isNotEmpty ? () => _copyReferralCode(referralCode) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.secondaryColor,
                        ),
                        icon: Icon(Icons.copy),
                        label: Text(isArabic ? 'نسخ' : 'Copy'),
                      ),
                      SizedBox(width: 12.w),
                      ElevatedButton.icon(
                        onPressed: referralCode.isNotEmpty ? () => _shareReferralCode(referralCode, isArabic) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.secondaryColor,
                        ),
                        icon: Icon(Icons.share),
                        label: Text(isArabic ? 'مشاركة' : 'Share'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Statistics Grid
            Text(
              isArabic ? 'إحصائيات الإحالة' : 'Referral Statistics',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: isArabic ? 'إجمالي الإحالات' : 'Total Referrals',
                    value: totalReferrals.toString(),
                    icon: FontAwesomeIcons.users,
                    color: AppTheme.infoColor,
                    isDarkMode: isDarkMode,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildStatCard(
                    title: isArabic ? 'إجمالي الأرباح' : 'Total Earnings',
                    value: '${totalRevenue.toStringAsFixed(0)} LE',
                    icon: FontAwesomeIcons.coins,
                    color: AppTheme.successColor,
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
                    title: isArabic ? 'الأرباح المعلقة' : 'Pending Earnings',
                    value: '${pendingRevenue.toStringAsFixed(0)} LE',
                    icon: FontAwesomeIcons.clock,
                    color: AppTheme.warningColor,
                    isDarkMode: isDarkMode,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildStatCard(
                    title: isArabic ? 'الأرباح المدفوعة' : 'Paid Earnings',
                    value: '${paidRevenue.toStringAsFixed(0)} LE',
                    icon: FontAwesomeIcons.checkCircle,
                    color: AppTheme.primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // How It Works Section
            _buildHowItWorksSection(isArabic, isDarkMode),

            SizedBox(height: 24.h),

            // Revenue Breakdown
            _buildRevenueBreakdown(isArabic, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralsTab(bool isArabic, bool isDarkMode, dynamic user) {
    final referralHistory = _referralStats['referralHistory'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _loadReferralData,
      child: referralHistory.isEmpty
          ? _buildEmptyState(
              isArabic ? 'لا توجد إحالات بعد' : 'No Referrals Yet',
              isArabic ? 'ابدأ بمشاركة كود الإحالة الخاص بك' : 'Start sharing your referral code',
              FontAwesomeIcons.userPlus,
            )
          : ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: referralHistory.length,
              itemBuilder: (context, index) {
                final referral = referralHistory[index];
                return _buildReferralItem(referral, isArabic, isDarkMode);
              },
            ),
    );
  }

  Widget _buildEarningsTab(bool isArabic, bool isDarkMode, dynamic user) {
    final referralHistory = _referralStats['referralHistory'] as List? ?? [];
    final earningsHistory = referralHistory.where((r) => r['status'] == 'paid').toList();

    return RefreshIndicator(
      onRefresh: _loadReferralData,
      child: earningsHistory.isEmpty
          ? _buildEmptyState(
              isArabic ? 'لا توجد أرباح بعد' : 'No Earnings Yet',
              isArabic ? 'ستظهر أرباحك هنا بعد 90 يوماً' : 'Your earnings will appear here after 90 days',
              FontAwesomeIcons.chartLine,
            )
          : ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: earningsHistory.length,
              itemBuilder: (context, index) {
                final earning = earningsHistory[index];
                return _buildEarningItem(earning, isArabic, isDarkMode);
              },
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
              fontSize: 20.sp,
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

  Widget _buildReferralItem(Map<String, dynamic> referral, bool isArabic, bool isDarkMode) {
    final revenue = referral['revenue'] ?? 0.0;
    final paymentStatus = referral['status'] ?? 'pending'; // This is the payment status
    final referralStatus = referral['actualReferralStatus'] ?? 'approved'; // This is the referral approval status
    final tier = referral['tier'] ?? 'member';
    final memberName = referral['memberName'] ?? 'Unknown Member';
    final date = referral['referralDate'] as Timestamp?;

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
              color: _getStatusColor(referralStatus).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              FontAwesomeIcons.userCheck, // Use userCheck to show approved referral
              color: _getStatusColor(referralStatus),
              size: 20.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memberName,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${tier.toUpperCase()} ${isArabic ? "عضوية" : "Member"}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  date != null ? _formatDate(date.toDate(), isArabic) : 'N/A',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: _getPaymentStatusColor(paymentStatus),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    isArabic
                        ? (paymentStatus == 'paid' ? 'مدفوع' : 'معلق الدفع')
                        : (paymentStatus == 'paid' ? 'PAID' : 'PAYMENT PENDING'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${revenue.toStringAsFixed(0)} LE',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: _getPaymentStatusColor(paymentStatus),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningItem(Map<String, dynamic> earning, bool isArabic, bool isDarkMode) {
    final revenue = earning['revenue'] ?? 0.0;
    final date = earning['referralDate'] as Timestamp?;
    final borrowCommissions = earning['borrowCommissions'] as List? ?? [];

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'عمولة إحالة' : 'Referral Commission',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '+${revenue.toStringAsFixed(0)} LE',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            date != null ? _formatDate(date.toDate(), isArabic) : 'N/A',
            style: TextStyle(
              fontSize: 14.sp,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          if (borrowCommissions.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              isArabic 
                  ? '+ ${borrowCommissions.length} عمولات استعارة'
                  : '+ ${borrowCommissions.length} borrow commissions',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.infoColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection(bool isArabic, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'كيف يعمل برنامج الإحالة' : 'How Referral Program Works',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
          _buildHowItWorksStep(
            step: '1',
            title: isArabic ? 'شارك كودك' : 'Share Your Code',
            description: isArabic 
                ? 'شارك كود الإحالة مع الأصدقاء والعائلة'
                : 'Share your referral code with friends and family',
            icon: Icons.share,
          ),
          _buildHowItWorksStep(
            step: '2',
            title: isArabic ? 'يسجلون باستخدام الكود' : 'They Register with Code',
            description: isArabic 
                ? 'يستخدم أصدقاؤك الكود عند التسجيل كعضو جديد'
                : 'Your friends use the code during registration as new members',
            icon: Icons.person_add,
          ),
          _buildHowItWorksStep(
            step: '3',
            title: isArabic ? 'تحصل على 20%' : 'You Earn 20%',
            description: isArabic 
                ? 'تحصل على 20% من رسوم العضوية + عمولات الاستعارة لمدة 90 يوماً. يتم دفع الأرباح بعد 90 يوم.'
                : 'You earn 20% of membership fees + borrow commissions for 90 days. Payments are processed after 90 days.',
            icon: Icons.monetization_on,
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep({
    required String step,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Icon(icon, color: AppTheme.primaryColor, size: 20.sp),
          SizedBox(width: 12.w),
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
                  style: TextStyle(fontSize: 14.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBreakdown(bool isArabic, bool isDarkMode) {
    final totalRevenue = _referralStats['totalRevenue'] ?? 0.0;
    final pendingRevenue = _referralStats['pendingRevenue'] ?? 0.0;
    final paidRevenue = _referralStats['paidRevenue'] ?? 0.0;

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
          Text(
            isArabic ? 'تفصيل الأرباح' : 'Revenue Breakdown',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
          _buildRevenueItem(
            title: isArabic ? 'إجمالي الأرباح' : 'Total Revenue',
            amount: totalRevenue,
            color: AppTheme.primaryColor,
            isTotal: true,
          ),
          _buildRevenueItem(
            title: isArabic ? 'الأرباح المدفوعة' : 'Paid Revenue',
            amount: paidRevenue,
            color: AppTheme.successColor,
          ),
          _buildRevenueItem(
            title: isArabic ? 'الأرباح المعلقة' : 'Pending Revenue',
            amount: pendingRevenue,
            color: AppTheme.warningColor,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueItem({
    required String title,
    required double amount,
    required Color color,
    bool isTotal = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isTotal ? 16.sp : 14.sp,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(0)} LE',
            style: TextStyle(
              fontSize: isTotal ? 18.sp : 16.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
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
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _copyReferralCode(String code) {
    if (code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: code));
      Fluttertoast.showToast(
        msg: 'Referral code copied!',
        backgroundColor: AppTheme.successColor,
        textColor: Colors.white,
      );
    }
  }

  void _shareReferralCode(String code, bool isArabic) {
    if (code.isNotEmpty) {
      final message = isArabic
          ? 'انضم إلى Share Station باستخدام كود الإحالة الخاص بي: $code'
          : 'Join Share Station using my referral code: $code';
      
      Share.share(message);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.successColor;
      case 'pending':
        return AppTheme.warningColor;
      case 'rejected':
        return AppTheme.errorColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  Color _getPaymentStatusColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'paid':
        return AppTheme.successColor;
      case 'pending':
        return AppTheme.warningColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _formatDate(DateTime date, bool isArabic) {
    final formatter = DateFormat('MMM dd, yyyy');
    return formatter.format(date);
  }
}