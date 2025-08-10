// lib/presentation/screens/admin/analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedPeriod = '7days';
  bool _isLoading = false;

  // Analytics Data
  Map<String, dynamic> _overviewData = {};
  List<Map<String, dynamic>> _revenueData = [];
  List<Map<String, dynamic>> _userGrowthData = [];
  List<Map<String, dynamic>> _topGames = [];
  List<Map<String, dynamic>> _topContributors = [];
  Map<String, dynamic> _tierDistribution = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadOverviewData(),
        _loadRevenueData(),
        _loadUserGrowthData(),
        _loadTopGames(),
        _loadTopContributors(),
        _loadTierDistribution(),
      ]);
    } catch (e) {
      print('Error loading analytics: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadOverviewData() async {
    // Get total users
    final usersSnapshot = await _firestore.collection('users').get();
    final activeUsers = usersSnapshot.docs
        .where((doc) => doc.data()['status'] == 'active')
        .length;

    // Get total games
    final gamesSnapshot = await _firestore.collection('games').get();

    // Get active borrows
    final borrowsSnapshot = await _firestore
        .collection('active_borrows')
        .where('isReturned', isEqualTo: false)
        .get();

    // Calculate total revenue (simplified)
    double totalRevenue = 0;
    double monthlyRevenue = 0;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      totalRevenue += (data['membershipFee'] ?? 0).toDouble();

      final joinDate = (data['joinDate'] as Timestamp?)?.toDate();
      if (joinDate != null && joinDate.isAfter(startOfMonth)) {
        monthlyRevenue += (data['membershipFee'] ?? 0).toDouble();
      }
    }

    _overviewData = {
      'totalUsers': usersSnapshot.docs.length,
      'activeUsers': activeUsers,
      'totalGames': gamesSnapshot.docs.length,
      'activeBorrows': borrowsSnapshot.docs.length,
      'totalRevenue': totalRevenue,
      'monthlyRevenue': monthlyRevenue,
    };
  }

  Future<void> _loadRevenueData() async {
    // Simplified revenue data for last 7 days
    _revenueData = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      _revenueData.add({
        'date': date,
        'revenue': (100 + (i * 20)).toDouble(), // Mock data
        'borrows': 5 + i,
      });
    }
  }

  Future<void> _loadUserGrowthData() async {
    // Get user growth over time
    final usersSnapshot = await _firestore
        .collection('users')
        .orderBy('joinDate', descending: false)
        .get();

    _userGrowthData = [];
    int cumulativeUsers = 0;

    for (var doc in usersSnapshot.docs) {
      cumulativeUsers++;
      final joinDate = (doc.data()['joinDate'] as Timestamp?)?.toDate();
      if (joinDate != null) {
        _userGrowthData.add({
          'date': joinDate,
          'users': cumulativeUsers,
        });
      }
    }
  }

  Future<void> _loadTopGames() async {
    // Get most borrowed games
    final gamesSnapshot = await _firestore
        .collection('games')
        .limit(5)
        .get();

    _topGames = gamesSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'title': data['title'] ?? 'Unknown',
        'borrows': data['totalBorrows'] ?? 0,
        'revenue': (data['totalRevenue'] ?? 0).toDouble(),
      };
    }).toList();

    // Sort by borrows
    _topGames.sort((a, b) => b['borrows'].compareTo(a['borrows']));
  }

  Future<void> _loadTopContributors() async {
    // Get top contributors by total shares
    final usersSnapshot = await _firestore
        .collection('users')
        .orderBy('totalShares', descending: true)
        .limit(5)
        .get();

    _topContributors = usersSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'name': data['name'] ?? 'Unknown',
        'shares': (data['totalShares'] ?? 0).toDouble(),
        'tier': data['tier'] ?? 'member',
      };
    }).toList();
  }

  Future<void> _loadTierDistribution() async {
    final usersSnapshot = await _firestore.collection('users').get();

    Map<String, int> distribution = {
      'vip': 0,
      'member': 0,
      'client': 0,
      'user': 0,
    };

    for (var doc in usersSnapshot.docs) {
      final tier = doc.data()['tier'] ?? 'member';
      distribution[tier] = (distribution[tier] ?? 0) + 1;
    }

    _tierDistribution = distribution;
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
          isArabic ? 'التحليلات' : 'Analytics',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          // Period Selector
          PopupMenuButton<String>(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _loadAnalytics();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: '7days',
                child: Text(isArabic ? '7 أيام' : '7 Days'),
              ),
              PopupMenuItem(
                value: '30days',
                child: Text(isArabic ? '30 يوم' : '30 Days'),
              ),
              PopupMenuItem(
                value: '90days',
                child: Text(isArabic ? '90 يوم' : '90 Days'),
              ),
              PopupMenuItem(
                value: 'all',
                child: Text(isArabic ? 'الكل' : 'All Time'),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAnalytics,
          ),
        ],
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
              icon: Icon(Icons.trending_up, size: 20.sp),
              text: isArabic ? 'الإيرادات' : 'Revenue',
            ),
            Tab(
              icon: Icon(Icons.people, size: 20.sp),
              text: isArabic ? 'المستخدمون' : 'Users',
            ),
            Tab(
              icon: Icon(FontAwesomeIcons.gamepad, size: 20.sp),
              text: isArabic ? 'الألعاب' : 'Games',
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
          _buildRevenueTab(isArabic, isDarkMode),
          _buildUsersTab(isArabic, isDarkMode),
          _buildGamesTab(isArabic, isDarkMode),
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
          // Key Metrics Grid
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.2,
            children: [
              _buildMetricCard(
                title: isArabic ? 'إجمالي المستخدمين' : 'Total Users',
                value: _overviewData['totalUsers']?.toString() ?? '0',
                icon: Icons.people,
                color: AppTheme.primaryColor,
                isDarkMode: isDarkMode,
              ),
              _buildMetricCard(
                title: isArabic ? 'المستخدمون النشطون' : 'Active Users',
                value: _overviewData['activeUsers']?.toString() ?? '0',
                icon: Icons.person_add,
                color: AppTheme.successColor,
                isDarkMode: isDarkMode,
              ),
              _buildMetricCard(
                title: isArabic ? 'إجمالي الألعاب' : 'Total Games',
                value: _overviewData['totalGames']?.toString() ?? '0',
                icon: FontAwesomeIcons.gamepad,
                color: AppTheme.infoColor,
                isDarkMode: isDarkMode,
              ),
              _buildMetricCard(
                title: isArabic ? 'الاستعارات النشطة' : 'Active Borrows',
                value: _overviewData['activeBorrows']?.toString() ?? '0',
                icon: Icons.book,
                color: AppTheme.warningColor,
                isDarkMode: isDarkMode,
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // Revenue Overview
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
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
                  isArabic ? 'نظرة عامة على الإيرادات' : 'Revenue Overview',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          isArabic ? 'الإيرادات الإجمالية' : 'Total Revenue',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDarkMode ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${_overviewData['totalRevenue']?.toStringAsFixed(0) ?? '0'} LE',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40.h,
                      color: isDarkMode ? Colors.white24 : Colors.black12,
                    ),
                    Column(
                      children: [
                        Text(
                          isArabic ? 'هذا الشهر' : 'This Month',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDarkMode ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${_overviewData['monthlyRevenue']?.toStringAsFixed(0) ?? '0'} LE',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Tier Distribution
          _buildTierDistributionCard(isArabic, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildRevenueTab(bool isArabic, bool isDarkMode) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue Chart
          Container(
            height: 250.h,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
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
                  isArabic ? 'اتجاه الإيرادات' : 'Revenue Trend',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}',
                                style: TextStyle(fontSize: 10.sp),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < _revenueData.length) {
                                final date = _revenueData[value.toInt()]['date'] as DateTime;
                                return Text(
                                  DateFormat('dd/MM').format(date),
                                  style: TextStyle(fontSize: 9.sp),
                                );
                              }
                              return Text('');
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _revenueData.asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble(),
                              entry.value['revenue'].toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          color: AppTheme.primaryColor,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.primaryColor.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Revenue Breakdown
          Text(
            isArabic ? 'تفصيل الإيرادات' : 'Revenue Breakdown',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),

          _buildRevenueItem(
            title: isArabic ? 'رسوم العضوية' : 'Membership Fees',
            amount: 15000,
            percentage: 60,
            color: AppTheme.primaryColor,
            isDarkMode: isDarkMode,
          ),
          _buildRevenueItem(
            title: isArabic ? 'رسوم الاستعارة' : 'Borrowing Fees',
            amount: 7500,
            percentage: 30,
            color: AppTheme.successColor,
            isDarkMode: isDarkMode,
          ),
          _buildRevenueItem(
            title: isArabic ? 'رسوم البيع' : 'Sale Fees',
            amount: 2500,
            percentage: 10,
            color: AppTheme.warningColor,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(bool isArabic, bool isDarkMode) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Growth Chart
          Container(
            height: 250.h,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'نمو المستخدمين' : 'User Growth',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _userGrowthData.take(10).toList().asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble(),
                              entry.value['users'].toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          color: AppTheme.infoColor,
                          barWidth: 3,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.infoColor.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Top Contributors
          Text(
            isArabic ? 'أفضل المساهمين' : 'Top Contributors',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),

          ..._topContributors.map((contributor) => _buildContributorItem(
            name: contributor['name'],
            shares: contributor['shares'],
            tier: contributor['tier'],
            isArabic: isArabic,
            isDarkMode: isDarkMode,
          )),
        ],
      ),
    );
  }

  Widget _buildGamesTab(bool isArabic, bool isDarkMode) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Games
          Text(
            isArabic ? 'أفضل الألعاب' : 'Top Games',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),

          ..._topGames.asMap().entries.map((entry) => _buildGameItem(
            rank: entry.key + 1,
            title: entry.value['title'],
            borrows: entry.value['borrows'],
            revenue: entry.value['revenue'],
            isArabic: isArabic,
            isDarkMode: isDarkMode,
          )),
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
        borderRadius: BorderRadius.circular(16.r),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24.sp),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: color,
                  size: 16.sp,
                ),
              ),
            ],
          ),
          Spacer(),
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
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierDistributionCard(bool isArabic, bool isDarkMode) {
    final total = _tierDistribution.values.fold<int>(0, (sum, count) => sum + (count as int));

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'توزيع المستخدمين' : 'User Distribution',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
          ..._tierDistribution.entries.map((entry) {
            final percentage = total > 0 ? (entry.value / total * 100) : 0;
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key.toUpperCase(),
                        style: TextStyle(fontSize: 12.sp),
                      ),
                      Text(
                        '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(_getTierColor(entry.key)),
                    minHeight: 6.h,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRevenueItem({
    required String title,
    required double amount,
    required double percentage,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Center(
              child: Text(
                '${percentage.toInt()}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
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
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${amount.toStringAsFixed(0)} LE',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributorItem({
    required String name,
    required double shares,
    required String tier,
    required bool isArabic,
    required bool isDarkMode,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: _getTierColor(tier).withOpacity(0.2),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: _getTierColor(tier),
                fontWeight: FontWeight.bold,
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  tier.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: _getTierColor(tier),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${shares.toStringAsFixed(1)} ${isArabic ? "مساهمة" : "shares"}',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameItem({
    required int rank,
    required String title,
    required int borrows,
    required double revenue,
    required bool isArabic,
    required bool isDarkMode,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              color: rank <= 3 ? Colors.amber.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: rank <= 3 ? Colors.amber : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${borrows} ${isArabic ? "استعارة" : "borrows"}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${revenue.toStringAsFixed(0)} LE',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.successColor,
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
}