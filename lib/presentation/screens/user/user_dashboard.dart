// lib/presentation/screens/user/user_dashboard.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../../widgets/custom_loading.dart';
import '../user/browse_games_screen.dart';
import '../user/my_borrowings_screen.dart';
import '../user/my_contributions_screen.dart';
import '../user/profile_screen.dart';
import '../user/add_contribution_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({Key? key}) : super(key: key);

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Real-time statistics
  int _totalGames = 0;
  int _availableGames = 0;
  int _userPendingRequests = 0;
  int _userApprovedContributions = 0;
  int _userActiveBorrows = 0;

  @override
  void initState() {
    super.initState();
    _loadLibraryStatistics();
  }

  Future<void> _loadLibraryStatistics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    try {
      // Count total games in library
      final gamesSnapshot = await _firestore
          .collection('games')
          .where('isActive', isEqualTo: true)
          .get();

      int availableCount = 0;
      for (var doc in gamesSnapshot.docs) {
        final data = doc.data();

        // Check if game has available slots
        if (data['accounts'] != null) {
          final accounts = data['accounts'] as List<dynamic>;
          for (var account in accounts) {
            final slots = account['slots'] as Map<String, dynamic>?;
            if (slots != null) {
              final hasAvailable = slots.values.any((slot) =>
              slot['status'] == 'available'
              );
              if (hasAvailable) {
                availableCount++;
                break; // Count game only once even if multiple slots available
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalGames = gamesSnapshot.docs.length;
          _availableGames = availableCount;
        });
      }
    } catch (e) {
      print('Error loading library statistics: $e');
    }
  }

  Stream<Map<String, dynamic>> _getUserStatistics(String userId) {
    // Combine multiple streams for user statistics
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userSnapshot) async {

      // Get pending contribution requests
      final pendingContributions = await _firestore
          .collection('contribution_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      // Get approved contributions
      final approvedContributions = await _firestore
          .collection('contribution_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .count()
          .get();

      // Get pending borrow requests
      final pendingBorrows = await _firestore
          .collection('borrow_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      // Get active borrows
      final activeBorrows = await _firestore
          .collection('borrow_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .count()
          .get();

      return {
        'userData': userSnapshot.data(),
        'pendingRequests': (pendingContributions.count ?? 0) + (pendingBorrows.count ?? 0),
        'approvedContributions': approvedContributions.count ?? 0,
        'activeBorrows': activeBorrows.count ?? 0,
      };
    });
  }

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
      appBar: AppBar(
        title: Text(
          isArabic ? 'لوحة التحكم' : 'Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          // Add Contribution Button
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddContributionScreen(),
                ),
              ).then((_) {
                // Refresh statistics after returning
                _loadLibraryStatistics();
              });
            },
            tooltip: isArabic ? 'إضافة مساهمة' : 'Add Contribution',
          ),
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              // Navigate to notifications
            },
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _getUserStatistics(currentUser.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CustomLoading());
          }

          final data = snapshot.data!;
          final userData = data['userData'] as Map<String, dynamic>?;

          if (userData == null) {
            return Center(
              child: Text(isArabic ? 'خطأ في تحميل البيانات' : 'Error loading data'),
            );
          }

          // Parse user data
          final userName = userData['name'] ?? 'User';
          final tierValue = userData['tier'] ?? 'member';
          final tier = UserTier.fromString(tierValue);

          // Financial metrics
          final stationLimit = (userData['stationLimit'] ?? 0).toDouble();
          final remainingStationLimit = (userData['remainingStationLimit'] ?? stationLimit).toDouble();
          final usedStationLimit = stationLimit - remainingStationLimit;

          // Calculate total balance from balance entries
          double totalBalance = 0;
          if (userData['balanceEntries'] != null) {
            final entries = userData['balanceEntries'] as List<dynamic>;
            for (var entry in entries) {
              if (entry['isExpired'] != true) {
                totalBalance += (entry['amount'] ?? 0).toDouble();
              }
            }
          }

          // Points and contributions
          final points = userData['points'] ?? 0;
          final gameShares = (userData['gameShares'] ?? 0).toDouble();
          final fundShares = (userData['fundShares'] ?? 0).toDouble();
          final totalShares = (userData['totalShares'] ?? (gameShares + fundShares)).toDouble();

          // Borrowing metrics
          final currentBorrows = (userData['currentBorrows'] ?? 0).toDouble();
          final borrowLimit = userData['borrowLimit'] ?? 1;
          final totalBorrowsCount = userData['totalBorrowsCount'] ?? 0;

          // Statistics from stream
          final pendingRequests = data['pendingRequests'] ?? 0;
          final approvedContributions = data['approvedContributions'] ?? 0;
          final activeBorrows = data['activeBorrows'] ?? 0;

          // Check if close to VIP promotion
          final isCloseToVIP = tier != UserTier.vip && totalShares >= 10 && fundShares >= 3;
          final sharesNeededForVIP = totalShares < 15 ? (15 - totalShares).toInt() : 0;
          final fundSharesNeededForVIP = fundShares < 5 ? (5 - fundShares).toInt() : 0;

          return RefreshIndicator(
            onRefresh: _loadLibraryStatistics,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Message
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'مرحباً، $userName!'
                                  : 'Welcome, $userName!',
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                // Member ID Badge
                                if (userData['memberId'] != null) ...[
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4.r),
                                      border: Border.all(color: AppTheme.primaryColor),
                                    ),
                                    child: Text(
                                      'ID: ${userData['memberId']}',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                ],
                                Text(
                                  isArabic
                                      ? 'عضو منذ ${_formatMembershipDuration(userData['joinDate'])}'
                                      : 'Member since ${_formatMembershipDuration(userData['joinDate'])}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: isDarkMode
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // User Tier Badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: _getTierColor(tier).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: _getTierColor(tier),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTierIcon(tier),
                              color: _getTierColor(tier),
                              size: 16.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              tier.displayName,
                              style: TextStyle(
                                color: _getTierColor(tier),
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // VIP Promotion Progress (if applicable)
                  if (isCloseToVIP) ...[
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.withOpacity(0.1),
                            Colors.orange.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(FontAwesomeIcons.crown,
                                  color: Colors.amber,
                                  size: 16.sp
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                isArabic ? 'قريب من VIP!' : 'Close to VIP!',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            isArabic
                                ? 'تحتاج $sharesNeededForVIP مساهمة و $fundSharesNeededForVIP مساهمة تمويل'
                                : 'Need $sharesNeededForVIP shares & $fundSharesNeededForVIP fund shares',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.amber[700],
                            ),
                          ),
                          SizedBox(height: 8.h),
                          LinearProgressIndicator(
                            value: totalShares / 15,
                            backgroundColor: Colors.amber.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 24.h),

                  // Main Metrics Cards
                  Text(
                    isArabic ? 'المقاييس الرئيسية' : 'Main Metrics',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 12.h),

                  // Balance and Points Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: isArabic ? 'الرصيد' : 'Balance',
                          value: '${totalBalance.toStringAsFixed(0)}',
                          unit: 'LE',
                          icon: FontAwesomeIcons.wallet,
                          color: AppTheme.successColor,
                          isDarkMode: isDarkMode,
                          subtitle: userData['balanceEntries'] != null
                              ? '${(userData['balanceEntries'] as List).where((e) => e['isExpired'] != true).length} ${isArabic ? "مدخلات نشطة" : "active entries"}'
                              : null,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildMetricCard(
                          title: isArabic ? 'النقاط' : 'Points',
                          value: points.toString(),
                          unit: 'pts',
                          icon: FontAwesomeIcons.star,
                          color: AppTheme.warningColor,
                          isDarkMode: isDarkMode,
                          subtitle: points >= 25
                              ? (isArabic ? 'يمكن التحويل' : 'Can redeem')
                              : null,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12.h),

                  // Station Limit Card with Progress
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  FontAwesomeIcons.gauge,
                                  color: AppTheme.primaryColor,
                                  size: 20.sp,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  isArabic ? 'حد المحطة' : 'Station Limit',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${remainingStationLimit.toStringAsFixed(0)}/${stationLimit.toStringAsFixed(0)} LE',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4.r),
                          child: LinearProgressIndicator(
                            value: stationLimit > 0 ? remainingStationLimit / stationLimit : 0,
                            minHeight: 8.h,
                            backgroundColor: AppTheme.errorColor.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              remainingStationLimit > stationLimit * 0.3
                                  ? AppTheme.successColor
                                  : AppTheme.warningColor,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          isArabic
                              ? 'مستخدم: ${usedStationLimit.toStringAsFixed(0)} LE'
                              : 'Used: ${usedStationLimit.toStringAsFixed(0)} LE',
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

                  SizedBox(height: 12.h),

                  // Contributions and Borrows Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: isArabic ? 'المساهمات' : 'Contributions',
                          value: totalShares.toStringAsFixed(1),
                          unit: isArabic ? 'مساهمة' : 'shares',
                          icon: FontAwesomeIcons.handHoldingDollar,
                          color: AppTheme.infoColor,
                          isDarkMode: isDarkMode,
                          subtitle: '${gameShares.toStringAsFixed(1)} ${isArabic ? "لعبة" : "game"}, ${fundShares.toStringAsFixed(0)} ${isArabic ? "تمويل" : "fund"}',
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildMetricCard(
                          title: isArabic ? 'الاستعارات' : 'Borrows',
                          value: '${currentBorrows.toStringAsFixed(1)}/$borrowLimit',
                          unit: isArabic ? 'نشط' : 'active',
                          icon: FontAwesomeIcons.gamepad,
                          color: currentBorrows >= borrowLimit
                              ? AppTheme.errorColor
                              : AppTheme.secondaryColor,
                          isDarkMode: isDarkMode,
                          subtitle: totalBorrowsCount > 0
                              ? '${isArabic ? "المجموع:" : "Total:"} $totalBorrowsCount'
                              : null,
                        ),
                      ),
                    ],
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

                  SizedBox(height: 12.h),

                  GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12.h,
                    crossAxisSpacing: 12.w,
                    childAspectRatio: 1.5,
                    children: [
                      _buildActionCard(
                        title: isArabic ? 'تصفح الألعاب' : 'Browse Games',
                        icon: FontAwesomeIcons.magnifyingGlass,
                        color: AppTheme.primaryColor,
                        badge: _availableGames > 0 ? _availableGames.toString() : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BrowseGamesScreen(),
                            ),
                          );
                        },
                      ),
                      _buildActionCard(
                        title: isArabic ? 'استعاراتي' : 'My Borrowings',
                        icon: FontAwesomeIcons.gamepad,
                        color: AppTheme.secondaryColor,
                        badge: activeBorrows > 0 ? activeBorrows.toString() : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MyBorrowingsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildActionCard(
                        title: isArabic ? 'المساهمات' : 'Contributions',
                        icon: FontAwesomeIcons.handHoldingDollar,
                        color: AppTheme.successColor,
                        badge: approvedContributions > 0 ? approvedContributions.toString() : null,
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
                        title: isArabic ? 'الملف الشخصي' : 'Profile',
                        icon: FontAwesomeIcons.user,
                        color: AppTheme.warningColor,
                        badge: pendingRequests > 0 ? pendingRequests.toString() : null,
                        badgeColor: AppTheme.errorColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  // Borrow Window Status
                  StreamBuilder<DocumentSnapshot>(
                    stream: _firestore.collection('settings').doc('borrow_window').snapshots(),
                    builder: (context, snapshot) {
                      bool isWindowOpen = false;
                      String nextWindowTime = '';

                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        isWindowOpen = data?['isOpen'] ?? false;

                        if (!isWindowOpen) {
                          final now = DateTime.now();
                          final daysUntilThursday = (DateTime.thursday - now.weekday) % 7;
                          final nextThursday = now.add(Duration(
                              days: daysUntilThursday == 0 ? 7 : daysUntilThursday
                          ));
                          nextWindowTime = '${nextThursday.day}/${nextThursday.month}';
                        }
                      }

                      return Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: isWindowOpen
                              ? AppTheme.successColor.withOpacity(0.1)
                              : AppTheme.warningColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isWindowOpen
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isWindowOpen ? Icons.lock_open : Icons.lock,
                              color: isWindowOpen
                                  ? AppTheme.successColor
                                  : AppTheme.warningColor,
                            ),
                            SizedBox(width: 12.w),
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
                                    isWindowOpen
                                        ? (isArabic ? 'مفتوحة الآن - يمكنك الاستعارة!' : 'Open Now - You can borrow!')
                                        : (isArabic
                                        ? 'مغلقة - تفتح الخميس $nextWindowTime'
                                        : 'Closed - Opens Thursday $nextWindowTime'),
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: isDarkMode
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 24.h),

                  // Library Statistics
                  Text(
                    isArabic ? 'إحصائيات المكتبة' : 'Library Statistics',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 12.h),

                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          title: isArabic ? 'إجمالي الألعاب' : 'Total Games',
                          value: _totalGames.toString(),
                          icon: FontAwesomeIcons.gamepad,
                          color: AppTheme.primaryColor,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildInfoCard(
                          title: isArabic ? 'متاح للاستعارة' : 'Available',
                          value: _availableGames.toString(),
                          icon: FontAwesomeIcons.circleCheck,
                          color: AppTheme.successColor,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildInfoCard(
                          title: isArabic ? 'طلبات معلقة' : 'Pending',
                          value: pendingRequests.toString(),
                          icon: FontAwesomeIcons.clock,
                          color: AppTheme.warningColor,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatMembershipDuration(dynamic joinDate) {
    if (joinDate == null) return '';

    try {
      DateTime join;
      if (joinDate is Timestamp) {
        join = joinDate.toDate();
      } else if (joinDate is DateTime) {
        join = joinDate;
      } else {
        return '';
      }

      final now = DateTime.now();
      final difference = now.difference(join);

      if (difference.inDays < 30) {
        return '${difference.inDays} days';
      } else if (difference.inDays < 365) {
        return '${(difference.inDays / 30).floor()} months';
      } else {
        return '${(difference.inDays / 365).floor()} years';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
    String? subtitle,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: color,
                size: 20.sp,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: isDarkMode
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.sp,
                color: color.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 32.sp,
                ),
                SizedBox(height: 8.h),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: badgeColor ?? color,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: 20.w,
                    minHeight: 20.w,
                  ),
                  child: Center(
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
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
          Icon(
            icon,
            color: color,
            size: 24.sp,
          ),
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
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.sp,
              color: isDarkMode
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(UserTier tier) {
    switch (tier) {
      case UserTier.admin:
        return Colors.red;
      case UserTier.vip:
        return Colors.amber;
      case UserTier.member:
        return AppTheme.primaryColor;
      case UserTier.client:
        return AppTheme.secondaryColor;
      case UserTier.user:
        return AppTheme.infoColor;
    }
  }

  IconData _getTierIcon(UserTier tier) {
    switch (tier) {
      case UserTier.admin:
        return FontAwesomeIcons.userShield;
      case UserTier.vip:
        return FontAwesomeIcons.crown;
      case UserTier.member:
        return FontAwesomeIcons.userCheck;
      case UserTier.client:
        return FontAwesomeIcons.userClock;
      case UserTier.user:
        return FontAwesomeIcons.user;
    }
  }
}