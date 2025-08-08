import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/contribution_model.dart';
import '../../../services/contribution_service.dart';
import '../user/add_contribution_screen.dart';

class MyContributionsScreen extends StatefulWidget {
  const MyContributionsScreen({Key? key}) : super(key: key);

  @override
  State<MyContributionsScreen> createState() => _MyContributionsScreenState();
}

class _MyContributionsScreenState extends State<MyContributionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ContributionService _contributionService = ContributionService();

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
        body: Center(
          child: Text(isArabic ? 'الرجاء تسجيل الدخول' : 'Please login first'),
        ),
      );
    }

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
            Tab(text: isArabic ? 'المعتمدة' : 'Approved'),
            Tab(text: isArabic ? 'المعلقة' : 'Pending'),
            Tab(text: isArabic ? 'المرفوضة' : 'Rejected'),
          ],
        ),
      ),
      body: StreamBuilder<List<ContributionModel>>(
        stream: _contributionService.getUserContributions(user.uid),
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

          final allContributions = snapshot.data ?? [];

          // Filter contributions by status
          final approvedContributions = allContributions
              .where((c) => c.status == ContributionStatus.approved)
              .toList();
          final pendingContributions = allContributions
              .where((c) => c.status == ContributionStatus.pending)
              .toList();
          final rejectedContributions = allContributions
              .where((c) => c.status == ContributionStatus.rejected)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildContributionList(approvedContributions, ContributionStatus.approved),
              _buildContributionList(pendingContributions, ContributionStatus.pending),
              _buildContributionList(rejectedContributions, ContributionStatus.rejected),
            ],
          );
        },
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

  Widget _buildContributionList(List<ContributionModel> contributions, ContributionStatus status) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    if (contributions.isEmpty) {
      return _buildEmptyState(
        icon: _getStatusIcon(status),
        title: _getEmptyTitle(status, isArabic),
        subtitle: _getEmptySubtitle(status, isArabic),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: contributions.length,
      itemBuilder: (context, index) {
        final contribution = contributions[index];

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
                // Header
                Row(
                  children: [
                    Icon(
                      contribution.type == ContributionType.game
                          ? FontAwesomeIcons.gamepad
                          : FontAwesomeIcons.dollarSign,
                      size: 20.sp,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        contribution.gameTitle ?? contribution.targetGameTitle ?? 'Contribution',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStatusBadge(contribution.status, isArabic),
                  ],
                ),
                SizedBox(height: 12.h),

                // Contribution Details
                if (contribution.type == ContributionType.game) ...[
                  _buildInfoRow(
                    icon: Icons.devices,
                    label: isArabic ? 'المنصة' : 'Platform',
                    value: contribution.platform?.toUpperCase() ?? 'N/A',
                  ),
                  _buildInfoRow(
                    icon: Icons.category,
                    label: isArabic ? 'نوع الحساب' : 'Account Type',
                    value: contribution.accountType ?? 'N/A',
                  ),
                  _buildInfoRow(
                    icon: Icons.attach_money,
                    label: isArabic ? 'قيمة اللعبة' : 'Game Value',
                    value: '${contribution.gameValue?.toStringAsFixed(0) ?? '0'} LE',
                  ),
                ] else ...[
                  _buildInfoRow(
                    icon: Icons.attach_money,
                    label: isArabic ? 'المبلغ' : 'Amount',
                    value: '${contribution.fundAmount?.toStringAsFixed(0) ?? '0'} LE',
                  ),
                  _buildInfoRow(
                    icon: Icons.payment,
                    label: isArabic ? 'طريقة الدفع' : 'Payment Method',
                    value: contribution.paymentMethod ?? 'N/A',
                  ),
                ],

                // Status-specific information
                if (contribution.status == ContributionStatus.approved) ...[
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
                        if (contribution.type == ContributionType.game) ...[
                          Text(
                            isArabic
                                ? '• حد المحطة: +${contribution.gameValue?.toStringAsFixed(0) ?? '0'} LE'
                                : '• Station Limit: +${contribution.gameValue?.toStringAsFixed(0) ?? '0'} LE',
                            style: TextStyle(fontSize: 11.sp),
                          ),
                          Text(
                            isArabic
                                ? '• الرصيد: +${((contribution.gameValue ?? 0) * 0.7).toStringAsFixed(0)} LE'
                                : '• Balance: +${((contribution.gameValue ?? 0) * 0.7).toStringAsFixed(0)} LE',
                            style: TextStyle(fontSize: 11.sp),
                          ),
                          Text(
                            isArabic
                                ? '• حصص الألعاب: +1'
                                : '• Game Shares: +1',
                            style: TextStyle(fontSize: 11.sp),
                          ),
                        ] else ...[
                          Text(
                            isArabic
                                ? '• حصص التمويل: +${((contribution.fundAmount ?? 0) / 100).round()}'
                                : '• Fund Shares: +${((contribution.fundAmount ?? 0) / 100).round()}',
                            style: TextStyle(fontSize: 11.sp),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                if (contribution.status == ContributionStatus.rejected &&
                    contribution.rejectionReason != null) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16.sp,
                          color: AppTheme.errorColor,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            contribution.rejectionReason!,
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

                // Dates
                SizedBox(height: 8.h),
                _buildInfoRow(
                  icon: Icons.calendar_today,
                  label: isArabic ? 'تاريخ الإرسال' : 'Submitted',
                  value: DateFormat('dd MMM yyyy').format(contribution.createdAt),
                ),
                if (contribution.approvedAt != null)
                  _buildInfoRow(
                    icon: Icons.check_circle,
                    label: isArabic ? 'تاريخ الموافقة' : 'Approved',
                    value: DateFormat('dd MMM yyyy').format(contribution.approvedAt!),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(ContributionStatus status, bool isArabic) {
    Color color;
    String text;

    switch (status) {
      case ContributionStatus.approved:
        color = AppTheme.successColor;
        text = isArabic ? 'معتمد' : 'Approved';
        break;
      case ContributionStatus.pending:
        color = AppTheme.warningColor;
        text = isArabic ? 'معلق' : 'Pending';
        break;
      case ContributionStatus.rejected:
        color = AppTheme.errorColor;
        text = isArabic ? 'مرفوض' : 'Rejected';
        break;
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

  IconData _getStatusIcon(ContributionStatus status) {
    switch (status) {
      case ContributionStatus.approved:
        return FontAwesomeIcons.checkCircle;
      case ContributionStatus.pending:
        return FontAwesomeIcons.clock;
      case ContributionStatus.rejected:
        return FontAwesomeIcons.timesCircle;
    }
  }

  String _getEmptyTitle(ContributionStatus status, bool isArabic) {
    switch (status) {
      case ContributionStatus.approved:
        return isArabic ? 'لا توجد مساهمات معتمدة' : 'No approved contributions';
      case ContributionStatus.pending:
        return isArabic ? 'لا توجد مساهمات معلقة' : 'No pending contributions';
      case ContributionStatus.rejected:
        return isArabic ? 'لا توجد مساهمات مرفوضة' : 'No rejected contributions';
    }
  }

  String _getEmptySubtitle(ContributionStatus status, bool isArabic) {
    switch (status) {
      case ContributionStatus.approved:
        return isArabic
            ? 'ساهم بالألعاب أو التمويل لتحسين مكانتك'
            : 'Contribute games or funds to improve your standing';
      case ContributionStatus.pending:
        return isArabic
            ? 'لا توجد مساهمات في انتظار الموافقة'
            : 'No contributions awaiting approval';
      case ContributionStatus.rejected:
        return isArabic
            ? 'لا توجد مساهمات مرفوضة'
            : 'No rejected contributions';
    }
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