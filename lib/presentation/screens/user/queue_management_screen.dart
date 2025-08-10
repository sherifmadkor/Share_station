// lib/presentation/screens/user/queue_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/queue_service.dart';
import '../../widgets/custom_loading.dart';

class QueueManagementScreen extends StatefulWidget {
  const QueueManagementScreen({Key? key}) : super(key: key);

  @override
  State<QueueManagementScreen> createState() => _QueueManagementScreenState();
}

class _QueueManagementScreenState extends State<QueueManagementScreen>
    with SingleTickerProviderStateMixin {
  final QueueService _queueService = QueueService();
  late TabController _tabController;

  List<Map<String, dynamic>> _myQueueEntries = [];
  List<Map<String, dynamic>> _allQueueEntries = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadQueueData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQueueData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;

    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      // Load user's queue entries
      final myEntries = await _queueService.getUserQueueEntries(userId);
      
      // Load all queue entries (for monitoring purposes)
      final allEntries = await _queueService.getAllQueueEntries();

      if (mounted) {
        setState(() {
          _myQueueEntries = myEntries;
          _allQueueEntries = allEntries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(
          msg: 'Error loading queue data: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  Future<void> _removeFromQueue(String queueId) async {
    try {
      await _queueService.removeFromQueue(queueId);
      Fluttertoast.showToast(
        msg: 'Removed from queue successfully',
        backgroundColor: AppTheme.successColor,
      );
      _loadQueueData();
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _loadQueueData();
    setState(() => _isRefreshing = false);
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
          isArabic ? 'إدارة قوائم الانتظار' : 'Queue Management',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: Icon(FontAwesomeIcons.user),
              text: isArabic ? 'قوائمي' : 'My Queues',
            ),
            Tab(
              icon: Icon(FontAwesomeIcons.list),
              text: isArabic ? 'جميع القوائم' : 'All Queues',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const CustomLoading()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMyQueuesTab(isArabic, isDarkMode),
                _buildAllQueuesTab(isArabic, isDarkMode),
              ],
            ),
    );
  }

  Widget _buildMyQueuesTab(bool isArabic, bool isDarkMode) {
    if (_myQueueEntries.isEmpty) {
      return _buildEmptyState(
        isArabic ? 'لا توجد قوائم انتظار' : 'No queue entries',
        isArabic 
            ? 'لم تنضم إلى أي قوائم انتظار حتى الآن'
            : 'You haven\'t joined any queues yet',
        FontAwesomeIcons.clockRotateLeft,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: _myQueueEntries.length,
        itemBuilder: (context, index) {
          final entry = _myQueueEntries[index];
          return _buildQueueEntryTile(entry, isArabic, isDarkMode, showActions: true);
        },
      ),
    );
  }

  Widget _buildAllQueuesTab(bool isArabic, bool isDarkMode) {
    if (_allQueueEntries.isEmpty) {
      return _buildEmptyState(
        isArabic ? 'لا توجد قوائم انتظار' : 'No queue entries',
        isArabic 
            ? 'لا توجد قوائم انتظار في النظام'
            : 'No queue entries in the system',
        FontAwesomeIcons.list,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: _allQueueEntries.length,
        itemBuilder: (context, index) {
          final entry = _allQueueEntries[index];
          return _buildQueueEntryTile(entry, isArabic, isDarkMode, showActions: false);
        },
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64.sp,
            color: Colors.grey,
          ),
          SizedBox(height: 24.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQueueEntryTile(
    Map<String, dynamic> entry,
    bool isArabic,
    bool isDarkMode, {
    required bool showActions,
  }) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isMyEntry = entry['userId'] == authProvider.currentUser?.uid;
    
    final createdAt = entry['createdAt'] as Timestamp?;
    final createdDate = createdAt?.toDate();
    final formattedDate = createdDate != null
        ? DateFormat('MMM dd, yyyy • HH:mm').format(createdDate)
        : 'Unknown';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: isMyEntry
            ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with game title and priority
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['gameTitle'] ?? 'Unknown Game',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.user,
                            size: 12.sp,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            entry['userName'] ?? 'Unknown User',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey,
                            ),
                          ),
                          if (isMyEntry) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                isArabic ? 'أنت' : 'You',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(entry['priority']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        '${isArabic ? "أولوية" : "Priority"}: ${entry['priority']?.toStringAsFixed(1) ?? '0.0'}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _getPriorityColor(entry['priority']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${isArabic ? "الترتيب" : "Position"}: #${entry['position'] ?? '?'}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Game details
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.gamepad,
                  size: 14.sp,
                  color: Colors.grey,
                ),
                SizedBox(width: 6.w),
                Text(
                  '${entry['platform']} • ${entry['accountType']}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey,
                  ),
                ),
                Spacer(),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            // Status and actions
            if (showActions && isMyEntry) ...[
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: _getStatusColor(entry['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        _getStatusText(entry['status'], isArabic),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _getStatusColor(entry['status']),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  TextButton.icon(
                    onPressed: () => _confirmRemoveFromQueue(entry['id'], isArabic),
                    icon: Icon(FontAwesomeIcons.xmark, size: 14.sp),
                    label: Text(
                      isArabic ? 'إزالة' : 'Remove',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(double? priority) {
    if (priority == null) return Colors.grey;
    if (priority >= 8.0) return AppTheme.successColor;
    if (priority >= 6.0) return AppTheme.primaryColor;
    if (priority >= 4.0) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return AppTheme.primaryColor;
      case 'processing':
        return AppTheme.warningColor;
      case 'fulfilled':
        return AppTheme.successColor;
      case 'expired':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status, bool isArabic) {
    switch (status?.toLowerCase()) {
      case 'active':
        return isArabic ? 'نشط' : 'Active';
      case 'processing':
        return isArabic ? 'قيد المعالجة' : 'Processing';
      case 'fulfilled':
        return isArabic ? 'تم التنفيذ' : 'Fulfilled';
      case 'expired':
        return isArabic ? 'منتهي الصلاحية' : 'Expired';
      default:
        return isArabic ? 'غير محدد' : 'Unknown';
    }
  }

  Future<void> _confirmRemoveFromQueue(String queueId, bool isArabic) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تأكيد الإزالة' : 'Confirm Removal'),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من إزالة هذا العنصر من قائمة الانتظار؟'
              : 'Are you sure you want to remove this item from the queue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(
              isArabic ? 'إزالة' : 'Remove',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _removeFromQueue(queueId);
    }
  }
}