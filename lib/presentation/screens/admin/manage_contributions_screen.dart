// lib/presentation/screens/admin/manage_contributions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../services/contribution_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/custom_loading.dart';

class ManageContributionsScreen extends StatefulWidget {
  const ManageContributionsScreen({Key? key}) : super(key: key);

  @override
  State<ManageContributionsScreen> createState() => _ManageContributionsScreenState();
}

class _ManageContributionsScreenState extends State<ManageContributionsScreen>
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
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          isArabic ? 'إدارة المساهمات' : 'Manage Contributions',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            isArabic ? Icons.arrow_forward : Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
          tabs: [
            Tab(
              text: isArabic ? 'معلقة' : 'Pending',
              icon: Icon(FontAwesomeIcons.clock, size: 16.sp),
            ),
            Tab(
              text: isArabic ? 'موافق عليها' : 'Approved',
              icon: Icon(FontAwesomeIcons.checkCircle, size: 16.sp),
            ),
            Tab(
              text: isArabic ? 'مرفوضة' : 'Rejected',
              icon: Icon(FontAwesomeIcons.timesCircle, size: 16.sp),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildApprovedTab(),
          _buildRejectedTab(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _contributionService.getPendingContributions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CustomLoading());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No pending contributions');
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildContributionCard(doc.id, data, 'pending');
          },
        );
      },
    );
  }

  Widget _buildApprovedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _contributionService.getApprovedContributions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CustomLoading());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No approved contributions');
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildContributionCard(doc.id, data, 'approved');
          },
        );
      },
    );
  }

  Widget _buildRejectedTab() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('contribution_requests')
          .where('status', isEqualTo: 'rejected')
          .orderBy('rejectedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CustomLoading());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isArabic ? 'لا توجد مساهمات مرفوضة' : 'No rejected contributions');
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildContributionCard(doc.id, data, 'rejected');
          },
        );
      },
    );
  }

  Widget _buildContributionCard(String docId, Map<String, dynamic> data, String status) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    final isGameAccount = data['type'] == 'game_account';
    final submittedAt = data['submittedAt'] != null
        ? (data['submittedAt'] as Timestamp).toDate()
        : DateTime.now();

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: isGameAccount
                ? AppTheme.primaryColor.withOpacity(0.1)
                : AppTheme.secondaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            isGameAccount ? FontAwesomeIcons.gamepad : FontAwesomeIcons.dollarSign,
            color: isGameAccount ? AppTheme.primaryColor : AppTheme.secondaryColor,
            size: 20.sp,
          ),
        ),
        title: Text(
          isGameAccount ? data['gameTitle'] ?? 'Unknown Game' : 'Fund Contribution',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isArabic ? "بواسطة:" : "By:"} ${data['userName'] ?? 'Unknown'}',
              style: TextStyle(fontSize: 14.sp),
            ),
            if (isGameAccount) ...[
              Text(
                '${isArabic ? "القيمة:" : "Value:"} ${data['gameValue']} LE',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else ...[
              Text(
                '${isArabic ? "المبلغ:" : "Amount:"} ${data['amount']} LE',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            Text(
              _formatDate(submittedAt),
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isGameAccount) ...[
                  _buildDetailRow(
                    isArabic ? 'المنصات' : 'Platforms',
                    (data['platforms'] as List?)?.join(', ') ?? 'N/A',
                  ),
                  _buildDetailRow(
                    isArabic ? 'خيارات المشاركة' : 'Sharing Options',
                    (data['sharingOptions'] as List?)?.join(', ') ?? 'N/A',
                  ),
                  _buildDetailRow(
                    isArabic ? 'الإصدار' : 'Edition',
                    data['edition'] ?? 'Standard',
                  ),
                  _buildDetailRow(
                    isArabic ? 'المنطقة' : 'Region',
                    data['region'] ?? 'US',
                  ),
                  if (data['includedTitles'] != null) ...[
                    _buildDetailRow(
                      isArabic ? 'العناوين المضمنة' : 'Included Titles',
                      (data['includedTitles'] as List).join(', '),
                    ),
                  ],
                  _buildDetailRow(
                    isArabic ? 'البريد الإلكتروني' : 'Email',
                    data['credentials']?['email'] ?? 'N/A',
                  ),
                  _buildDetailRow(
                    isArabic ? 'كلمة المرور' : 'Password',
                    '********',
                  ),
                ],
                if (!isGameAccount && data['notes'] != null) ...[
                  _buildDetailRow(
                    isArabic ? 'ملاحظات' : 'Notes',
                    data['notes'],
                  ),
                ],
                if (status == 'rejected' && data['rejectionReason'] != null) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppTheme.errorColor,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            '${isArabic ? "سبب الرفض:" : "Rejection Reason:"} ${data['rejectionReason']}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (status == 'pending') ...[
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveContribution(docId, isGameAccount),
                          icon: Icon(FontAwesomeIcons.check, size: 16.sp),
                          label: Text(isArabic ? 'موافقة' : 'Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRejectDialog(docId),
                          icon: Icon(FontAwesomeIcons.times, size: 16.sp),
                          label: Text(isArabic ? 'رفض' : 'Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.folderOpen,
            size: 64.sp,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16.h),
          Text(
            isArabic && message.contains('pending')
                ? 'لا توجد مساهمات معلقة'
                : isArabic && message.contains('approved')
                ? 'لا توجد مساهمات موافق عليها'
                : message,
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _approveContribution(String docId, bool isGameAccount) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CustomLoading()),
    );

    final result = isGameAccount
        ? await _contributionService.approveGameContribution(docId)
        : await _contributionService.approveFundContribution(docId);

    Navigator.pop(context); // Close loading dialog

    if (result['success']) {
      Fluttertoast.showToast(
        msg: isArabic ? 'تمت الموافقة على المساهمة بنجاح!' : result['message'],
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.successColor,
        textColor: Colors.white,
      );
    } else {
      Fluttertoast.showToast(
        msg: result['message'] ?? 'Failed to approve contribution',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.errorColor,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _showRejectDialog(String docId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'رفض المساهمة' : 'Reject Contribution'),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: isArabic ? 'سبب الرفض' : 'Rejection Reason',
            hintText: isArabic
                ? 'أدخل سبب رفض المساهمة'
                : 'Enter reason for rejection',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                Fluttertoast.showToast(
                  msg: isArabic
                      ? 'يرجى إدخال سبب الرفض'
                      : 'Please enter rejection reason',
                  backgroundColor: AppTheme.warningColor,
                );
                return;
              }

              Navigator.pop(context);

              // Show loading
              showDialog(
                context: this.context,
                barrierDismissible: false,
                builder: (context) => Center(child: CustomLoading()),
              );

              final result = await _contributionService.rejectContribution(
                docId,
                reasonController.text.trim(),
              );

              Navigator.pop(this.context); // Close loading

              if (result['success']) {
                Fluttertoast.showToast(
                  msg: isArabic ? 'تم رفض المساهمة' : result['message'],
                  backgroundColor: AppTheme.warningColor,
                  textColor: Colors.white,
                );
              } else {
                Fluttertoast.showToast(
                  msg: result['message'] ?? 'Failed to reject contribution',
                  backgroundColor: AppTheme.errorColor,
                  textColor: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(isArabic ? 'رفض' : 'Reject'),
          ),
        ],
      ),
    );
  }
}