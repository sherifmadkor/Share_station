// lib/presentation/screens/user/balance_details_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../data/models/user_model.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/balance_service.dart';

class BalanceDetailsScreen extends StatefulWidget {
  const BalanceDetailsScreen({Key? key}) : super(key: key);

  @override
  State<BalanceDetailsScreen> createState() => _BalanceDetailsScreenState();
}

class _BalanceDetailsScreenState extends State<BalanceDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BalanceService _balanceService = BalanceService();

  bool _isLoading = false;
  Map<String, double> _balanceBreakdown = {};
  List<Map<String, dynamic>> _balanceEntries = [];
  List<Map<String, dynamic>> _expiredEntries = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBalanceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBalanceData() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data()!;

      // Calculate balance breakdown
      _balanceBreakdown = {
        'borrowValue': (userData['borrowValue'] ?? 0).toDouble(),
        'sellValue': (userData['sellValue'] ?? 0).toDouble(),
        'refunds': (userData['refunds'] ?? 0).toDouble(),
        'referralEarnings': (userData['referralEarnings'] ?? 0).toDouble(),
        'cashIn': (userData['cashIn'] ?? 0).toDouble(),
      };

      // Get balance entries
      final entries = List<Map<String, dynamic>>.from(
          userData['balanceEntries'] ?? []
      );

      // Separate active and expired entries
      _balanceEntries = entries.where((e) => e['isExpired'] != true).toList();
      _expiredEntries = entries.where((e) => e['isExpired'] == true).toList();
      
      // If referralEarnings exists but no referral balance entries, create synthetic entry
      final referralEarnings = _balanceBreakdown['referralEarnings'] ?? 0.0;
      if (referralEarnings > 0) {
        final hasReferralEntries = _balanceEntries.any((e) => e['type'] == 'referralEarnings');
        if (!hasReferralEntries) {
          // Add synthetic referral earnings entry
          _balanceEntries.insert(0, {
            'id': 'referral_earnings_synthetic',
            'type': 'referralEarnings',
            'amount': referralEarnings,
            'description': 'Referral commission earnings',
            'earnedDate': Timestamp.now(),
            'isExpired': false,
          });
        }
      }

      // Sort by date
      _balanceEntries.sort((a, b) {
        final dateA = (a['earnedDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final dateB = (b['earnedDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      _expiredEntries.sort((a, b) {
        final dateA = (a['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final dateB = (b['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

    } catch (e) {
      print('Error loading balance data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    final user = authProvider.currentUser;
    final isVIP = user?.tier == UserTier.vip;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          isArabic ? 'تفاصيل الرصيد' : 'Balance Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          if (isVIP)
            IconButton(
              icon: Icon(Icons.account_balance_wallet, color: Colors.white),
              onPressed: () => _showWithdrawalDialog(),
              tooltip: isArabic ? 'سحب الرصيد' : 'Withdraw Balance',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: isArabic ? 'نظرة عامة' : 'Overview'),
            Tab(text: isArabic ? 'نشط' : 'Active'),
            Tab(text: isArabic ? 'منتهي' : 'Expired'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(isArabic, isDarkMode, isVIP),
          _buildActiveEntriesTab(isArabic, isDarkMode),
          _buildExpiredEntriesTab(isArabic, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(bool isArabic, bool isDarkMode, bool isVIP) {
    final totalBalance = _balanceBreakdown.values.reduce((a, b) => a + b);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Balance Card
          Container(
            width: double.infinity,
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
                  isArabic ? 'إجمالي الرصيد' : 'Total Balance',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '${totalBalance.toStringAsFixed(2)} LE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isVIP) ...[
                  SizedBox(height: 12.h),
                  ElevatedButton.icon(
                    onPressed: () => _showWithdrawalDialog(),
                    icon: Icon(Icons.arrow_downward, size: 16.sp),
                    label: Text(
                      isArabic ? 'سحب الرصيد' : 'Withdraw',
                      style: TextStyle(fontSize: 14.sp),
                    ),
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
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // Balance Breakdown
          Text(
            isArabic ? 'تفصيل الرصيد' : 'Balance Breakdown',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),

          _buildBreakdownCard(
            title: isArabic ? 'قيمة الاستعارة' : 'Borrow Value',
            subtitle: isArabic ? '70% من قيمة الألعاب المستعارة' : '70% of borrowed games value',
            amount: _balanceBreakdown['borrowValue'] ?? 0,
            icon: FontAwesomeIcons.gamepad,
            color: AppTheme.primaryColor,
            isDarkMode: isDarkMode,
            expires: true,
          ),

          _buildBreakdownCard(
            title: isArabic ? 'قيمة البيع' : 'Sell Value',
            subtitle: isArabic ? '90% من قيمة البيع' : '90% of sale value',
            amount: _balanceBreakdown['sellValue'] ?? 0,
            icon: FontAwesomeIcons.tags,
            color: AppTheme.successColor,
            isDarkMode: isDarkMode,
            expires: true,
          ),

          _buildBreakdownCard(
            title: isArabic ? 'المبالغ المستردة' : 'Refunds',
            subtitle: isArabic ? 'من مساهمات الصندوق' : 'From fund contributions',
            amount: _balanceBreakdown['refunds'] ?? 0,
            icon: FontAwesomeIcons.rotateLeft,
            color: AppTheme.infoColor,
            isDarkMode: isDarkMode,
            expires: true,
          ),

          _buildBreakdownCard(
            title: isArabic ? 'أرباح الإحالة' : 'Referral Earnings',
            subtitle: isArabic ? '20% من رسوم المحالين' : '20% of referred users fees',
            amount: _balanceBreakdown['referralEarnings'] ?? 0,
            icon: FontAwesomeIcons.userGroup,
            color: AppTheme.warningColor,
            isDarkMode: isDarkMode,
            expires: true,
          ),

          _buildBreakdownCard(
            title: isArabic ? 'الإيداع النقدي' : 'Cash In',
            subtitle: isArabic ? 'لا تنتهي صلاحيته' : 'Never expires',
            amount: _balanceBreakdown['cashIn'] ?? 0,
            icon: FontAwesomeIcons.moneyBillWave,
            color: AppTheme.secondaryColor,
            isDarkMode: isDarkMode,
            expires: false,
          ),

          SizedBox(height: 20.h),

          // Warning Card
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppTheme.warningColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.warningColor,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'جميع الأرصدة (باستثناء الإيداع النقدي) تنتهي بعد 90 يومًا'
                        : 'All balances (except Cash In) expire after 90 days',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveEntriesTab(bool isArabic, bool isDarkMode) {
    if (_balanceEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64.sp,
              color: Colors.grey,
            ),
            SizedBox(height: 16.h),
            Text(
              isArabic ? 'لا توجد أرصدة نشطة' : 'No active balance entries',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _balanceEntries.length,
      itemBuilder: (context, index) {
        final entry = _balanceEntries[index];
        return _buildBalanceEntryCard(entry, isArabic, isDarkMode);
      },
    );
  }

  Widget _buildExpiredEntriesTab(bool isArabic, bool isDarkMode) {
    if (_expiredEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer_off,
              size: 64.sp,
              color: Colors.grey,
            ),
            SizedBox(height: 16.h),
            Text(
              isArabic ? 'لا توجد أرصدة منتهية' : 'No expired balance entries',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _expiredEntries.length,
      itemBuilder: (context, index) {
        final entry = _expiredEntries[index];
        return _buildBalanceEntryCard(entry, isArabic, isDarkMode, isExpired: true);
      },
    );
  }

  Widget _buildBreakdownCard({
    required String title,
    required String subtitle,
    required double amount,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
    required bool expires,
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
              borderRadius: BorderRadius.circular(10.r),
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
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${amount.toStringAsFixed(2)} LE',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (expires)
                Text(
                  'Expires',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.orange,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceEntryCard(
      Map<String, dynamic> entry,
      bool isArabic,
      bool isDarkMode, {
        bool isExpired = false,
      }) {
    final amount = (entry['amount'] ?? 0).toDouble();
    final type = entry['type'] ?? 'unknown';
    final description = entry['description'] ?? '';
    final earnedDate = (entry['earnedDate'] as Timestamp?)?.toDate();
    final expiryDate = (entry['expiryDate'] as Timestamp?)?.toDate();

    IconData icon;
    Color color;

    switch (type) {
      case 'borrowValue':
        icon = FontAwesomeIcons.gamepad;
        color = AppTheme.primaryColor;
        break;
      case 'sellValue':
        icon = FontAwesomeIcons.tags;
        color = AppTheme.successColor;
        break;
      case 'refunds':
        icon = FontAwesomeIcons.rotateLeft;
        color = AppTheme.infoColor;
        break;
      case 'referralEarnings':
        icon = FontAwesomeIcons.userGroup;
        color = AppTheme.warningColor;
        break;
      case 'cashIn':
        icon = FontAwesomeIcons.moneyBillWave;
        color = AppTheme.secondaryColor;
        break;
      default:
        icon = Icons.account_balance_wallet;
        color = Colors.grey;
    }

    if (isExpired) {
      color = Colors.grey;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: isExpired
            ? Border.all(color: Colors.grey.withOpacity(0.3))
            : null,
        boxShadow: !isExpired
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        decoration: isExpired ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (earnedDate != null)
                      Text(
                        DateFormat('dd MMM yyyy').format(earnedDate),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isDarkMode ? Colors.white60 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${amount.toStringAsFixed(2)} LE',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isExpired ? Colors.grey : color,
                  decoration: isExpired ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          if (expiryDate != null && !isExpired) ...[
            SizedBox(height: 8.h),
            _buildExpiryIndicator(expiryDate, isArabic),
          ],
        ],
      ),
    );
  }

  Widget _buildExpiryIndicator(DateTime expiryDate, bool isArabic) {
    final now = DateTime.now();
    final daysRemaining = expiryDate.difference(now).inDays;

    Color color;
    IconData icon;
    String text;

    if (daysRemaining <= 7) {
      color = AppTheme.errorColor;
      icon = Icons.warning;
      text = isArabic
          ? 'ينتهي خلال $daysRemaining أيام'
          : 'Expires in $daysRemaining days';
    } else if (daysRemaining <= 30) {
      color = AppTheme.warningColor;
      icon = Icons.timer;
      text = isArabic
          ? 'ينتهي خلال $daysRemaining يوم'
          : 'Expires in $daysRemaining days';
    } else {
      color = AppTheme.successColor;
      icon = Icons.check_circle;
      text = isArabic
          ? 'صالح لمدة $daysRemaining يوم'
          : 'Valid for $daysRemaining days';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14.sp),
          SizedBox(width: 4.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.sp,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showWithdrawalDialog() {
    final appProvider = context.read<AppProvider>();
    final isArabic = appProvider.isArabic;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'سحب الرصيد' : 'Withdraw Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic
                  ? 'كعضو VIP، يمكنك سحب رصيدك مع رسوم 20%'
                  : 'As a VIP member, you can withdraw your balance with a 20% fee',
            ),
            SizedBox(height: 16.h),
            TextField(
              decoration: InputDecoration(
                labelText: isArabic ? 'المبلغ' : 'Amount',
                border: OutlineInputBorder(),
                suffixText: 'LE',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement withdrawal
              Navigator.pop(context);
              Fluttertoast.showToast(
                msg: 'Withdrawal request submitted',
                backgroundColor: AppTheme.successColor,
              );
            },
            child: Text(isArabic ? 'سحب' : 'Withdraw'),
          ),
        ],
      ),
    );
  }
}