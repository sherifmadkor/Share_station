// lib/presentation/screens/admin/manage_return_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../../services/return_request_service.dart';
import '../../widgets/custom_loading.dart';

class ManageReturnRequestsScreen extends StatefulWidget {
  const ManageReturnRequestsScreen({Key? key}) : super(key: key);

  @override
  State<ManageReturnRequestsScreen> createState() => _ManageReturnRequestsScreenState();
}

class _ManageReturnRequestsScreenState extends State<ManageReturnRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ReturnRequestService _returnService = ReturnRequestService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          isArabic ? 'إدارة طلبات الإرجاع' : 'Manage Return Requests',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: Icon(Icons.pending_actions),
              text: isArabic ? 'معلقة' : 'Pending',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: isArabic ? 'السجل' : 'History',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingReturns(isArabic, isDarkMode),
          _buildReturnHistory(isArabic, isDarkMode),
        ],
      ),
    );
  }

  // Pending Returns Tab
  Widget _buildPendingReturns(bool isArabic, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _returnService.getPendingReturnRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48.sp, color: AppTheme.errorColor),
                SizedBox(height: 16.h),
                Text(
                  isArabic ? 'خطأ في تحميل البيانات' : 'Error loading data',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
              ],
            ),
          );
        }

        final returns = snapshot.data?.docs ?? [];

        if (returns.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_return,
                  size: 64.sp,
                  color: Colors.grey.withOpacity(0.5),
                ),
                SizedBox(height: 16.h),
                Text(
                  isArabic
                      ? 'لا توجد طلبات إرجاع معلقة'
                      : 'No pending return requests',
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
          itemCount: returns.length,
          itemBuilder: (context, index) {
            final doc = returns[index];
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final borrowDate = (data['borrowDate'] as Timestamp?)?.toDate();

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
                    // Header with game title and status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['gameTitle'] ?? 'Unknown Game',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                data['userName'] ?? 'Unknown User',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
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
                            isArabic ? 'معلق' : 'PENDING',
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
                    Divider(),
                    SizedBox(height: 12.h),

                    // Details Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.devices,
                            label: isArabic ? 'المنصة' : 'Platform',
                            value: '${data['platform']?.toUpperCase() ?? 'PS4'}',
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.account_box,
                            label: isArabic ? 'نوع الحساب' : 'Account',
                            value: data['accountType'] ?? 'Primary',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.monetization_on,
                            label: isArabic ? 'قيمة الاستعارة' : 'Borrow Value',
                            value: '${data['borrowValue']?.toStringAsFixed(0) ?? '0'} LE',
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.calendar_today,
                            label: isArabic ? 'تاريخ الاستعارة' : 'Borrowed',
                            value: borrowDate != null
                                ? DateFormat('dd/MM').format(borrowDate)
                                : 'N/A',
                          ),
                        ),
                      ],
                    ),

                    if (borrowDate != null) ...[
                      SizedBox(height: 12.h),
                      _buildInfoItem(
                        icon: Icons.timer,
                        label: isArabic ? 'مدة الاستعارة' : 'Hold Period',
                        value: isArabic
                            ? '${DateTime.now().difference(borrowDate).inDays} يوم'
                            : '${DateTime.now().difference(borrowDate).inDays} days',
                      ),
                    ],

                    SizedBox(height: 16.h),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveReturn(doc.id),
                            icon: Icon(Icons.check_circle, size: 18.sp),
                            label: Text(
                              isArabic ? 'موافقة' : 'Approve',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
                          child: OutlinedButton.icon(
                            onPressed: () => _showRejectDialog(doc.id),
                            icon: Icon(Icons.cancel, size: 18.sp),
                            label: Text(
                              isArabic ? 'رفض' : 'Reject',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.errorColor,
                              side: BorderSide(color: AppTheme.errorColor),
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  // History Tab
  Widget _buildReturnHistory(bool isArabic, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _returnService.getReturnHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final history = snapshot.data?.docs ?? [];

        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64.sp,
                  color: Colors.grey.withOpacity(0.5),
                ),
                SizedBox(height: 16.h),
                Text(
                  isArabic ? 'لا يوجد سجل' : 'No history',
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
          itemCount: history.length,
          itemBuilder: (context, index) {
            final data = history[index].data() as Map<String, dynamic>;
            final status = data['status'];
            final processedAt = status == 'approved'
                ? (data['approvedAt'] as Timestamp?)?.toDate()
                : (data['rejectedAt'] as Timestamp?)?.toDate();

            return Card(
              margin: EdgeInsets.only(bottom: 12.h),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: status == 'approved'
                      ? AppTheme.successColor.withOpacity(0.2)
                      : AppTheme.errorColor.withOpacity(0.2),
                  child: Icon(
                    status == 'approved' ? Icons.check : Icons.close,
                    color: status == 'approved'
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                ),
                title: Text(
                  data['gameTitle'] ?? 'Unknown Game',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['userName'] ?? 'Unknown User'),
                    if (processedAt != null)
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(processedAt),
                        style: TextStyle(fontSize: 12.sp),
                      ),
                    if (status == 'rejected' && data['rejectionReason'] != null)
                      Text(
                        '${isArabic ? "السبب" : "Reason"}: ${data['rejectionReason']}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.errorColor,
                        ),
                      ),
                  ],
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'approved'
                        ? AppTheme.successColor.withOpacity(0.2)
                        : AppTheme.errorColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    status == 'approved'
                        ? (isArabic ? 'موافق' : 'Approved')
                        : (isArabic ? 'مرفوض' : 'Rejected'),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: status == 'approved'
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper Widget
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: AppTheme.primaryColor),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Actions
  Future<void> _approveReturn(String returnRequestId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تأكيد الموافقة' : 'Confirm Approval'),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من الموافقة على طلب الإرجاع؟\nسيتم إتاحة اللعبة للاستعارة مرة أخرى.'
              : 'Are you sure you want to approve this return?\nThe game will become available for borrowing again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: Text(isArabic ? 'موافقة' : 'Approve'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CustomLoading()),
    );

    final result = await _returnService.approveReturnRequest(returnRequestId);

    Navigator.pop(context); // Close loading

    if (result['success']) {
      Fluttertoast.showToast(
        msg: isArabic
            ? 'تمت الموافقة على الإرجاع! اللعبة متاحة الآن.'
            : result['message'],
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: AppTheme.successColor,
        textColor: Colors.white,
      );
    } else {
      Fluttertoast.showToast(
        msg: result['message'] ?? 'Failed to approve return',
        backgroundColor: AppTheme.errorColor,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _showRejectDialog(String returnRequestId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'رفض طلب الإرجاع' : 'Reject Return Request'),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: isArabic ? 'سبب الرفض' : 'Rejection Reason',
            hintText: isArabic
                ? 'أدخل سبب رفض الطلب'
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

              final result = await _returnService.rejectReturnRequest(
                returnRequestId,
                reasonController.text.trim(),
              );

              Navigator.pop(this.context); // Close loading

              if (result['success']) {
                Fluttertoast.showToast(
                  msg: isArabic
                      ? 'تم رفض طلب الإرجاع'
                      : 'Return request rejected',
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