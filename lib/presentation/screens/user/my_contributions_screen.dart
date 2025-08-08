import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../user/add_contribution_screen.dart';

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

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          isArabic ? 'مساهماتي' : 'My Contributions',
          style: TextStyle(
            color: isDarkMode ? Colors.white : AppTheme.darkBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: isArabic ? 'الألعاب' : 'Games'),
            Tab(text: isArabic ? 'التمويل' : 'Funds'),
            Tab(text: isArabic ? 'المعلقة' : 'Pending'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGameContributions(user?.uid),
          _buildFundContributions(user?.uid),
          _buildPendingContributions(user?.uid),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddContributionScreen(),
            ),
          );
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

  Widget _buildGameContributions(String? userId) {
    if (userId == null) {
      return Center(child: Text('Please login first'));
    }

    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('games')
          .where('contributors', arrayContains: {
        'userId': userId,
      })
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              isArabic ? 'خطأ في تحميل المساهمات' : 'Error loading contributions',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          );
        }

        final games = snapshot.data?.docs ?? [];

        if (games.isEmpty) {
          return _buildEmptyState(
            icon: FontAwesomeIcons.gamepad,
            title: isArabic ? 'لا توجد مساهمات ألعاب' : 'No game contributions',
            subtitle: isArabic
                ? 'ابدأ بالمساهمة بلعبة لزيادة حد المحطة'
                : 'Start contributing games to increase your Station Limit',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final data = games[index].data() as Map<String, dynamic>;

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
                            data['title'] ?? 'Unknown Game',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            isArabic ? 'نشط' : 'Active',
                            style: TextStyle(
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    _buildInfoRow(
                      icon: Icons.devices,
                      label: isArabic ? 'المنصات' : 'Platforms',
                      value: (data['supportedPlatforms'] as List?)
                          ?.map((p) => p.toString().toUpperCase())
                          .join(', ') ?? 'N/A',
                    ),
                    _buildInfoRow(
                      icon: Icons.attach_money,
                      label: isArabic ? 'قيمة اللعبة' : 'Game Value',
                      value: '${data['gameValue']?.toStringAsFixed(0) ?? '0'} LE',
                    ),
                    _buildInfoRow(
                      icon: Icons.people,
                      label: isArabic ? 'إجمالي الاستعارات' : 'Total Borrows',
                      value: '${data['totalBorrows'] ?? 0}',
                    ),
                    _buildInfoRow(
                      icon: Icons.trending_up,
                      label: isArabic ? 'الإيرادات المكتسبة' : 'Revenue Earned',
                      value: '${data['borrowRevenue']?.toStringAsFixed(0) ?? '0'} LE',
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

  Widget _buildFundContributions(String? userId) {
    if (userId == null) {
      return Center(child: Text('Please login first'));
    }

    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('fund_contributions')
          .where('contributorId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .orderBy('approvedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              isArabic ? 'خطأ في تحميل المساهمات' : 'Error loading contributions',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          );
        }

        final funds = snapshot.data?.docs ?? [];

        if (funds.isEmpty) {
          return _buildEmptyState(
            icon: FontAwesomeIcons.dollarSign,
            title: isArabic ? 'لا توجد مساهمات مالية' : 'No fund contributions',
            subtitle: isArabic
                ? 'ساهم في شراء ألعاب جديدة للمكتبة'
                : 'Contribute to purchasing new games for the library',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: funds.length,
          itemBuilder: (context, index) {
            final data = funds[index].data() as Map<String, dynamic>;
            final approvedAt = (data['approvedAt'] as Timestamp?)?.toDate();

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
                          data['gameTitle'] ?? 'Fund Contribution',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${data['amount']?.toStringAsFixed(0) ?? '0'} LE',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    _buildInfoRow(
                      icon: Icons.payment,
                      label: isArabic ? 'طريقة الدفع' : 'Payment Method',
                      value: data['paymentMethod'] ?? 'Unknown',
                    ),
                    if (approvedAt != null)
                      _buildInfoRow(
                        icon: Icons.calendar_today,
                        label: isArabic ? 'تاريخ الموافقة' : 'Approved Date',
                        value: DateFormat('dd MMM yyyy').format(approvedAt),
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

  Widget _buildPendingContributions(String? userId) {
    if (userId == null) {
      return Center(child: Text('Please login first'));
    }

    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('contribution_requests')
          .where('contributorId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final gameRequests = snapshot.data?.docs ?? [];

        // Also get fund contribution requests
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('fund_contribution_requests')
              .where('contributorId', isEqualTo: userId)
              .where('status', isEqualTo: 'pending')
              .orderBy('createdAt', descending: true)
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
                    ? 'جميع مساهماتك تمت الموافقة عليها'
                    : 'All your contributions have been approved',
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: allPending.length,
              itemBuilder: (context, index) {
                final doc = allPending[index];
                final data = doc.data() as Map<String, dynamic>;
                final isGameRequest = doc.reference.parent.id == 'contribution_requests';
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

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
                          children: [
                            Icon(
                              isGameRequest
                                  ? FontAwesomeIcons.gamepad
                                  : FontAwesomeIcons.dollarSign,
                              size: 20.sp,
                              color: AppTheme.primaryColor,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                data['gameTitle'] ?? 'Contribution Request',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                isArabic ? 'معلق' : 'Pending',
                                style: TextStyle(
                                  color: AppTheme.warningColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        _buildInfoRow(
                          icon: Icons.category,
                          label: isArabic ? 'النوع' : 'Type',
                          value: isGameRequest
                              ? (data['accountType'] ?? 'Game')
                              : (isArabic ? 'مساهمة مالية' : 'Fund Contribution'),
                        ),
                        if (!isGameRequest)
                          _buildInfoRow(
                            icon: Icons.attach_money,
                            label: isArabic ? 'المبلغ' : 'Amount',
                            value: '${data['amount']?.toStringAsFixed(0) ?? '0'} LE',
                          ),
                        if (createdAt != null)
                          _buildInfoRow(
                            icon: Icons.access_time,
                            label: isArabic ? 'تاريخ الطلب' : 'Request Date',
                            value: DateFormat('dd MMM yyyy, HH:mm').format(createdAt),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDarkMode = Provider.of<AppProvider>(context).isDarkMode;

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