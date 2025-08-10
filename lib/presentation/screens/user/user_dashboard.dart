// lib/presentation/screens/user/user_dashboard.dart - FIXED VERSION
// Fixed type casting issues for int/double

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

// Import all screens that need to be linked
import '../../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../user/points_redemption_screen.dart';
import '../user/my_contributions_screen.dart';
import '../user/add_contribution_screen.dart';
// Import new screens once created
// import '../user/balance_details_screen.dart';
// import '../user/queue_management_screen.dart';
// import '../user/sell_game_screen.dart';
// import '../user/referral_dashboard_screen.dart';

class EnhancedUserDashboard extends StatefulWidget {
  const EnhancedUserDashboard({Key? key}) : super(key: key);

  @override
  State<EnhancedUserDashboard> createState() => _EnhancedUserDashboardState();
}

class _EnhancedUserDashboardState extends State<EnhancedUserDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Text(isArabic ? 'الرجاء تسجيل الدخول' : 'Please login'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(currentUser.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData == null) {
            return Center(child: Text('Error loading data'));
          }

          // Extract all metrics with proper type handling
          final totalBalance = _calculateTotalBalance(userData);
          // Fix: Ensure points is treated as int
          final points = (userData['points'] ?? 0).toInt();
          final stationLimit = (userData['stationLimit'] ?? 0).toDouble();
          final remainingStationLimit = (userData['remainingStationLimit'] ?? stationLimit).toDouble();
          final gameShares = (userData['gameShares'] ?? 0).toDouble();
          final fundShares = (userData['fundShares'] ?? 0).toDouble();
          final totalShares = (userData['totalShares'] ?? 0).toDouble();
          final referralEarnings = (userData['referralEarnings'] ?? 0).toDouble();
          final coolDownEndDate = userData['coolDownEndDate'] as Timestamp?;
          final tier = userData['tier'] ?? 'member';

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: CustomScrollView(
              slivers: [
                // Custom App Bar
                SliverAppBar(
                  expandedHeight: 200.h,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppTheme.primaryColor,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      userData['name'] ?? 'User',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(20.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Tier Badge
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: _getTierColor(tier),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Text(
                                tier.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              'Member ID: ${userData['memberId'] ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Main Content
                SliverPadding(
                  padding: EdgeInsets.all(16.w),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Quick Stats Row
                      _buildQuickStatsRow(
                        totalBalance: totalBalance,
                        points: points,
                        stationLimit: stationLimit,
                        remainingStationLimit: remainingStationLimit,
                        isArabic: isArabic,
                        isDarkMode: isDarkMode,
                      ),

                      SizedBox(height: 20.h),

                      // Primary Action Cards
                      _buildPrimaryActionCards(
                        userData: userData,
                        totalShares: totalShares,
                        referralEarnings: referralEarnings,
                        isArabic: isArabic,
                        isDarkMode: isDarkMode,
                      ),

                      SizedBox(height: 20.h),

                      // Contribution Stats
                      _buildContributionStats(
                        gameShares: gameShares,
                        fundShares: fundShares,
                        totalShares: totalShares,
                        isArabic: isArabic,
                        isDarkMode: isDarkMode,
                      ),

                      SizedBox(height: 20.h),

                      // Additional Features
                      _buildAdditionalFeatures(
                        referralEarnings: referralEarnings,
                        coolDownEndDate: coolDownEndDate,
                        tier: tier,
                        isArabic: isArabic,
                        isDarkMode: isDarkMode,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStatsRow({
    required double totalBalance,
    required int points, // Fixed: Now properly typed as int
    required double stationLimit,
    required double remainingStationLimit,
    required bool isArabic,
    required bool isDarkMode,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: isArabic ? 'الرصيد' : 'Balance',
            value: '${totalBalance.toStringAsFixed(0)} LE',
            icon: FontAwesomeIcons.wallet,
            color: AppTheme.successColor,
            isDarkMode: isDarkMode,
            onTap: () {
              // Navigate to Balance Details Screen
              _navigateToBalanceDetails();
            },
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildStatCard(
            title: isArabic ? 'النقاط' : 'Points',
            value: points.toString(), // Now safely using int
            icon: FontAwesomeIcons.coins,
            color: AppTheme.warningColor,
            isDarkMode: isDarkMode,
            onTap: () {
              // Navigate to Points Redemption
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PointsRedemptionScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActionCards({
    required Map<String, dynamic> userData,
    required double totalShares,
    required double referralEarnings,
    required bool isArabic,
    required bool isDarkMode,
  }) {
    // Safely convert totalShares to int for display
    final totalSharesInt = totalShares.toInt();

    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12.w,
      mainAxisSpacing: 12.h,
      childAspectRatio: 1.3,
      children: [
        _buildActionCard(
          title: isArabic ? 'مساهماتي' : 'My Contributions',
          subtitle: '$totalSharesInt shares', // Fixed: Using int for display
          icon: FontAwesomeIcons.handHoldingDollar,
          color: AppTheme.primaryColor,
          isDarkMode: isDarkMode,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MyContributionsScreen(),
              ),
            );
          },
        ),
        _buildActionCard(
          title: isArabic ? 'بيع لعبة' : 'Sell Game',
          subtitle: isArabic ? 'بيع مساهماتك' : 'Sell your contributions',
          icon: FontAwesomeIcons.tags,
          color: AppTheme.errorColor,
          isDarkMode: isDarkMode,
          onTap: () {
            _navigateToSellGame();
          },
        ),
        _buildActionCard(
          title: isArabic ? 'قوائم الانتظار' : 'My Queues',
          subtitle: isArabic ? 'إدارة الطلبات' : 'Manage requests',
          icon: FontAwesomeIcons.listCheck,
          color: AppTheme.infoColor,
          isDarkMode: isDarkMode,
          onTap: () {
            _navigateToQueueManagement();
          },
        ),
        _buildActionCard(
          title: isArabic ? 'الإحالات' : 'Referrals',
          subtitle: '${referralEarnings.toStringAsFixed(0)} LE earned',
          icon: FontAwesomeIcons.userGroup,
          color: AppTheme.secondaryColor,
          isDarkMode: isDarkMode,
          onTap: () {
            _navigateToReferralDashboard();
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
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
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(height: 8.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                color: isDarkMode ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.8),
              color,
            ],
          ),
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: 28.sp),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionStats({
    required double gameShares,
    required double fundShares,
    required double totalShares,
    required bool isArabic,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'إحصائيات المساهمات' : 'Contribution Stats',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddContributionScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildProgressRow(
            label: isArabic ? 'مساهمات الألعاب' : 'Game Shares',
            value: gameShares.toStringAsFixed(1), // Show decimal for half shares
            maxValue: 15,
            currentValue: gameShares,
            color: AppTheme.primaryColor,
          ),
          SizedBox(height: 8.h),
          _buildProgressRow(
            label: isArabic ? 'مساهمات الصندوق' : 'Fund Shares',
            value: fundShares.toStringAsFixed(0),
            maxValue: 5,
            currentValue: fundShares,
            color: AppTheme.secondaryColor,
          ),
          SizedBox(height: 8.h),
          _buildProgressRow(
            label: isArabic ? 'إجمالي المساهمات' : 'Total Shares',
            value: totalShares.toStringAsFixed(1),
            maxValue: 20,
            currentValue: totalShares,
            color: AppTheme.successColor,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required String value,
    required double maxValue,
    required double currentValue,
    required Color color,
  }) {
    double progress = (currentValue / maxValue).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12.sp),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 4.h,
        ),
      ],
    );
  }

  Widget _buildAdditionalFeatures({
    required double referralEarnings,
    required Timestamp? coolDownEndDate,
    required String tier,
    required bool isArabic,
    required bool isDarkMode,
  }) {
    return Column(
      children: [
        // Cooldown Timer
        if (coolDownEndDate != null)
          _buildCooldownWidget(
            coolDownEndDate: coolDownEndDate,
            isArabic: isArabic,
            isDarkMode: isDarkMode,
          ),

        // VIP Progress (if not VIP)
        if (tier != 'vip')
          _buildVIPProgressWidget(
            isArabic: isArabic,
            isDarkMode: isDarkMode,
          ),

        // Quick Links
        _buildQuickLinksSection(
          isArabic: isArabic,
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  Widget _buildCooldownWidget({
    required Timestamp coolDownEndDate,
    required bool isArabic,
    required bool isDarkMode,
  }) {
    final endDate = coolDownEndDate.toDate();
    final now = DateTime.now();
    final difference = endDate.difference(now);

    if (difference.isNegative) {
      return Container(); // Cooldown expired
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppTheme.warningColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            color: AppTheme.warningColor,
            size: 24.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'فترة الانتظار' : 'Cooldown Period',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningColor,
                  ),
                ),
                Text(
                  isArabic
                      ? '${difference.inDays} يوم، ${difference.inHours % 24} ساعة متبقية'
                      : '${difference.inDays} days, ${difference.inHours % 24} hours remaining',
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

  Widget _buildVIPProgressWidget({
    required bool isArabic,
    required bool isDarkMode,
  }) {
    // This would be calculated from actual data
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.1),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Colors.amber,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                FontAwesomeIcons.crown,
                color: Colors.amber,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                isArabic ? 'التقدم نحو VIP' : 'VIP Progress',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            isArabic
                ? 'تحتاج 15 مساهمة إجمالية و 5 مساهمات صندوق'
                : 'Need 15 total shares & 5 fund shares',
            style: TextStyle(
              fontSize: 11.sp,
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinksSection({
    required bool isArabic,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'روابط سريعة' : 'Quick Links',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildQuickLinkChip(
                label: isArabic ? 'اللوحة الرئيسية' : 'Leaderboard',
                icon: Icons.leaderboard,
                onTap: () => _navigateToLeaderboard(),
              ),
              _buildQuickLinkChip(
                label: isArabic ? 'المقاييس' : 'Metrics',
                icon: Icons.analytics,
                onTap: () => _navigateToMetrics(),
              ),
              _buildQuickLinkChip(
                label: isArabic ? 'الدعم' : 'Support',
                icon: Icons.help_outline,
                onTap: () => _showSupportDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinkChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp),
          SizedBox(width: 4.w),
          Text(label, style: TextStyle(fontSize: 12.sp)),
        ],
      ),
      onPressed: onTap,
      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
      labelStyle: TextStyle(color: AppTheme.primaryColor),
    );
  }

  // Navigation methods
  void _navigateToBalanceDetails() {
    // TODO: Implement once screen is created
    Fluttertoast.showToast(msg: 'Balance Details - Coming Soon');
  }

  void _navigateToSellGame() {
    // TODO: Implement once screen is created
    Fluttertoast.showToast(msg: 'Sell Game - Coming Soon');
  }

  void _navigateToQueueManagement() {
    // TODO: Implement once screen is created
    Fluttertoast.showToast(msg: 'Queue Management - Coming Soon');
  }

  void _navigateToReferralDashboard() {
    // TODO: Implement once screen is created
    Fluttertoast.showToast(msg: 'Referral Dashboard - Coming Soon');
  }

  void _navigateToLeaderboard() {
    // TODO: Implement once screen is created
    Fluttertoast.showToast(msg: 'Leaderboard - Coming Soon');
  }

  void _navigateToMetrics() {
    // TODO: Implement once screen is created
    Fluttertoast.showToast(msg: 'Metrics Dashboard - Coming Soon');
  }

  void _showSupportDialog() {
    // Show support dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Support'),
        content: Text('Contact support@sharestation.com'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  double _calculateTotalBalance(Map<String, dynamic> userData) {
    double total = 0;
    final entries = userData['balanceEntries'] as List<dynamic>? ?? [];

    for (var entry in entries) {
      if (entry['isExpired'] != true) {
        // Ensure amount is treated as double
        final amount = entry['amount'];
        if (amount != null) {
          total += amount is int ? amount.toDouble() : amount;
        }
      }
    }

    // Add other balance components with proper type handling
    final cashIn = userData['cashIn'];
    if (cashIn != null) {
      total += cashIn is int ? cashIn.toDouble() : cashIn;
    }

    return total;
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