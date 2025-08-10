// lib/presentation/screens/user/net_metrics_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class NetMetricsDashboardScreen extends StatefulWidget {
  const NetMetricsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<NetMetricsDashboardScreen> createState() => _NetMetricsDashboardScreenState();
}

class _NetMetricsDashboardScreenState extends State<NetMetricsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String _selectedPeriod = '30'; // '7', '30', '90', 'all'

  // Metrics data
  double _netLendingValue = 0;
  double _netBorrowingValue = 0;
  double _netExchangeValue = 0;
  double _averageHoldPeriod = 0;
  int _totalTransactions = 0;

  // Chart data
  List<FlSpot> _lendingTrend = [];
  List<FlSpot> _borrowingTrend = [];
  List<FlSpot> _exchangeTrend = [];

  // Breakdown data
  Map<String, double> _lendingBreakdown = {};
  Map<String, double> _borrowingBreakdown = {};
  Map<String, int> _transactionCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadMetrics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final periodDays = _selectedPeriod == 'all' ? 365 * 10 : int.parse(_selectedPeriod);
      final startDate = now.subtract(Duration(days: periodDays));

      // Get user's lending data (games they've lent out)
      final lendingQuery = await _firestore
          .collection('borrows')
          .where('ownerId', isEqualTo: user.uid)
          .where('borrowDate', isGreaterThan: Timestamp.fromDate(startDate))
          .get();

      double totalLending = 0;
      int lendingCount = 0;
      double totalHoldDays = 0;

      for (var doc in lendingQuery.docs) {
        final data = doc.data();
        totalLending += (data['borrowValue'] ?? 0).toDouble();
        lendingCount++;

        if (data['returnDate'] != null) {
          final borrowDate = (data['borrowDate'] as Timestamp).toDate();
          final returnDate = (data['returnDate'] as Timestamp).toDate();
          totalHoldDays += returnDate.difference(borrowDate).inDays.toDouble();
        }
      }

      // Get user's borrowing data
      final borrowingQuery = await _firestore
          .collection('borrows')
          .where('borrowerId', isEqualTo: user.uid)
          .where('borrowDate', isGreaterThan: Timestamp.fromDate(startDate))
          .get();

      double totalBorrowing = 0;
      int borrowingCount = 0;

      for (var doc in borrowingQuery.docs) {
        final data = doc.data();
        totalBorrowing += (data['borrowValue'] ?? 0).toDouble();
        borrowingCount++;
      }

      // Get exchange data (sales and purchases)
      final salesQuery = await _firestore
          .collection('transactions')
          .where('sellerId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'sale')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startDate))
          .get();

      double totalSales = 0;
      for (var doc in salesQuery.docs) {
        totalSales += (doc.data()['amount'] ?? 0).toDouble();
      }

      final purchasesQuery = await _firestore
          .collection('transactions')
          .where('buyerId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'purchase')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startDate))
          .get();

      double totalPurchases = 0;
      for (var doc in purchasesQuery.docs) {
        totalPurchases += (doc.data()['amount'] ?? 0).toDouble();
      }

      // Calculate metrics
      setState(() {
        _netLendingValue = totalLending;
        _netBorrowingValue = totalBorrowing;
        _netExchangeValue = totalSales - totalPurchases;
        _totalTransactions = lendingCount + borrowingCount + salesQuery.docs.length + purchasesQuery.docs.length;
        _averageHoldPeriod = lendingCount > 0 ? totalHoldDays / lendingCount : 0;

        // Generate trend data
        _generateTrendData(startDate, now);

        // Calculate breakdowns
        _lendingBreakdown = {
          'Free Borrows': totalLending * 0.3, // Example calculation
          'Paid Borrows': totalLending * 0.7,
        };

        _borrowingBreakdown = {
          'Free': totalBorrowing * 0.2,
          'Paid': totalBorrowing * 0.8,
        };

        _transactionCounts = {
          'Lending': lendingCount,
          'Borrowing': borrowingCount,
          'Sales': salesQuery.docs.length,
          'Purchases': purchasesQuery.docs.length,
        };
      });

    } catch (e) {
      _showError('Failed to load metrics');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _generateTrendData(DateTime startDate, DateTime endDate) {
    // Generate sample trend data points
    _lendingTrend = [];
    _borrowingTrend = [];
    _exchangeTrend = [];

    final days = endDate.difference(startDate).inDays;
    final interval = days > 30 ? 7 : 1; // Weekly for long periods, daily for short

    for (int i = 0; i <= days; i += interval) {
      final x = i.toDouble();
      _lendingTrend.add(FlSpot(x, 100 + (i * 2) + (i % 10 * 5).toDouble()));
      _borrowingTrend.add(FlSpot(x, 80 + (i * 1.5) + (i % 7 * 3).toDouble()));
      _exchangeTrend.add(FlSpot(x, 50 + (i * 0.8) + (i % 5 * 2).toDouble()));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.locale.languageCode == 'ar';
    final isDarkMode = appProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic ? 'لوحة المقاييس الصافية' : 'Net Metrics Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.date_range),
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _loadMetrics();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: '7',
                child: Text(isArabic ? '7 أيام' : '7 Days'),
              ),
              PopupMenuItem(
                value: '30',
                child: Text(isArabic ? '30 يوم' : '30 Days'),
              ),
              PopupMenuItem(
                value: '90',
                child: Text(isArabic ? '90 يوم' : '90 Days'),
              ),
              PopupMenuItem(
                value: 'all',
                child: Text(isArabic ? 'كل الوقت' : 'All Time'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Tabs
          Container(
            color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: isArabic ? 'نظرة عامة' : 'Overview'),
                Tab(text: isArabic ? 'الإقراض' : 'Lending'),
                Tab(text: isArabic ? 'الاقتراض' : 'Borrowing'),
                Tab(text: isArabic ? 'التبادل' : 'Exchange'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(isArabic, isDarkMode),
                _buildLendingTab(isArabic, isDarkMode),
                _buildBorrowingTab(isArabic, isDarkMode),
                _buildExchangeTab(isArabic, isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(bool isArabic, bool isDarkMode) {
    return RefreshIndicator(
      onRefresh: _loadMetrics,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key Metrics Grid
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              children: [
                _buildMetricCard(
                  title: isArabic ? 'صافي الإقراض' : 'Net Lending',
                  value: _netLendingValue,
                  icon: FontAwesomeIcons.handHoldingDollar,
                  color: Colors.green,
                  isArabic: isArabic,
                  isDarkMode: isDarkMode,
                ),
                _buildMetricCard(
                  title: isArabic ? 'صافي الاقتراض' : 'Net Borrowing',
                  value: _netBorrowingValue,
                  icon: FontAwesomeIcons.handHolding,
                  color: Colors.blue,
                  isArabic: isArabic,
                  isDarkMode: isDarkMode,
                ),
                _buildMetricCard(
                  title: isArabic ? 'صافي التبادل' : 'Net Exchange',
                  value: _netExchangeValue,
                  icon: FontAwesomeIcons.arrowRightArrowLeft,
                  color: _netExchangeValue >= 0 ? Colors.green : Colors.red,
                  isArabic: isArabic,
                  isDarkMode: isDarkMode,
                ),
                _buildMetricCard(
                  title: isArabic ? 'متوسط الاحتفاظ' : 'Avg Hold',
                  value: _averageHoldPeriod,
                  icon: FontAwesomeIcons.clock,
                  color: Colors.orange,
                  suffix: isArabic ? ' يوم' : ' days',
                  isArabic: isArabic,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Transaction Summary
            _buildSectionTitle(isArabic ? 'ملخص المعاملات' : 'Transaction Summary', isArabic),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(15.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _totalTransactions.toString(),
                        style: TextStyle(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        isArabic ? 'إجمالي المعاملات' : 'Total Transactions',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  ..._transactionCounts.entries.map((entry) {
                    return _buildTransactionRow(
                      entry.key,
                      entry.value,
                      _totalTransactions,
                      isArabic,
                      isDarkMode,
                    );
                  }).toList(),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Trend Chart
            _buildSectionTitle(isArabic ? 'اتجاه النشاط' : 'Activity Trend', isArabic),
            SizedBox(height: 12.h),
            Container(
              height: 200.h,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(15.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _lendingTrend,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: _borrowingTrend,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: _exchangeTrend,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLendingTab(bool isArabic, bool isDarkMode) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lending Value Card
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green, Colors.green.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.handHoldingDollar,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      isArabic ? 'إجمالي قيمة الإقراض' : 'Total Lending Value',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Text(
                  '${_netLendingValue.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'LE'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Lending Breakdown
          _buildSectionTitle(isArabic ? 'تفاصيل الإقراض' : 'Lending Breakdown', isArabic),
          SizedBox(height: 12.h),
          ..._lendingBreakdown.entries.map((entry) {
            return _buildBreakdownItem(
              entry.key,
              entry.value,
              _netLendingValue,
              Colors.green,
              isArabic,
              isDarkMode,
            );
          }).toList(),

          SizedBox(height: 24.h),

          // Top Borrowed Games
          _buildSectionTitle(isArabic ? 'الألعاب الأكثر إقراضاً' : 'Most Lent Games', isArabic),
          SizedBox(height: 12.h),
          _buildGamesList(isArabic, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildBorrowingTab(bool isArabic, bool isDarkMode) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Borrowing Value Card
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.blue.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.handHolding,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      isArabic ? 'إجمالي قيمة الاقتراض' : 'Total Borrowing Value',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Text(
                  '${_netBorrowingValue.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'LE'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Borrowing Breakdown
          _buildSectionTitle(isArabic ? 'تفاصيل الاقتراض' : 'Borrowing Breakdown', isArabic),
          SizedBox(height: 12.h),
          ..._borrowingBreakdown.entries.map((entry) {
            return _buildBreakdownItem(
              entry.key,
              entry.value,
              _netBorrowingValue,
              Colors.blue,
              isArabic,
              isDarkMode,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildExchangeTab(bool isArabic, bool isDarkMode) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exchange Value Card
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _netExchangeValue >= 0
                    ? [Colors.green, Colors.green.shade700]
                    : [Colors.red, Colors.red.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.arrowRightArrowLeft,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      isArabic ? 'صافي التبادل' : 'Net Exchange',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Text(
                  '${_netExchangeValue >= 0 ? '+' : ''}${_netExchangeValue.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'LE'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  _netExchangeValue >= 0
                      ? (isArabic ? 'ربح صافي' : 'Net Profit')
                      : (isArabic ? 'خسارة صافية' : 'Net Loss'),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
    String suffix = '',
    required bool isArabic,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FaIcon(
                icon,
                color: color,
                size: 20.sp,
              ),
              if (value > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '+${((value / (_netLendingValue + _netBorrowingValue)) * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey,
            ),
          ),
          Text(
            '${value.toStringAsFixed(suffix.isEmpty ? 0 : 1)}$suffix',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isArabic) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18.sp,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTransactionRow(
      String type,
      int count,
      int total,
      bool isArabic,
      bool isDarkMode,
      ) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              type,
              style: TextStyle(fontSize: 14.sp),
            ),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                _getTypeColor(type),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(
      String label,
      double value,
      double total,
      Color color,
      bool isArabic,
      bool isDarkMode,
      ) {
    final percentage = total > 0 ? (value / total) : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14.sp),
              ),
              Text(
                '${value.toStringAsFixed(0)} ${isArabic ? 'ج.م' : 'LE'}',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8.h,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGamesList(bool isArabic, bool isDarkMode) {
    // Placeholder for top games list
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: List.generate(3, (index) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.1),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text('Game ${index + 1}'),
            subtitle: Text('${10 - index * 2} times'),
            trailing: Text(
              '${(100 - index * 20)} ${isArabic ? 'ج.م' : 'LE'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          );
        }),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Lending':
        return Colors.green;
      case 'Borrowing':
        return Colors.blue;
      case 'Sales':
        return Colors.orange;
      case 'Purchases':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}