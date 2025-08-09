// lib/presentation/screens/admin/manage_borrow_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../services/borrow_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/custom_loading.dart';

class ManageBorrowRequestsScreen extends StatefulWidget {
  const ManageBorrowRequestsScreen({Key? key}) : super(key: key);

  @override
  State<ManageBorrowRequestsScreen> createState() => _ManageBorrowRequestsScreenState();
}

class _ManageBorrowRequestsScreenState extends State<ManageBorrowRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BorrowService _borrowService = BorrowService();

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
          isArabic ? 'إدارة طلبات الاستعارة' : 'Manage Borrow Requests',
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
              text: isArabic ? 'نشطة' : 'Active',
              icon: Icon(FontAwesomeIcons.gamepad, size: 16.sp),
            ),
            Tab(
              text: isArabic ? 'السجل' : 'History',
              icon: Icon(FontAwesomeIcons.history, size: 16.sp),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildActiveTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _borrowService.getPendingBorrowRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CustomLoading());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No pending borrow requests');
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildBorrowCard(data, 'pending');
          },
        );
      },
    );
  }

  Widget _buildActiveTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _borrowService.getActiveBorrows(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CustomLoading());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No active borrows');
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildBorrowCard(data, 'active');
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('borrow_requests')
          .where('status', whereIn: ['returned', 'rejected'])
          .orderBy('requestDate', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CustomLoading());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isArabic ? 'لا يوجد سجل' : 'No history');
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildBorrowCard(data, 'history');
          },
        );
      },
    );
  }

  Widget _buildBorrowCard(Map<String, dynamic> data, String status) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    final requestDate = data['requestDate'] != null
        ? (data['requestDate'] as Timestamp).toDate()
        : DateTime.now();

    Color statusColor = AppTheme.warningColor;
    String statusText = isArabic ? 'معلق' : 'Pending';

    if (status == 'active' || data['status'] == 'approved') {
      statusColor = AppTheme.successColor;
      statusText = isArabic ? 'نشط' : 'Active';
    } else if (data['status'] == 'returned') {
      statusColor = AppTheme.infoColor;
      statusText = isArabic ? 'مُرجع' : 'Returned';
    } else if (data['status'] == 'rejected') {
      statusColor = AppTheme.errorColor;
      statusText = isArabic ? 'مرفوض' : 'Rejected';
    }

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
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            FontAwesomeIcons.gamepad,
            color: statusColor,
            size: 20.sp,
          ),
        ),
        title: Text(
          data['gameTitle'] ?? 'Unknown Game',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isArabic ? "المستخدم:" : "User:"} ${data['userName'] ?? 'Unknown'}',
              style: TextStyle(fontSize: 14.sp),
            ),
            Row(
              children: [
                Text(
                  '${isArabic ? "القيمة:" : "Value:"} ${data['borrowValue']} LE',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              _formatDate(requestDate),
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
                _buildDetailRow(
                  isArabic ? 'المنصة' : 'Platform',
                  data['platform']?.toUpperCase() ?? 'N/A',
                ),
                _buildDetailRow(
                  isArabic ? 'نوع الحساب' : 'Account Type',
                  data['accountType'] ?? 'N/A',
                ),
                _buildDetailRow(
                  isArabic ? 'معرف المستخدم' : 'User ID',
                  data['userId'] ?? 'N/A',
                ),

                if (data['status'] == 'approved' && data['approvalDate'] != null) ...[
                  _buildDetailRow(
                    isArabic ? 'تاريخ الموافقة' : 'Approval Date',
                    _formatDate((data['approvalDate'] as Timestamp).toDate()),
                  ),
                ],

                if (data['status'] == 'returned' && data['returnDate'] != null) ...[
                  _buildDetailRow(
                    isArabic ? 'تاريخ الإرجاع' : 'Return Date',
                    _formatDate((data['returnDate'] as Timestamp).toDate()),
                  ),
                  if (data['holdPeriod'] != null) ...[
                    _buildDetailRow(
                      isArabic ? 'فترة الاحتفاظ' : 'Hold Period',
                      '${data['holdPeriod']} ${isArabic ? "يوم" : "days"}',
                    ),
                  ],
                ],

                if (data['status'] == 'rejected' && data['rejectionReason'] != null) ...[
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

                // Action buttons
                if (status == 'pending') ...[
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveBorrowRequest(data['requestId']),
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
                          onPressed: () => _showRejectDialog(data['requestId']),
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
                ] else if (status == 'active' || data['status'] == 'approved') ...[
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _returnGame(data['requestId']),
                      icon: Icon(FontAwesomeIcons.undoAlt, size: 16.sp),
                      label: Text(isArabic ? 'تسجيل الإرجاع' : 'Mark as Returned'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.infoColor,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
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
            FontAwesomeIcons.inbox,
            size: 64.sp,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16.h),
          Text(
            message,
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

  Future<void> _approveBorrowRequest(String requestId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تأكيد الموافقة' : 'Confirm Approval'),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من الموافقة على طلب الاستعارة هذا؟'
              : 'Are you sure you want to approve this borrow request?',
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

    final result = await _borrowService.approveBorrowRequest(requestId);

    Navigator.pop(context); // Close loading

    if (result['success']) {
      Fluttertoast.showToast(
        msg: isArabic ? 'تمت الموافقة على طلب الاستعارة!' : result['message'],
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.successColor,
        textColor: Colors.white,
      );
    } else {
      Fluttertoast.showToast(
        msg: result['message'] ?? 'Failed to approve request',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.errorColor,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _returnGame(String requestId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تأكيد الإرجاع' : 'Confirm Return'),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من تسجيل إرجاع هذه اللعبة؟'
              : 'Are you sure you want to mark this game as returned?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.infoColor,
            ),
            child: Text(isArabic ? 'تأكيد' : 'Confirm'),
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

    final result = await _borrowService.returnBorrowedGame(requestId);

    Navigator.pop(context); // Close loading

    if (result['success']) {
      Fluttertoast.showToast(
        msg: isArabic ? 'تم تسجيل إرجاع اللعبة بنجاح!' : result['message'],
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.successColor,
        textColor: Colors.white,
      );
    } else {
      Fluttertoast.showToast(
        msg: result['message'] ?? 'Failed to return game',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.errorColor,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _showRejectDialog(String requestId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'رفض طلب الاستعارة' : 'Reject Borrow Request'),
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

              final result = await _borrowService.rejectBorrowRequest(
                requestId,
                reasonController.text.trim(),
              );

              Navigator.pop(this.context); // Close loading

              if (result['success']) {
                Fluttertoast.showToast(
                  msg: isArabic ? 'تم رفض طلب الاستعارة' : result['message'],
                  backgroundColor: AppTheme.warningColor,
                  textColor: Colors.white,
                );
              } else {
                Fluttertoast.showToast(
                  msg: result['message'] ?? 'Failed to reject request',
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