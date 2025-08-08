import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'add_contribution_screen.dart';

class MyContributionsScreen extends StatefulWidget {
  const MyContributionsScreen({Key? key}) : super(key: key);

  @override
  State<MyContributionsScreen> createState() => _MyContributionsScreenState();
}

class _MyContributionsScreenState extends State<MyContributionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.login,
                size: 64.sp,
                color: AppTheme.primaryColor,
              ),
              SizedBox(height: 16.h),
              Text(
                isArabic ? 'الرجاء تسجيل الدخول' : 'Please login first',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          isArabic ? 'مساهماتي' : 'My Contributions',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.h),
          child: Container(
            color: AppTheme.primaryColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
              tabs: [
                Tab(text: isArabic ? 'المعتمدة' : 'Approved'),
                Tab(text: isArabic ? 'المعلقة' : 'Pending'),
                Tab(text: isArabic ? 'المرفوضة' : 'Rejected'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApprovedContributions(user.uid, isArabic, isDarkMode),
          _buildPendingContributions(user.uid, isArabic, isDarkMode),
          _buildRejectedContributions(user.uid, isArabic, isDarkMode),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddContributionScreen(),
            ),
          ).then((_) {
            // Refresh the screen when returning
            setState(() {});
          });
        },
        backgroundColor: AppTheme.primaryColor,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          isArabic ? 'إضافة مساهمة' : 'Add Contribution',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Build Approved Contributions Tab
  Widget _buildApprovedContributions(String userId, bool isArabic, bool isDarkMode) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getApprovedContributions(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Error loading approved contributions: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48.sp, color: AppTheme.errorColor),
                SizedBox(height: 16.h),
                Text(
                  isArabic ? 'خطأ في تحميل المساهمات' : 'Error loading contributions',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                SizedBox(height: 8.h),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                ),
              ],
            ),
          );
        }

        final contributions = snapshot.data ?? [];

        if (contributions.isEmpty) {
          return _buildEmptyState(
            icon: FontAwesomeIcons.checkCircle,
            title: isArabic ? 'لا توجد مساهمات معتمدة' : 'No approved contributions',
            subtitle: isArabic
                ? 'المساهمات المعتمدة ستظهر هنا'
                : 'Your approved contributions will appear here',
            isDarkMode: isDarkMode,
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: contributions.length,
          itemBuilder: (context, index) {
            return _buildContributionCard(contributions[index], isArabic, isDarkMode);
          },
        );
      },
    );
  }

  // Build Pending Contributions Tab
  Widget _buildPendingContributions(String userId, bool isArabic, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('contribution_requests')
          .where('contributorId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Error in pending contributions: ${snapshot.error}');
        }

        final gameRequests = snapshot.data?.docs ?? [];

        // Also get fund contribution requests
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('fund_contribution_requests')
              .where('contributorId', isEqualTo: userId)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, fundSnapshot) {
            if (fundSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final fundRequests = fundSnapshot.data?.docs ?? [];
            final allPending = [...gameRequests, ...fundRequests];

            if (allPending.isEmpty) {
              return _buildEmptyState(
                icon: FontAwesomeIcons.clock,
                title: isArabic ? 'لا توجد طلبات معلقة' : 'No pending requests',
                subtitle: isArabic
                    ? 'الطلبات في انتظار الموافقة ستظهر هنا'
                    : 'Requests awaiting approval will appear here',
                isDarkMode: isDarkMode,
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: allPending.length,
              itemBuilder: (context, index) {
                final doc = allPending[index];
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                data['status'] = 'pending';

                // Determine type based on collection
                final isGameRequest = doc.reference.parent.id == 'contribution_requests';
                data['contributionType'] = isGameRequest ? 'game' : 'fund';

                return _buildContributionCard(data, isArabic, isDarkMode);
              },
            );
          },
        );
      },
    );
  }

  // Build Rejected Contributions Tab
  Widget _buildRejectedContributions(String userId, bool isArabic, bool isDarkMode) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getRejectedContributions(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final contributions = snapshot.data ?? [];

        if (contributions.isEmpty) {
          return _buildEmptyState(
            icon: FontAwesomeIcons.timesCircle,
            title: isArabic ? 'لا توجد مساهمات مرفوضة' : 'No rejected contributions',
            subtitle: isArabic
                ? 'المساهمات المرفوضة ستظهر هنا'
                : 'Rejected contributions will appear here',
            isDarkMode: isDarkMode,
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: contributions.length,
          itemBuilder: (context, index) {
            return _buildContributionCard(contributions[index], isArabic, isDarkMode);
          },
        );
      },
    );
  }

  // Get approved contributions from both games collection and approved requests
  Future<List<Map<String, dynamic>>> _getApprovedContributions(String userId) async {
    List<Map<String, dynamic>> contributions = [];

    try {
      // Get approved game contributions from games collection
      final gamesQuery = await _firestore
          .collection('games')
          .where('contributorId', isEqualTo: userId)
          .get();

      for (var doc in gamesQuery.docs) {
        final data = doc.data();
        contributions.add({
          'id': doc.id,
          'contributionType': 'game',
          'gameTitle': data['title'] ?? 'Unknown Game',
          'platform': data['supportedPlatforms']?.first ?? 'PS4/PS5',
          'accountType': data['sharingOptions']?.first ?? 'primary',
          'gameValue': data['gameValue'] ?? 0,
          'status': 'approved',
          'createdAt': data['dateAdded'],
          'approvedAt': data['dateAdded'],
        });
      }

      // Get approved contribution requests
      final approvedGameRequests = await _firestore
          .collection('contribution_requests')
          .where('contributorId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();

      for (var doc in approvedGameRequests.docs) {
        final data = doc.data();
        contributions.add({
          'id': doc.id,
          'contributionType': 'game',
          'gameTitle': data['gameTitle'] ?? 'Unknown Game',
          'platform': data['platform'] ?? 'PS4/PS5',
          'accountType': data['accountType'] ?? 'primary',
          'gameValue': data['gameValue'] ?? 0,
          'status': 'approved',
          'createdAt': data['createdAt'],
          'approvedAt': data['approvedAt'],
        });
      }

      // Get approved fund contributions
      final approvedFundRequests = await _firestore
          .collection('fund_contribution_requests')
          .where('contributorId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();

      for (var doc in approvedFundRequests.docs) {
        final data = doc.data();
        contributions.add({
          'id': doc.id,
          'contributionType': 'fund',
          'gameTitle': data['gameTitle'] ?? 'Fund Contribution',
          'amount': data['amount'] ?? 0,
          'paymentMethod': data['paymentMethod'] ?? 'Unknown',
          'status': 'approved',
          'createdAt': data['createdAt'],
          'approvedAt': data['approvedAt'],
        });
      }
    } catch (e) {
      print('Error fetching approved contributions: $e');
    }

    return contributions;
  }

  // Get rejected contributions
  Future<List<Map<String, dynamic>>> _getRejectedContributions(String userId) async {
    List<Map<String, dynamic>> contributions = [];

    try {
      // Get rejected game contributions
      final rejectedGameRequests = await _firestore
          .collection('contribution_requests')
          .where('contributorId', isEqualTo: userId)
          .where('status', isEqualTo: 'rejected')
          .get();

      for (var doc in rejectedGameRequests.docs) {
        final data = doc.data();
        contributions.add({
          'id': doc.id,
          'contributionType': 'game',
          'gameTitle': data['gameTitle'] ?? 'Unknown Game',
          'platform': data['platform'] ?? 'PS4/PS5',
          'accountType': data['accountType'] ?? 'primary',
          'gameValue': data['gameValue'] ?? 0,
          'status': 'rejected',
          'rejectionReason': data['rejectionReason'],
          'createdAt': data['createdAt'],
          'rejectedAt': data['rejectedAt'],
        });
      }

      // Get rejected fund contributions
      final rejectedFundRequests = await _firestore
          .collection('fund_contribution_requests')
          .where('contributorId', isEqualTo: userId)
          .where('status', isEqualTo: 'rejected')
          .get();

      for (var doc in rejectedFundRequests.docs) {
        final data = doc.data();
        contributions.add({
          'id': doc.id,
          'contributionType': 'fund',
          'gameTitle': data['gameTitle'] ?? 'Fund Contribution',
          'amount': data['amount'] ?? 0,
          'paymentMethod': data['paymentMethod'] ?? 'Unknown',
          'status': 'rejected',
          'rejectionReason': data['rejectionReason'],
          'createdAt': data['createdAt'],
          'rejectedAt': data['rejectedAt'],
        });
      }
    } catch (e) {
      print('Error fetching rejected contributions: $e');
    }

    return contributions;
  }

  // Build contribution card
  Widget _buildContributionCard(Map<String, dynamic> data, bool isArabic, bool isDarkMode) {
    final isGameContribution = data['contributionType'] == 'game';
    final status = data['status'] ?? 'pending';

    // Parse dates safely
    DateTime? createdAt;
    if (data['createdAt'] != null) {
      try {
        if (data['createdAt'] is Timestamp) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        }
      } catch (e) {
        print('Error parsing createdAt: $e');
      }
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  isGameContribution
                      ? FontAwesomeIcons.gamepad
                      : FontAwesomeIcons.dollarSign,
                  size: 20.sp,
                  color: AppTheme.primaryColor,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    data['gameTitle'] ?? 'Contribution',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(status, isArabic),
              ],
            ),
            SizedBox(height: 12.h),

            // Details
            if (isGameContribution) ...[
              _buildInfoRow(
                icon: Icons.devices,
                label: isArabic ? 'المنصة' : 'Platform',
                value: data['platform']?.toString().toUpperCase() ?? 'N/A',
              ),
              _buildInfoRow(
                icon: Icons.category,
                label: isArabic ? 'نوع الحساب' : 'Account Type',
                value: _formatAccountType(data['accountType'], isArabic),
              ),
              _buildInfoRow(
                icon: Icons.attach_money,
                label: isArabic ? 'قيمة اللعبة' : 'Game Value',
                value: '${data['gameValue']?.toStringAsFixed(0) ?? '0'} LE',
              ),
            ] else ...[
              _buildInfoRow(
                icon: Icons.attach_money,
                label: isArabic ? 'المبلغ' : 'Amount',
                value: '${data['amount']?.toStringAsFixed(0) ?? '0'} LE',
              ),
              _buildInfoRow(
                icon: Icons.payment,
                label: isArabic ? 'طريقة الدفع' : 'Payment Method',
                value: data['paymentMethod'] ?? 'N/A',
              ),
            ],

            // Date
            if (createdAt != null) ...[
              SizedBox(height: 8.h),
              _buildInfoRow(
                icon: Icons.calendar_today,
                label: isArabic ? 'التاريخ' : 'Date',
                value: DateFormat('dd MMM yyyy').format(createdAt),
              ),
            ],

            // Rejection reason
            if (status == 'rejected' && data['rejectionReason'] != null) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16.sp,
                      color: AppTheme.errorColor,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        data['rejectionReason'],
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Impact on metrics (for approved game contributions)
            if (status == 'approved' && isGameContribution) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'التأثير على حسابك:' : 'Impact on your account:',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successColor,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      isArabic
                          ? '• حد المحطة: +${data['gameValue']?.toStringAsFixed(0) ?? '0'} LE'
                          : '• Station Limit: +${data['gameValue']?.toStringAsFixed(0) ?? '0'} LE',
                      style: TextStyle(fontSize: 11.sp),
                    ),
                    Text(
                      isArabic
                          ? '• الرصيد: +${((data['gameValue'] ?? 0) * 0.7).toStringAsFixed(0)} LE'
                          : '• Balance: +${((data['gameValue'] ?? 0) * 0.7).toStringAsFixed(0)} LE',
                      style: TextStyle(fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isArabic) {
    Color color;
    String text;

    switch (status.toLowerCase()) {
      case 'approved':
        color = AppTheme.successColor;
        text = isArabic ? 'معتمد' : 'Approved';
        break;
      case 'pending':
        color = AppTheme.warningColor;
        text = isArabic ? 'معلق' : 'Pending';
        break;
      case 'rejected':
        color = AppTheme.errorColor;
        text = isArabic ? 'مرفوض' : 'Rejected';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12.w,
        vertical: 4.h,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12.sp,
        ),
      ),
    );
  }

  String _formatAccountType(String? type, bool isArabic) {
    if (type == null) return 'N/A';

    switch (type.toLowerCase()) {
      case 'primary':
        return isArabic ? 'أساسي' : 'Primary';
      case 'secondary':
        return isArabic ? 'ثانوي' : 'Secondary';
      case 'full':
        return isArabic ? 'كامل' : 'Full';
      case 'psplus':
        return 'PS Plus';
      default:
        return type;
    }
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
            color: AppTheme.primaryColor.withOpacity(0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: isDarkMode
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
}