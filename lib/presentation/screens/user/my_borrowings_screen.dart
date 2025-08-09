import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class MyBorrowingsScreen extends StatefulWidget {
  const MyBorrowingsScreen({Key? key}) : super(key: key);

  @override
  State<MyBorrowingsScreen> createState() => _MyBorrowingsScreenState();
}

class _MyBorrowingsScreenState extends State<MyBorrowingsScreen>
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

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          isArabic ? 'استعاراتي' : 'My Borrowings',
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
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14.sp,
          ),
          tabs: [
            Tab(text: isArabic ? 'النشطة' : 'Active'),
            Tab(text: isArabic ? 'المعلقة' : 'Pending'),
            Tab(text: isArabic ? 'السجل' : 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveBorrowings(),
          _buildPendingBorrowings(),
          _buildBorrowingHistory(),
        ],
      ),
    );
  }

  // Active Borrowings Tab
  Widget _buildActiveBorrowings() {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final user = authProvider.currentUser;

    if (user == null) {
      return Center(
        child: Text(
          isArabic ? 'يرجى تسجيل الدخول أولاً' : 'Please login first',
          style: TextStyle(fontSize: 16.sp),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('borrow_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Active borrowings error: ${snapshot.error}');
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
                  isArabic ? 'خطأ في تحميل البيانات' : 'Error loading data',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                SizedBox(height: 8.h),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: 12.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                ),
              ],
            ),
          );
        }

        final allBorrows = snapshot.data?.docs ?? [];
        
        // Sort by requestDate or approvedAt in descending order (newest first)
        final borrows = allBorrows..sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final dateA = (dataA['approvedAt'] as Timestamp?)?.toDate() ?? (dataA['requestDate'] as Timestamp?)?.toDate() ?? DateTime(2020);
          final dateB = (dataB['approvedAt'] as Timestamp?)?.toDate() ?? (dataB['requestDate'] as Timestamp?)?.toDate() ?? DateTime(2020);
          return dateB.compareTo(dateA);
        });

        if (borrows.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.gamepad,
                  size: 64.sp,
                  color: Colors.grey.withAlpha(128),
                ),
                SizedBox(height: 16.h),
                Text(
                  isArabic ? 'لا توجد استعارات نشطة' : 'No active borrowings',
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  isArabic
                      ? 'الألعاب التي تستعيرها حالياً ستظهر هنا'
                      : 'Games you are currently borrowing will appear here',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.withAlpha(179),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: borrows.length,
          itemBuilder: (context, index) {
            final doc = borrows[index];
            final data = doc.data() as Map<String, dynamic>;
            final borrowDate = (data['approvedAt'] as Timestamp?)?.toDate() ?? (data['requestDate'] as Timestamp?)?.toDate();
            final daysRemaining = 30 - (borrowDate != null
                ? DateTime.now().difference(borrowDate).inDays
                : 0);

            return Card(
              margin: EdgeInsets.only(bottom: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(12.w),
                leading: Container(
                  width: 60.w,
                  height: 60.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.r),
                    color: AppTheme.primaryColor.withAlpha(26),
                  ),
                  child: Icon(
                    FontAwesomeIcons.gamepad,
                    color: AppTheme.primaryColor,
                    size: 28.sp,
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
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(Icons.devices, size: 14.sp, color: Colors.grey),
                        SizedBox(width: 4.w),
                        Text(
                          '${data['platform']?.toUpperCase() ?? 'PS4'} • ${data['accountType'] ?? 'Primary'}',
                          style: TextStyle(fontSize: 12.sp),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(Icons.timer, size: 14.sp, color: AppTheme.warningColor),
                        SizedBox(width: 4.w),
                        Text(
                          isArabic
                              ? 'متبقي: $daysRemaining يوم'
                              : 'Remaining: $daysRemaining days',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: daysRemaining < 7
                                ? AppTheme.errorColor
                                : AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 20.sp),
                          SizedBox(width: 8.w),
                          Text(isArabic ? 'التفاصيل' : 'Details'),
                        ],
                      ),
                      value: 'details',
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.assignment_return, size: 20.sp, color: AppTheme.warningColor),
                          SizedBox(width: 8.w),
                          Text(isArabic ? 'إرجاع' : 'Return'),
                        ],
                      ),
                      value: 'return',
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'return') {
                      _submitReturnRequest(doc.id, data);
                    } else if (value == 'details') {
                      _showBorrowDetails(data);
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Pending Borrowings Tab - FIXED VERSION
  Widget _buildPendingBorrowings() {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final user = authProvider.currentUser;

    if (user == null) {
      return Center(
        child: Text(
          isArabic ? 'يرجى تسجيل الدخول أولاً' : 'Please login first',
          style: TextStyle(fontSize: 16.sp),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('borrow_requests')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Error loading pending borrows: ${snapshot.error}');
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
                  isArabic ? 'خطأ في تحميل البيانات' : 'Error loading data',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {}); // Retry
                  },
                  child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                ),
              ],
            ),
          );
        }

        // Filter for pending and queued status in memory, then sort
        final allRequests = snapshot.data?.docs ?? [];
        final pendingRequests = allRequests.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'pending' || data['status'] == 'queued';
        }).toList()..sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final dateA = (dataA['requestDate'] as Timestamp?)?.toDate() ?? (dataA['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2020);
          final dateB = (dataB['requestDate'] as Timestamp?)?.toDate() ?? (dataB['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2020);
          return dateB.compareTo(dateA);
        });

        if (pendingRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.clock,
                  size: 64.sp,
                  color: Colors.grey.withAlpha(128),
                ),
                SizedBox(height: 16.h),
                Text(
                  isArabic ? 'لا توجد طلبات معلقة' : 'No pending requests',
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  isArabic
                      ? 'طلبات الاستعارة الخاصة بك ستظهر هنا'
                      : 'Your borrow requests will appear here',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.withAlpha(179),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: pendingRequests.length,
          itemBuilder: (context, index) {
            final doc = pendingRequests[index];
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = (data['requestDate'] as Timestamp?)?.toDate() ?? (data['createdAt'] as Timestamp?)?.toDate();
            final isQueued = data['status'] == 'queued';

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
                            data['gameTitle'] ?? 'Unknown Game',
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
                            color: isQueued
                                ? Colors.orange.withAlpha(51)
                                : AppTheme.warningColor.withAlpha(51),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            isQueued
                                ? (isArabic ? 'في الانتظار' : 'Queued')
                                : (isArabic ? 'معلق' : 'Pending'),
                            style: TextStyle(
                              color: isQueued ? Colors.orange : AppTheme.warningColor,
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
                      label: isArabic ? 'المنصة' : 'Platform',
                      value: '${data['platform']?.toUpperCase() ?? 'PS4'} • ${data['accountType'] ?? 'Primary'}',
                    ),
                    _buildInfoRow(
                      icon: Icons.speed,
                      label: isArabic ? 'قيمة الاستعارة' : 'Borrow Value',
                      value: '${data['borrowValue']?.toStringAsFixed(0) ?? '0'} LE',
                    ),
                    if (isQueued && data['queuePosition'] != null)
                      _buildInfoRow(
                        icon: Icons.format_list_numbered,
                        label: isArabic ? 'موقعك في القائمة' : 'Queue Position',
                        value: '#${data['queuePosition']}',
                      ),
                    if (createdAt != null)
                      _buildInfoRow(
                        icon: Icons.access_time,
                        label: isArabic ? 'تاريخ الطلب' : 'Request Date',
                        value: DateFormat('dd MMM yyyy, HH:mm').format(createdAt),
                      ),

                    // Cancel button for pending requests
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _cancelBorrowRequest(doc.id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          isArabic ? 'إلغاء الطلب' : 'Cancel Request',
                          style: TextStyle(fontSize: 14.sp),
                        ),
                      ),
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

  // Borrowing History Tab
  Widget _buildBorrowingHistory() {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final user = authProvider.currentUser;

    if (user == null) {
      return Center(
        child: Text(
          isArabic ? 'يرجى تسجيل الدخول أولاً' : 'Please login first',
          style: TextStyle(fontSize: 16.sp),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('borrow_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'returned')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allHistory = snapshot.data?.docs ?? [];
        
        // Sort by returnedAt or requestDate in descending order (newest first)
        final history = allHistory..sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final dateA = (dataA['returnedAt'] as Timestamp?)?.toDate() ?? (dataA['requestDate'] as Timestamp?)?.toDate() ?? DateTime(2020);
          final dateB = (dataB['returnedAt'] as Timestamp?)?.toDate() ?? (dataB['requestDate'] as Timestamp?)?.toDate() ?? DateTime(2020);
          return dateB.compareTo(dateA);
        });

        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.clockRotateLeft,
                  size: 64.sp,
                  color: Colors.grey.withAlpha(128),
                ),
                SizedBox(height: 16.h),
                Text(
                  isArabic ? 'لا يوجد سجل استعارات' : 'No borrowing history',
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  isArabic
                      ? 'سجل استعاراتك السابقة سيظهر هنا'
                      : 'Your past borrowing history will appear here',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.withAlpha(179),
                  ),
                  textAlign: TextAlign.center,
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
            final borrowDate = (data['approvedAt'] as Timestamp?)?.toDate();
            final returnDate = (data['returnedAt'] as Timestamp?)?.toDate();
            final duration = borrowDate != null && returnDate != null
                ? returnDate.difference(borrowDate).inDays
                : 0;

            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        data['gameTitle'] ?? 'Unknown Game',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withAlpha(51),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          isArabic ? 'مُرجع' : 'Returned',
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHistoryInfo(
                          icon: Icons.calendar_today,
                          label: isArabic ? 'تاريخ الاستعارة' : 'Borrowed',
                          value: borrowDate != null
                              ? DateFormat('dd/MM/yyyy').format(borrowDate)
                              : 'N/A',
                        ),
                      ),
                      Expanded(
                        child: _buildHistoryInfo(
                          icon: Icons.assignment_return,
                          label: isArabic ? 'تاريخ الإرجاع' : 'Returned',
                          value: returnDate != null
                              ? DateFormat('dd/MM/yyyy').format(returnDate)
                              : 'N/A',
                        ),
                      ),
                      Expanded(
                        child: _buildHistoryInfo(
                          icon: Icons.timer,
                          label: isArabic ? 'المدة' : 'Duration',
                          value: isArabic ? '$duration يوم' : '$duration days',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper Widgets
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

  Widget _buildHistoryInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16.sp, color: AppTheme.primaryColor),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Action Methods
  Future<void> _submitReturnRequest(String borrowId, Map<String, dynamic> borrowData) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تأكيد الإرجاع' : 'Confirm Return'),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من أنك تريد إرجاع هذه اللعبة؟'
              : 'Are you sure you want to return this game?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text(isArabic ? 'نعم، إرجاع' : 'Yes, Return'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Create return request
      await _firestore.collection('return_requests').add({
        'borrowId': borrowId,
        'gameId': borrowData['gameId'],
        'gameTitle': borrowData['gameTitle'],
        'userId': borrowData['userId'],
        'userName': borrowData['userName'],
        'platform': borrowData['platform'],
        'accountType': borrowData['accountType'],
        'borrowValue': borrowData['borrowValue'],
        'borrowDate': borrowData['approvedAt'],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم إرسال طلب الإرجاع للمراجعة'
                : 'Return request submitted for review',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      print('Error submitting return request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'حدث خطأ في إرسال الطلب'
                : 'Error submitting request',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _cancelBorrowRequest(String requestId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تأكيد الإلغاء' : 'Confirm Cancellation'),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من إلغاء هذا الطلب؟'
              : 'Are you sure you want to cancel this request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isArabic ? 'لا' : 'No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(
              isArabic ? 'نعم، إلغاء' : 'Yes, Cancel',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('borrow_requests').doc(requestId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم إلغاء الطلب بنجاح'
                : 'Request cancelled successfully',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      print('Error cancelling request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'حدث خطأ في إلغاء الطلب'
                : 'Error cancelling request',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showBorrowDetails(Map<String, dynamic> data) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['gameTitle'] ?? 'Game Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                isArabic ? 'المنصة' : 'Platform',
                data['platform']?.toUpperCase() ?? 'Unknown',
              ),
              _buildDetailRow(
                isArabic ? 'نوع الحساب' : 'Account Type',
                data['accountType'] ?? 'Unknown',
              ),
              _buildDetailRow(
                isArabic ? 'قيمة الاستعارة' : 'Borrow Value',
                '${data['borrowValue']?.toStringAsFixed(0) ?? '0'} LE',
              ),
              _buildDetailRow(
                isArabic ? 'المساهم' : 'Contributor',
                data['contributorName'] ?? 'Unknown',
              ),
              if (data['approvedAt'] != null)
                _buildDetailRow(
                  isArabic ? 'تاريخ الموافقة' : 'Approval Date',
                  DateFormat('dd MMM yyyy').format(
                    (data['approvedAt'] as Timestamp).toDate(),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إغلاق' : 'Close'),
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
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }
}