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
      // Count pending memberships
      final memberships = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .get();

      // Count pending game contributions (simplified query)
      final games = await _firestore
          .collection('contribution_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      // Count pending fund contributions
      final funds = await _firestore
          .collection('fund_contribution_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      // Count pending borrow requests
      final borrows = await _firestore
          .collection('borrow_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      // Count pending return requests
      final returns = await _firestore
          .collection('return_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      if (mounted) {
        setState(() {
          _pendingMemberships = memberships.docs.length;
          _pendingGames = games.docs.length;
          _pendingFunds = funds.docs.length;
          _pendingBorrows = borrows.docs.length;
          _pendingReturns = returns.docs.length;
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingCounts,
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

  // Membership Approval Tab
  Widget _buildMembershipTab(bool isArabic, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              isArabic ? 'خطأ في تحميل الطلبات' : 'Error loading requests',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          );
        }

        final requests = snapshot.data?.docs ?? [];

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
            final tier = UserTier.fromString(data['tier'] ?? 'user');
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

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
                        Text(
                          data['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
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
                    if (data['recruiterId'] != null && data['recruiterId'].isNotEmpty)
                      _buildInfoRow(
                        icon: Icons.person_add,
                        label: isArabic ? 'معرف المُحيل' : 'Referrer ID',
                        value: data['recruiterId'],
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
      },
    );
  }

  // Games Approval Tab
  Widget _buildGamesTab(bool isArabic, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('contribution_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              isArabic ? 'خطأ في تحميل الطلبات' : 'Error loading requests',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          );
        }

        // Filter for game type in memory
        final requests = snapshot.data?.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['type'] == 'game' || data['type'] == null;
        }).toList() ?? [];

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
                            data['accountType']?.toUpperCase() ?? 'GAME',
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
                      value: data['platform']?.toUpperCase() ?? 'PS4/PS5',
                    ),
                    _buildInfoRow(
                      icon: Icons.category,
                      label: isArabic ? 'نوع الحساب' : 'Account Type',
                      value: _getAccountTypeDisplay(data['accountType'], isArabic),
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

                    if (data['description'] != null && data['description'].isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Text(
                          data['description'],
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
                              data['contributorId'],
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

  // Funds Approval Tab
  Widget _buildFundsTab(bool isArabic, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('fund_contribution_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              isArabic ? 'خطأ في تحميل الطلبات' : 'Error loading requests',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          );
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.dollarSign,
                  size: 64.sp,
                  color: AppTheme.primaryColor.withOpacity(0.5),
                ),
                SizedBox(height: 16.h),
                Text(
                  isArabic
                      ? 'لا توجد طلبات تمويل معلقة'
                      : 'No pending fund contributions',
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
                    // Fund Game Title
                    Text(
                      data['gameTitle'] ?? 'Fund Contribution',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Contributor Info
                    _buildInfoRow(
                      icon: Icons.person,
                      label: isArabic ? 'المساهم' : 'Contributor',
                      value: data['contributorName'] ?? 'Unknown',
                    ),
                    _buildInfoRow(
                      icon: Icons.attach_money,
                      label: isArabic ? 'المبلغ' : 'Amount',
                      value: '${data['amount']?.toStringAsFixed(0) ?? '0'} LE',
                    ),
                    _buildInfoRow(
                      icon: Icons.payment,
                      label: isArabic ? 'طريقة الدفع' : 'Payment Method',
                      value: data['paymentMethod'] ?? 'Unknown',
                    ),

                    // Receipt Image
                    if (data['receiptUrl'] != null && data['receiptUrl'].isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 12.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'إيصال الدفع:' : 'Payment Receipt:',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            GestureDetector(
                              onTap: () => _showReceiptImage(
                                context,
                                data['receiptUrl'],
                              ),
                              child: Container(
                                height: 200.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.r),
                                  child: CachedNetworkImage(
                                    imageUrl: data['receiptUrl'],
                                    fit: BoxFit.cover,
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
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 16.h),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveFundContribution(
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
                            onPressed: () => _rejectFundContribution(
                              requestId,
                              data['contributorId'],
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

  // Borrows Approval Tab
  Widget _buildBorrowsTab(bool isArabic, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('borrow_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              isArabic ? 'خطأ في تحميل الطلبات' : 'Error loading requests',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          );
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.handHolding,
                  size: 64.sp,
                  color: AppTheme.primaryColor.withOpacity(0.5),
                ),
                SizedBox(height: 16.h),
                Text(
                  isArabic
                      ? 'لا توجد طلبات استعارة معلقة'
                      : 'No pending borrow requests',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: isDarkMode
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  isArabic
                      ? 'ستظهر طلبات الاستعارة هنا عندما يطلب المستخدمون الألعاب'
                      : 'Borrow requests will appear here when users request games',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDarkMode
                        ? AppTheme.darkTextSecondary.withOpacity(0.7)
                        : AppTheme.lightTextSecondary.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
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
                    // Game Title
                    Text(
                      data['gameTitle'] ?? 'Unknown Game',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Borrower Info
                    _buildInfoRow(
                      icon: Icons.person,
                      label: isArabic ? 'المستعير' : 'Borrower',
                      value: data['borrowerName'] ?? 'Unknown',
                    ),
                    _buildInfoRow(
                      icon: Icons.devices,
                      label: isArabic ? 'المنصة' : 'Platform',
                      value: data['platform']?.toUpperCase() ?? 'PS4/PS5',
                    ),
                    _buildInfoRow(
                      icon: Icons.category,
                      label: isArabic ? 'نوع الحساب' : 'Account Type',
                      value: _getAccountTypeDisplay(data['accountType'], isArabic),
                    ),
                    _buildInfoRow(
                      icon: Icons.speed,
                      label: isArabic ? 'قيمة الاستعارة' : 'Borrow Value',
                      value: '${data['borrowValue']?.toStringAsFixed(0) ?? '0'} LE',
                    ),
                    _buildInfoRow(
                      icon: Icons.account_balance_wallet,
                      label: isArabic ? 'الحد المتبقي' : 'Remaining Limit',
                      value: '${data['userRemainingLimit']?.toStringAsFixed(0) ?? '0'} LE',
                    ),

                    // Check if user has enough limit
                    if (data['borrowValue'] != null && data['userRemainingLimit'] != null)
                      Container(
                        margin: EdgeInsets.only(top: 8.h),
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: data['userRemainingLimit'] >= data['borrowValue']
                              ? AppTheme.successColor.withOpacity(0.1)
                              : AppTheme.errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              data['userRemainingLimit'] >= data['borrowValue']
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: data['userRemainingLimit'] >= data['borrowValue']
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              data['userRemainingLimit'] >= data['borrowValue']
                                  ? (isArabic ? 'المستخدم لديه حد كافي' : 'User has sufficient limit')
                                  : (isArabic ? 'المستخدم ليس لديه حد كافي' : 'User has insufficient limit'),
                              style: TextStyle(
                                color: data['userRemainingLimit'] >= data['borrowValue']
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 16.h),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: data['userRemainingLimit'] >= data['borrowValue']
                                ? () => _approveBorrowRequest(requestId, data, isArabic)
                                : null,
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
                            onPressed: () => _rejectBorrowRequest(requestId, data['borrowerId'], isArabic),
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

  // Returns Approval Tab
  Widget _buildReturnsTab(bool isArabic, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('return_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              isArabic ? 'خطأ في تحميل الطلبات' : 'Error loading requests',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          );
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.arrowRotateLeft,
                  size: 64.sp,
                  color: AppTheme.primaryColor.withOpacity(0.5),
                ),
                SizedBox(height: 16.h),
                Text(
                  isArabic
                      ? 'لا توجد طلبات إرجاع معلقة'
                      : 'No pending return requests',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: isDarkMode
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  isArabic
                      ? 'ستظهر طلبات الإرجاع هنا عندما يريد المستخدمون إرجاع الألعاب'
                      : 'Return requests will appear here when users want to return games',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDarkMode
                        ? AppTheme.darkTextSecondary.withOpacity(0.7)
                        : AppTheme.lightTextSecondary.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
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

            // Calculate borrowing duration
            final borrowDate = (data['borrowDate'] as Timestamp?)?.toDate();
            final now = DateTime.now();
            final duration = borrowDate != null
                ? now.difference(borrowDate).inDays
                : 0;

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
                    // Game Title
                    Text(
                      data['gameTitle'] ?? 'Unknown Game',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Borrower Info
                    _buildInfoRow(
                      icon: Icons.person,
                      label: isArabic ? 'المستخدم' : 'User',
                      value: data['borrowerName'] ?? 'Unknown',
                    ),
                    _buildInfoRow(
                      icon: Icons.calendar_today,
                      label: isArabic ? 'تاريخ الاستعارة' : 'Borrow Date',
                      value: borrowDate != null
                          ? DateFormat('dd MMM yyyy').format(borrowDate)
                          : 'Unknown',
                    ),
                    _buildInfoRow(
                      icon: Icons.timer,
                      label: isArabic ? 'مدة الاستعارة' : 'Borrowing Duration',
                      value: isArabic
                          ? '$duration أيام'
                          : '$duration days',
                    ),
                    _buildInfoRow(
                      icon: Icons.speed,
                      label: isArabic ? 'قيمة الاستعارة' : 'Borrow Value',
                      value: '${data['borrowValue']?.toStringAsFixed(0) ?? '0'} LE',
                    ),

                    SizedBox(height: 16.h),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveReturnRequest(requestId, data, isArabic),
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
                            onPressed: () => _rejectReturnRequest(requestId, data['borrowerId'], isArabic),
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

  String _getAccountTypeDisplay(String? type, bool isArabic) {
    switch (type) {
      case 'primary':
        return isArabic ? 'أساسي' : 'Primary';
      case 'secondary':
        return isArabic ? 'ثانوي' : 'Secondary';
      case 'full':
        return isArabic ? 'كامل' : 'Full';
      case 'psPlus':
        return 'PS Plus';
      default:
        return isArabic ? 'غير محدد' : 'Unknown';
    }
  }

  // Approval Methods
  Future<void> _approveMembership(String userId, Map<String, dynamic> data, bool isArabic) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'active',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin', // Get from auth provider
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تمت الموافقة على العضوية' : 'Membership approved'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      _loadPendingCounts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'خطأ في الموافقة' : 'Error approving'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _rejectMembership(String userId, bool isArabic) async {
    // Show rejection reason dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'سبب الرفض' : 'Rejection Reason'),
        content: TextField(
          decoration: InputDecoration(
            hintText: isArabic ? 'أدخل سبب الرفض' : 'Enter rejection reason',
          ),
          onChanged: (value) {},
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'reason'),
            child: Text(isArabic ? 'رفض' : 'Reject'),
          ),
        ],
      ),
    );

    if (reason != null) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'خطأ في الرفض' : 'Error rejecting'),
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
        contributionData: requestData,  // Changed from requestData to contributionData
        onApproved: () {  // Changed from onApprove to onApproved
          _loadPendingCounts();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _rejectGameContribution(String requestId, String contributorId, bool isArabic) async {
    // Similar rejection logic with reason
  }

  Future<void> _approveFundContribution(String requestId, Map<String, dynamic> data, bool isArabic) async {
    // Fund contribution approval logic
  }

  Future<void> _rejectFundContribution(String requestId, String contributorId, bool isArabic) async {
    // Fund contribution rejection logic
  }

  Future<void> _approveBorrowRequest(String requestId, Map<String, dynamic> data, bool isArabic) async {
    // Borrow request approval logic
  }

  Future<void> _rejectBorrowRequest(String requestId, String borrowerId, bool isArabic) async {
    // Borrow request rejection logic
  }

  Future<void> _approveReturnRequest(String requestId, Map<String, dynamic> data, bool isArabic) async {
    // Return request approval logic
  }

  Future<void> _rejectReturnRequest(String requestId, String borrowerId, bool isArabic) async {
    // Return request rejection logic
  }

  void _showReceiptImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}