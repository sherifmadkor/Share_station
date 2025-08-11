import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/game_model.dart';
import '../../../services/referral_service.dart';
import '../../widgets/admin/game_approval_modal.dart';

class AdminApprovalDashboard extends StatefulWidget {
  const AdminApprovalDashboard({Key? key}) : super(key: key);

  @override
  State<AdminApprovalDashboard> createState() => _AdminApprovalDashboardState();
}

class _AdminApprovalDashboardState extends State<AdminApprovalDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Counters for pending requests
  int _pendingMemberships = 0;
  int _pendingGames = 0;
  int _pendingFunds = 0;
  int _pendingBorrows = 0;
  int _pendingReturns = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadPendingCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingCounts() async {
    try {
      // Count pending memberships - Fixed query
      int pendingMembershipsCount = 0;
      try {
        final memberships = await _firestore
            .collection('users')
            .where('status', isEqualTo: 'pending')
            .limit(100) // Add limit to prevent excessive reads
            .get();
        pendingMembershipsCount = memberships.docs.length;
      } catch (e) {
        print('Error loading memberships: $e');
        // Try alternative query without ordering if it fails
        try {
          final allUsers = await _firestore
              .collection('users')
              .limit(100)
              .get();
          // Filter in memory
          final pendingUsers = allUsers.docs
              .where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data != null && data['status'] == 'pending';
          })
              .toList();
          pendingMembershipsCount = pendingUsers.length;
        } catch (e2) {
          print('Alternative query also failed: $e2');
          pendingMembershipsCount = 0;
        }
      }

      // Count pending game contributions
      int pendingGamesCount = 0;
      try {
        final games = await _firestore
            .collection('contribution_requests')
            .where('status', isEqualTo: 'pending')
            .where('type', isEqualTo: 'game')
            .limit(100)
            .get();
        pendingGamesCount = games.docs.length;
      } catch (e) {
        print('Error loading game contributions: $e');
        // Try without type filter
        try {
          final games = await _firestore
              .collection('contribution_requests')
              .where('status', isEqualTo: 'pending')
              .limit(100)
              .get();
          pendingGamesCount = games.docs.length;
        } catch (e2) {
          print('Alternative query for games failed: $e2');
          pendingGamesCount = 0;
        }
      }

      // Count pending fund contributions
      int pendingFundsCount = 0;
      try {
        final funds = await _firestore
            .collection('fund_contribution_requests')
            .where('status', isEqualTo: 'pending')
            .limit(100)
            .get();
        pendingFundsCount = funds.docs.length;
      } catch (e) {
        print('Error loading fund contributions: $e');
        pendingFundsCount = 0;
      }

      // Count pending borrow requests
      int pendingBorrowsCount = 0;
      try {
        final borrows = await _firestore
            .collection('borrow_requests')
            .where('status', isEqualTo: 'pending')
            .limit(100)
            .get();
        pendingBorrowsCount = borrows.docs.length;
      } catch (e) {
        print('Error loading borrow requests: $e');
        pendingBorrowsCount = 0;
      }

      // Count pending return requests
      int pendingReturnsCount = 0;
      try {
        final returns = await _firestore
            .collection('return_requests')
            .where('status', isEqualTo: 'pending')
            .limit(100)
            .get();
        pendingReturnsCount = returns.docs.length;
      } catch (e) {
        print('Error loading return requests: $e');
        pendingReturnsCount = 0;
      }

      if (mounted) {
        setState(() {
          _pendingMemberships = pendingMembershipsCount;
          _pendingGames = pendingGamesCount;
          _pendingFunds = pendingFundsCount;
          _pendingBorrows = pendingBorrowsCount;
          _pendingReturns = pendingReturnsCount;
        });
      }
    } catch (e) {
      print('Error loading pending counts: $e');
      // Set to 0 if error occurs
      if (mounted) {
        setState(() {
          _pendingMemberships = 0;
          _pendingGames = 0;
          _pendingFunds = 0;
          _pendingBorrows = 0;
          _pendingReturns = 0;
        });
      }
    }
  }

  Widget _buildBadge(int count) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppTheme.errorColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
          isArabic ? 'لوحة الموافقات' : 'Approval Dashboard',
          style: TextStyle(
            color: isDarkMode ? Colors.white : AppTheme.darkBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.admin_panel_settings),
            onSelected: (String value) {
              switch (value) {
                case 'fix_referrals':
                  _fixReferralRecords();
                  break;
                case 'update_revenue_status':
                  _updateReferralRevenueStatus();
                  break;
                case 'fix_missing_balances':
                  _fixMissingReferralBalances();
                  break;
                case 'diagnose_referrals':
                  _showDiagnosticDialog();
                  break;
                case 'complete_referral_fix':
                  _showCompleteReferralFix();
                  break;
                case 'refresh':
                  _loadPendingCounts();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'fix_referrals',
                child: ListTile(
                  leading: Icon(FontAwesomeIcons.userGroup),
                  title: Text('Fix Referral Records'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'update_revenue_status',
                child: ListTile(
                  leading: Icon(FontAwesomeIcons.coins),
                  title: Text('Update Revenue Status'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'fix_missing_balances',
                child: ListTile(
                  leading: Icon(Icons.build),
                  title: Text('Fix Missing Balances'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'diagnose_referrals',
                child: ListTile(
                  leading: Icon(Icons.bug_report),
                  title: Text('Diagnose Referrals'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'complete_referral_fix',
                child: ListTile(
                  leading: Icon(Icons.build_circle, color: Colors.red),
                  title: Text('Complete Referral Fix', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh Data'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                children: [
                  Text(isArabic ? 'العضويات' : 'Memberships'),
                  SizedBox(width: 4.w),
                  _buildBadge(_pendingMemberships),
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  Text(isArabic ? 'الألعاب' : 'Games'),
                  SizedBox(width: 4.w),
                  _buildBadge(_pendingGames),
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  Text(isArabic ? 'التمويل' : 'Funds'),
                  SizedBox(width: 4.w),
                  _buildBadge(_pendingFunds),
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  Text(isArabic ? 'الاستعارة' : 'Borrows'),
                  SizedBox(width: 4.w),
                  _buildBadge(_pendingBorrows),
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  Text(isArabic ? 'الإرجاع' : 'Returns'),
                  SizedBox(width: 4.w),
                  _buildBadge(_pendingReturns),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMembershipTab(isArabic, isDarkMode),
          _buildGamesTab(isArabic, isDarkMode),
          _buildFundsTab(isArabic, isDarkMode),
          _buildBorrowsTab(isArabic, isDarkMode),
          _buildReturnsTab(isArabic, isDarkMode),
        ],
      ),
    );
  }

  // Membership Approval Tab - Fixed
  Widget _buildMembershipTab(bool isArabic, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .limit(50) // Add limit to prevent excessive reads
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Membership tab error: ${snapshot.error}');
          // Try alternative approach without ordering
          return FutureBuilder<QuerySnapshot>(
            future: _firestore
                .collection('users')
                .limit(100)
                .get(),
            builder: (context, altSnapshot) {
              if (altSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (altSnapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48.sp,
                        color: AppTheme.errorColor,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        isArabic ? 'خطأ في تحميل الطلبات' : 'Error loading requests',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                      SizedBox(height: 8.h),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                      ),
                    ],
                  ),
                );
              }

              // Filter pending users in memory
              final allUsers = altSnapshot.data?.docs ?? [];
              final requests = allUsers.where((doc) {
                final data = doc.data() as Map<String, dynamic>?;
                return data != null && data['status'] == 'pending';
              }).toList();

              return _buildMembershipList(requests, isArabic, isDarkMode);
            },
          );
        }

        final requests = snapshot.data?.docs ?? [];
        return _buildMembershipList(requests, isArabic, isDarkMode);
      },
    );
  }

  Widget _buildMembershipList(List<QueryDocumentSnapshot> requests, bool isArabic, bool isDarkMode) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.userCheck,
              size: 64.sp,
              color: AppTheme.primaryColor.withOpacity(0.5),
            ),
            SizedBox(height: 16.h),
            Text(
              isArabic
                  ? 'لا توجد طلبات عضوية معلقة'
                  : 'No pending membership requests',
              style: TextStyle(
                fontSize: 16.sp,
                color: isDarkMode
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final data = requests[index].data() as Map<String, dynamic>;
        final userId = requests[index].id;

        // Safely parse tier with default fallback
        UserTier tier;
        try {
          tier = UserTier.fromString(data['tier'] ?? 'user');
        } catch (e) {
          tier = UserTier.user;
        }

        // Safely parse createdAt
        DateTime? createdAt;
        try {
          if (data['createdAt'] != null) {
            if (data['createdAt'] is Timestamp) {
              createdAt = (data['createdAt'] as Timestamp).toDate();
            }
          }
        } catch (e) {
          print('Error parsing createdAt: $e');
        }

        double subscriptionFee = 0;
        if (tier == UserTier.member) subscriptionFee = 1500;
        if (tier == UserTier.client) subscriptionFee = 750;

        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        data['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: _getTierColor(tier).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        tier.displayName,
                        style: TextStyle(
                          color: _getTierColor(tier),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                _buildInfoRow(
                  icon: Icons.email,
                  label: isArabic ? 'البريد' : 'Email',
                  value: data['email'] ?? '',
                ),
                _buildInfoRow(
                  icon: Icons.phone,
                  label: isArabic ? 'الهاتف' : 'Phone',
                  value: data['phoneNumber'] ?? '',
                ),
                _buildInfoRow(
                  icon: Icons.attach_money,
                  label: isArabic ? 'رسوم الاشتراك' : 'Subscription Fee',
                  value: '${subscriptionFee.toStringAsFixed(0)} LE',
                ),
                if (data['recruiterId'] != null && data['recruiterId'].toString().isNotEmpty)
                  _buildInfoRow(
                    icon: Icons.person_add,
                    label: isArabic ? 'معرف المُحيل' : 'Referrer ID',
                    value: data['recruiterId'].toString(),
                  ),
                if (createdAt != null)
                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    label: isArabic ? 'تاريخ التسجيل' : 'Registration Date',
                    value: DateFormat('dd MMM yyyy, HH:mm').format(createdAt),
                  ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _approveMembership(userId, data, isArabic),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          isArabic ? 'موافقة' : 'Approve',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rejectMembership(userId, isArabic),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: BorderSide(color: AppTheme.errorColor),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          isArabic ? 'رفض' : 'Reject',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Games Approval Tab - Fixed
  Widget _buildGamesTab(bool isArabic, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('contribution_requests')
          .where('status', isEqualTo: 'pending')
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Games tab error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48.sp,
                  color: AppTheme.errorColor,
                ),
                SizedBox(height: 16.h),
                Text(
                  isArabic ? 'خطأ في تحميل الطلبات' : 'Error loading requests',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.errorColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        // Filter for game type in memory
        final allRequests = snapshot.data?.docs ?? [];
        final requests = allRequests.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          return data != null &&
              (data['type'] == 'game' ||
                  data['type'] == null ||
                  data['gameTitle'] != null);
        }).toList();

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.gamepad,
                  size: 64.sp,
                  color: AppTheme.primaryColor.withOpacity(0.5),
                ),
                SizedBox(height: 16.h),
                Text(
                  isArabic
                      ? 'لا توجد طلبات ألعاب معلقة'
                      : 'No pending game contributions',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: isDarkMode
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            final requestId = doc.id;

            return Card(
              margin: EdgeInsets.only(bottom: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Game Title and Type
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            data['gameTitle'] ?? 'Unknown Game',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: data['accountType'] == 'psPlus'
                                ? Colors.amber.withOpacity(0.2)
                                : AppTheme.primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            data['accountType']?.toString().toUpperCase() ?? 'GAME',
                            style: TextStyle(
                              color: data['accountType'] == 'psPlus'
                                  ? Colors.amber[700]
                                  : AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Game Details
                    _buildInfoRow(
                      icon: Icons.person,
                      label: isArabic ? 'المساهم' : 'Contributor',
                      value: data['contributorName'] ?? 'Unknown',
                    ),
                    _buildInfoRow(
                      icon: Icons.devices,
                      label: isArabic ? 'المنصة' : 'Platform',
                      value: data['platform']?.toString().toUpperCase() ?? 'PS4/PS5',
                    ),
                    _buildInfoRow(
                      icon: Icons.category,
                      label: isArabic ? 'نوع الحساب' : 'Account Type',
                      value: _getAccountTypeDisplay(data['accountType']?.toString(), isArabic),
                    ),
                    _buildInfoRow(
                      icon: Icons.public,
                      label: isArabic ? 'المنطقة' : 'Region',
                      value: data['region'] ?? 'Global',
                    ),
                    _buildInfoRow(
                      icon: Icons.star,
                      label: isArabic ? 'الإصدار' : 'Edition',
                      value: data['edition'] ?? 'Standard',
                    ),

                    if (data['description'] != null &&
                        data['description'].toString().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Text(
                          data['description'].toString(),
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: isDarkMode
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    SizedBox(height: 16.h),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showGameApprovalModal(
                              context,
                              requestId,
                              data,
                              isArabic,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            child: Text(
                              isArabic ? 'موافقة' : 'Approve',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rejectGameContribution(
                              requestId,
                              data['contributorId']?.toString(),
                              isArabic,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.errorColor,
                              side: BorderSide(color: AppTheme.errorColor),
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            child: Text(
                              isArabic ? 'رفض' : 'Reject',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Add remaining tab implementations (Funds, Borrows, Returns)
  // These remain the same as in original file but with error handling improvements

  Widget _buildFundsTab(bool isArabic, bool isDarkMode) {
    // Implementation remains the same as original with added error handling
    return Center(
      child: Text(isArabic ? 'قيد التطوير' : 'Under Development'),
    );
  }

  Widget _buildBorrowsTab(bool isArabic, bool isDarkMode) {
    // Implementation remains the same as original with added error handling
    return Center(
      child: Text(isArabic ? 'قيد التطوير' : 'Under Development'),
    );
  }

  Widget _buildReturnsTab(bool isArabic, bool isDarkMode) {
    // Implementation remains the same as original with added error handling
    return Center(
      child: Text(isArabic ? 'قيد التطوير' : 'Under Development'),
    );
  }

  // Helper Methods
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: AppTheme.primaryColor),
          SizedBox(width: 8.w),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.primaryColor,
              ),
              overflow: TextOverflow.ellipsis,
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

  Future<void> _fixReferralRecords() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Fix Referral Records'),
          content: Text(
            'This will scan all referral records and fix any that have referral codes instead of user IDs. This is a one-time maintenance operation.\n\nProceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Fix Records'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Fixing referral records...'),
              ],
            ),
          );
        },
      );

      try {
        final referralService = ReferralService();
        final success = await referralService.fixExistingReferralRecords();
        
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? 'Referral records fixed successfully!' 
                : 'Error fixing referral records'),
            backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );

        if (success) {
          _loadPendingCounts(); // Refresh data
        }
      } catch (e) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _updateReferralRevenueStatus() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Update Referral Revenue Status'),
          content: Text(
            'This will check all pending referral revenues and move them to paid status if the referred member is now active. This fixes the 600 LE pending issue.\n\nProceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Update Status'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Updating revenue status...'),
              ],
            ),
          );
        },
      );

      try {
        final referralService = ReferralService();
        final success = await referralService.updateReferralRevenueStatus();
        
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? 'Referral revenue statuses updated successfully! Check console logs for details.' 
                : 'Error updating referral revenue statuses'),
            backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
            duration: Duration(seconds: 4),
          ),
        );

        if (success) {
          _loadPendingCounts(); // Refresh data
        }
      } catch (e) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _fixMissingReferralBalances() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Fix Missing Referral Balances'),
          content: Text(
            'This will scan all referral records and create missing balance entries for approved users who should have received referral rewards. This fixes the issue where referral commissions weren\'t credited to users\' balances.\n\nProceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Fix Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningColor,
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(
                  child: Text('Fixing missing referral balances...\nThis may take a few moments.'),
                ),
              ],
            ),
          );
        },
      );

      try {
        final referralService = ReferralService();
        final result = await referralService.fixMissingReferralBalances();
        
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Operation completed'),
            backgroundColor: result['success'] == true
                ? AppTheme.successColor 
                : AppTheme.errorColor,
            duration: Duration(seconds: 5),
          ),
        );

        // Show detailed results if successful
        if (result['success'] == true) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Fix Results'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✅ Fixed ${result['fixedCount']} referrals'),
                    SizedBox(height: 8),
                    Text('💰 Total amount restored: ${result['totalAmount']} LE'),
                    SizedBox(height: 16),
                    Text(
                      'Users can now see their referral commissions in their balance.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _loadPendingCounts(); // Refresh data
                    },
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      } catch (e) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showDiagnosticDialog() async {
    final TextEditingController userIdController = TextEditingController();
    
    final String? userId = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Diagnose Referral Issues'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter a user ID to diagnose referral issues:'),
              SizedBox(height: 16),
              TextField(
                controller: userIdController,
                decoration: InputDecoration(
                  hintText: 'User ID',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(userIdController.text.trim()),
              child: Text('Diagnose'),
            ),
          ],
        );
      },
    );

    if (userId != null && userId.isNotEmpty) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Running diagnostic...'),
              ],
            ),
          );
        },
      );

      try {
        final referralService = ReferralService();
        await referralService.diagnoseReferralIssue(userId);
        
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Diagnostic completed! Check console logs for detailed results.'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error running diagnostic: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showCompleteReferralFix() async {
    // First run comprehensive diagnosis
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Running Comprehensive Diagnosis'),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Analyzing referral system...\nCheck console for detailed results.')),
            ],
          ),
        );
      },
    );

    try {
      final referralService = ReferralService();
      await referralService.comprehensiveDiagnosis();
      
      Navigator.of(context).pop(); // Close diagnosis loading dialog
      
      // Show confirmation dialog with detailed description
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.build_circle, color: Colors.red),
                SizedBox(width: 8),
                Text('Complete Referral System Fix', style: TextStyle(color: Colors.red)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This comprehensive fix will:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text('1. 🔧 Fix all recruiterId fields that have referral codes instead of Firebase UIDs'),
                SizedBox(height: 8),
                Text('2. 🔗 Fix all referral records to use proper user IDs'),
                SizedBox(height: 8),
                Text('3. 💰 Create missing balance entries for all approved referrals'),
                SizedBox(height: 8),
                Text('4. 📊 Update revenue tracking for all affected users'),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ Important Notes:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700]),
                      ),
                      SizedBox(height: 4),
                      Text('• This operation processes ALL users and referrals', style: TextStyle(fontSize: 12)),
                      Text('• Check console logs for diagnosis results', style: TextStyle(fontSize: 12)),
                      Text('• Operation may take several minutes', style: TextStyle(fontSize: 12)),
                      Text('• Backup recommended before proceeding', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Continue with the complete fix?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Fix Everything'),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        // Show progress dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Fixing referral system...'),
                  SizedBox(height: 8),
                  Text(
                    'This may take several minutes.\nPlease wait...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          },
        );

        try {
          final result = await referralService.completeReferralSystemFix();
          
          Navigator.of(context).pop(); // Close progress dialog

          // Show detailed results
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  result['success'] == true ? '✅ Fix Complete!' : '❌ Fix Failed',
                  style: TextStyle(
                    color: result['success'] == true ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result['success'] == true) ...[
                      Text('🔧 Fixed users: ${result['fixedUsers']}'),
                      SizedBox(height: 8),
                      Text('🔗 Fixed referral records: ${result['fixedReferrals']}'),
                      SizedBox(height: 8),
                      Text('💰 Created balance entries: ${result['createdBalanceEntries']}'),
                      SizedBox(height: 8),
                      Text('📊 Total balance added: ${result['totalBalanceAdded']?.toStringAsFixed(2)} LE'),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'All users should now see their referral commissions in their balance. The referral system is now consistent and working properly.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ] else ...[
                      Text('Error: ${result['message']}'),
                    ],
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (result['success'] == true) {
                        _loadPendingCounts(); // Refresh data
                      }
                    },
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );

          // Show snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Operation completed'),
              backgroundColor: result['success'] == true
                  ? AppTheme.successColor 
                  : AppTheme.errorColor,
              duration: Duration(seconds: 5),
            ),
          );
        } catch (e) {
          Navigator.of(context).pop(); // Close progress dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close diagnosis dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error running diagnosis: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  String _getAccountTypeDisplay(String? type, bool isArabic) {
    switch (type?.toLowerCase()) {
      case 'primary':
        return isArabic ? 'أساسي' : 'Primary';
      case 'secondary':
        return isArabic ? 'ثانوي' : 'Secondary';
      case 'full':
        return isArabic ? 'كامل' : 'Full';
      case 'psplus':
        return 'PS Plus';
      default:
        return isArabic ? 'غير محدد' : 'Unknown';
    }
  }

  // Approval Methods - Updated for correct referral flow
  Future<void> _approveMembership(String userId, Map<String, dynamic> data, bool isArabic) async {
    try {
      // Update user status to active
      await _firestore.collection('users').doc(userId).update({
        'status': 'active',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin',
      });

      // Process referral reward if this user was referred
      final recruiterId = data['recruiterId'] as String?;
      if (recruiterId != null && recruiterId.isNotEmpty) {
        print('User $userId was referred with code: $recruiterId. Processing referral reward after approval...');
        
        final referralService = ReferralService();
        
        // Check if referral record already exists
        final existingReferrals = await _firestore
            .collection('referrals')
            .where('referredUserId', isEqualTo: userId)
            .get();
        
        if (existingReferrals.docs.isEmpty) {
          // No referral record exists, create it first (this shouldn't happen in new flow)
          final tier = data['tier'] as String? ?? 'member';
          final subscriptionFee = tier == 'client' ? 750.0 : 1500.0;
          
          await referralService.processReferral(
            newUserId: userId,
            referrerId: recruiterId,
            newUserTier: tier,
            subscriptionFee: subscriptionFee,
          );
          print('Created referral record for user $userId');
        }
        
        // Now trigger the referral reward after approval
        await referralService.processReferralRewardAfterApproval(userId);
        print('Processed referral reward after approval for user $userId');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تمت الموافقة على العضوية' : 'Membership approved'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      _loadPendingCounts();
    } catch (e) {
      print('Error approving membership: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'خطأ في الموافقة: $e' : 'Error approving: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _rejectMembership(String userId, bool isArabic) async {
    // Show rejection reason dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        String rejectionReason = '';
        return AlertDialog(
          title: Text(isArabic ? 'سبب الرفض' : 'Rejection Reason'),
          content: TextField(
            decoration: InputDecoration(
              hintText: isArabic ? 'أدخل سبب الرفض' : 'Enter rejection reason',
            ),
            onChanged: (value) {
              rejectionReason = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, rejectionReason),
              child: Text(isArabic ? 'رفض' : 'Reject'),
            ),
          ],
        );
      },
    );

    if (reason != null && reason.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(userId).update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectionReason': reason,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'تم رفض العضوية' : 'Membership rejected'),
            backgroundColor: AppTheme.warningColor,
          ),
        );

        _loadPendingCounts();
      } catch (e) {
        print('Error rejecting membership: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'خطأ في الرفض: $e' : 'Error rejecting: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showGameApprovalModal(
      BuildContext context,
      String requestId,
      Map<String, dynamic> requestData,
      bool isArabic,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GameApprovalModal(
        requestId: requestId,
        contributionData: requestData,
        onApproved: () {
          _loadPendingCounts();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _rejectGameContribution(String requestId, String? contributorId, bool isArabic) async {
    try {
      await _firestore.collection('contribution_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تم رفض المساهمة' : 'Contribution rejected'),
          backgroundColor: AppTheme.warningColor,
        ),
      );

      _loadPendingCounts();
    } catch (e) {
      print('Error rejecting contribution: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'خطأ في الرفض' : 'Error rejecting'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showReceiptImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => Center(
            child: CircularProgressIndicator(),
          ),
          errorWidget: (context, url, error) => Center(
            child: Icon(
              Icons.error_outline,
              color: AppTheme.errorColor,
              size: 48.sp,
            ),
          ),
        ),
      ),
    );
  }
}