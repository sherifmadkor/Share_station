// lib/presentation/screens/admin/admin_referral_management.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/referral_service.dart';

class AdminReferralManagement extends StatefulWidget {
  const AdminReferralManagement({Key? key}) : super(key: key);

  @override
  State<AdminReferralManagement> createState() => _AdminReferralManagementState();
}

class _AdminReferralManagementState extends State<AdminReferralManagement> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  final ReferralService _referralService = ReferralService();
  
  bool _isLoading = true;
  Map<String, dynamic> _adminStats = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAdminReferralData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminReferralData() async {
    setState(() => _isLoading = true);
    
    try {
      final stats = await _referralService.getAdminReferralStats();
      setState(() {
        _adminStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading admin referral data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.locale.languageCode == 'ar';
    final isDarkMode = appProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          isArabic ? 'إدارة الإحالات' : 'Referral Management',
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
            onPressed: _loadAdminReferralData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: isArabic ? 'نظرة عامة' : 'Overview',
              icon: Icon(Icons.dashboard, size: 20.sp),
            ),
            Tab(
              text: isArabic ? 'التحليلات' : 'Analytics',
              icon: Icon(Icons.analytics, size: 20.sp),
            ),
            Tab(
              text: isArabic ? 'أهم المحيلين' : 'Top Referrers',
              icon: Icon(FontAwesomeIcons.trophy, size: 18.sp),
            ),
            Tab(
              text: isArabic ? 'الإدارة' : 'Management',
              icon: Icon(Icons.settings, size: 20.sp),
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
                _buildAnalyticsTab(isArabic, isDarkMode),
                _buildTopReferrersTab(isArabic, isDarkMode),
                _buildManagementTab(isArabic, isDarkMode),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(bool isArabic, bool isDarkMode) {
    final totalReferrals = _adminStats['totalReferrals'] ?? 0;
    final totalRevenue = _adminStats['totalReferralRevenue'] ?? 0.0;
    final pendingRevenue = _adminStats['pendingReferralRevenue'] ?? 0.0;
    final paidRevenue = _adminStats['paidReferralRevenue'] ?? 0.0;
    final adminShare = _adminStats['adminRevenueShare'] ?? 0.0;

    return RefreshIndicator(
      onRefresh: _loadAdminReferralData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key Metrics Cards
            Text(
              isArabic ? 'المقاييس الرئيسية' : 'Key Metrics',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),

            // First Row - Total Stats
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: isArabic ? 'إجمالي الإحالات' : 'Total Referrals',
                    value: totalReferrals.toString(),
                    icon: FontAwesomeIcons.users,
                    color: AppTheme.primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildMetricCard(
                    title: isArabic ? 'إجمالي الإيرادات' : 'Total Revenue',
                    value: '${totalRevenue.toStringAsFixed(0)} LE',
                    icon: FontAwesomeIcons.chartLine,
                    color: AppTheme.successColor,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Second Row - Revenue Breakdown
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: isArabic ? 'الإيرادات المعلقة' : 'Pending Revenue',
                    value: '${pendingRevenue.toStringAsFixed(0)} LE',
                    icon: FontAwesomeIcons.clock,
                    color: AppTheme.warningColor,
                    isDarkMode: isDarkMode,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildMetricCard(
                    title: isArabic ? 'الإيرادات المدفوعة' : 'Paid Revenue',
                    value: '${paidRevenue.toStringAsFixed(0)} LE',
                    icon: FontAwesomeIcons.checkCircle,
                    color: AppTheme.infoColor,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Admin Revenue Share
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple,
                    Colors.purple.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    FontAwesomeIcons.crown,
                    color: Colors.white,
                    size: 32.sp,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    isArabic ? 'حصة الإدارة من الإحالات' : 'Admin Referral Share',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${adminShare.toStringAsFixed(0)} LE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    isArabic 
                        ? 'من إجمالي ${paidRevenue.toStringAsFixed(0)} ج.م'
                        : 'from total ${paidRevenue.toStringAsFixed(0)} LE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
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
            SizedBox(height: 16.h),

            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    title: isArabic ? 'معالجة الأرباح المعلقة' : 'Process Pending',
                    subtitle: isArabic ? 'معالجة الأرباح المستحقة' : 'Process due revenues',
                    icon: FontAwesomeIcons.play,
                    color: AppTheme.warningColor,
                    onTap: _processPendingRevenues,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildActionButton(
                    title: isArabic ? 'تقرير شهري' : 'Monthly Report',
                    subtitle: isArabic ? 'تصدير التقرير' : 'Export report',
                    icon: FontAwesomeIcons.fileExport,
                    color: AppTheme.infoColor,
                    onTap: _exportMonthlyReport,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab(bool isArabic, bool isDarkMode) {
    final referralsByMonth = _adminStats['referralsByMonth'] as Map<String, int>? ?? {};
    final revenueByMonth = _adminStats['revenueByMonth'] as Map<String, double>? ?? {};

    return RefreshIndicator(
      onRefresh: _loadAdminReferralData,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? 'تحليل الإحالات الشهري' : 'Monthly Referrals Analysis',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),

            // Referrals Chart
            Container(
              height: 300.h,
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
              child: _buildReferralsChart(referralsByMonth, isArabic),
            ),

            SizedBox(height: 24.h),

            Text(
              isArabic ? 'تحليل الإيرادات الشهرية' : 'Monthly Revenue Analysis',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),

            // Revenue Chart
            Container(
              height: 300.h,
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
              child: _buildRevenueChart(revenueByMonth, isArabic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopReferrersTab(bool isArabic, bool isDarkMode) {
    // This would be populated from a real query in production
    final topReferrers = <Map<String, dynamic>>[];

    return RefreshIndicator(
      onRefresh: _loadAdminReferralData,
      child: topReferrers.isEmpty
          ? _buildEmptyState(
              isArabic ? 'لا يوجد محيلون بعد' : 'No Referrers Yet',
              isArabic ? 'ستظهر قائمة أهم المحيلين هنا' : 'Top referrers will appear here',
              FontAwesomeIcons.trophy,
            )
          : ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: topReferrers.length,
              itemBuilder: (context, index) {
                final referrer = topReferrers[index];
                return _buildReferrerItem(referrer, index + 1, isArabic, isDarkMode);
              },
            ),
    );
  }

  Widget _buildManagementTab(bool isArabic, bool isDarkMode) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'إعدادات الإحالة' : 'Referral Settings',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),

          // System Settings
          _buildSettingsCard(
            title: isArabic ? 'معدل العمولة' : 'Commission Rate',
            subtitle: isArabic ? 'نسبة عمولة الإحالة الحالية' : 'Current referral commission rate',
            value: '20%',
            icon: Icons.percent,
            isDarkMode: isDarkMode,
          ),

          _buildSettingsCard(
            title: isArabic ? 'فترة الإيرادات' : 'Revenue Period',
            subtitle: isArabic ? 'فترة استحقاق إيرادات الإحالة' : 'Referral revenue eligibility period',
            value: '90 days',
            icon: Icons.calendar_today,
            isDarkMode: isDarkMode,
          ),

          _buildSettingsCard(
            title: isArabic ? 'فترة انتهاء الأرباح' : 'Earnings Expiry',
            subtitle: isArabic ? 'فترة انتهاء صلاحية الأرباح' : 'Earnings expiration period',
            value: '90 days',
            icon: Icons.timer,
            isDarkMode: isDarkMode,
          ),

          SizedBox(height: 24.h),

          // Management Actions
          Text(
            isArabic ? 'إجراءات الإدارة' : 'Management Actions',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),

          _buildManagementAction(
            title: isArabic ? 'تهيئة أكواد الإحالة' : 'Initialize Referral Codes',
            subtitle: isArabic ? 'إنشاء أكواد إحالة للمستخدمين الحاليين' : 'Generate referral codes for existing users',
            icon: FontAwesomeIcons.qrcode,
            color: AppTheme.primaryColor,
            onTap: _initializeReferralCodes,
          ),

          _buildManagementAction(
            title: isArabic ? 'معالجة الإيرادات المنتهية الصلاحية' : 'Process Expired Revenues',
            subtitle: isArabic ? 'معالجة الإيرادات المستحقة تلقائياً' : 'Automatically process due revenues',
            icon: FontAwesomeIcons.clockRotateLeft,
            color: AppTheme.warningColor,
            onTap: _processExpiredRevenues,
          ),

          _buildManagementAction(
            title: isArabic ? 'تحديث حصة الإدارة' : 'Update Admin Share',
            subtitle: isArabic ? 'تحديث حصة الإدارة من إيرادات الإحالة' : 'Update admin share from referral revenues',
            icon: FontAwesomeIcons.crown,
            color: Colors.purple,
            onTap: _updateAdminShare,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
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

  Widget _buildActionButton({
    required String title,
    required String subtitle,
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
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(height: 12.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
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
      ),
    );
  }

  Widget _buildReferralsChart(Map<String, int> data, bool isArabic) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          isArabic ? 'لا توجد بيانات لعرضها' : 'No data to display',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: data.entries.map((e) {
              final monthIndex = data.keys.toList().indexOf(e.key);
              return FlSpot(monthIndex.toDouble(), e.value.toDouble());
            }).toList(),
            isCurved: true,
            color: AppTheme.primaryColor,
            barWidth: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(Map<String, double> data, bool isArabic) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          isArabic ? 'لا توجد بيانات لعرضها' : 'No data to display',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: data.entries.map((e) {
              final monthIndex = data.keys.toList().indexOf(e.key);
              return FlSpot(monthIndex.toDouble(), e.value);
            }).toList(),
            isCurved: true,
            color: AppTheme.successColor,
            barWidth: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildReferrerItem(Map<String, dynamic> referrer, int rank, bool isArabic, bool isDarkMode) {
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
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: _getRankColor(rank),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  referrer['userName'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ID: ${referrer['memberId']}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${referrer['totalReferrals']} ${isArabic ? "إحالة" : "referrals"}',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              Text(
                '${referrer['totalEarnings']} LE',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
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
          Icon(icon, color: AppTheme.primaryColor, size: 24.sp),
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
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Provider.of<AppProvider>(context).isDarkMode;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, color: color, size: 24.sp),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14.sp,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
        trailing: Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        tileColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
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

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.orange[300]!;
      default:
        return AppTheme.primaryColor;
    }
  }

  void _processPendingRevenues() async {
    // Show loading and process pending revenues
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16.w),
            Text('Processing pending revenues...'),
          ],
        ),
      ),
    );

    await _referralService.processExpiredReferralRevenues();
    Navigator.pop(context);
    _loadAdminReferralData();
  }

  void _exportMonthlyReport() {
    // Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export functionality - Coming Soon')),
    );
  }

  void _initializeReferralCodes() {
    // Implement referral code initialization
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Referral codes initialization - Coming Soon')),
    );
  }

  void _processExpiredRevenues() async {
    await _referralService.processExpiredReferralRevenues();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Expired revenues processed successfully')),
    );
    _loadAdminReferralData();
  }

  void _updateAdminShare() {
    // Implement admin share update
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Admin share update - Coming Soon')),
    );
  }
}