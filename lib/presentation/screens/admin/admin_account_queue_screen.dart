import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../../services/queue_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';

class AdminAccountQueueScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;
  
  const AdminAccountQueueScreen({
    Key? key,
    required this.arguments,
  }) : super(key: key);

  @override
  State<AdminAccountQueueScreen> createState() => _AdminAccountQueueScreenState();
}

class _AdminAccountQueueScreenState extends State<AdminAccountQueueScreen> {
  final QueueService _queueService = QueueService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _queueEntries = [];
  List<Map<String, dynamic>> _filteredQueueEntries = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  String get gameId => widget.arguments['gameId'];
  String get gameTitle => widget.arguments['gameTitle'];
  String get accountId => widget.arguments['accountId'];
  String get platform => widget.arguments['platform'];
  String get accountType => widget.arguments['accountType'];
  String get displayName => widget.arguments['displayName'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadQueueData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterQueues();
    });
  }

  void _filterQueues() {
    if (_searchQuery.isEmpty) {
      _filteredQueueEntries = List.from(_queueEntries);
    } else {
      _filteredQueueEntries = _queueEntries.where((entry) {
        final userName = (entry['userName'] ?? '').toString().toLowerCase();
        final userId = (entry['userId'] ?? '').toString().toLowerCase();
        final userEmail = (entry['userEmail'] ?? '').toString().toLowerCase();
        
        return userName.contains(_searchQuery) ||
               userId.contains(_searchQuery) ||
               userEmail.contains(_searchQuery);
      }).toList();
    }
  }
  
  Future<void> _loadQueueData() async {
    setState(() => _isLoading = true);
    
    try {
      _queueEntries = await _queueService.getAdminQueueDetails(
        gameId: gameId,
        accountId: accountId,
        platform: platform,
        accountType: accountType,
      );
      
      _filteredQueueEntries = List.from(_queueEntries);
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading queue data: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _reorderQueue(String entryId, int oldPosition, int newPosition) async {
    if (oldPosition == newPosition) return;
    
    final entry = _queueEntries.firstWhere((e) => e['id'] == entryId);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تأكيد إعادة الترتيب' : 'Confirm Reorder'),
        content: Text(
          isArabic 
            ? 'هل تريد نقل ${entry['userName']} من المركز $oldPosition إلى المركز $newPosition؟'
            : 'Move ${entry['userName']} from position $oldPosition to position $newPosition?',
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
            child: Text(isArabic ? 'تأكيد' : 'Confirm'),
          ),
        ],
      ),
    );
    
    if (confirm != true) {
      // Reload data to reset any visual changes
      _loadQueueData();
      return;
    }
    
    // Show loading state
    setState(() => _isLoading = true);
    
    try {
      final result = await _queueService.reorderQueue(
        queueEntryId: entryId,
        newPosition: newPosition,
        gameId: gameId,
        accountId: accountId,
        platform: platform,
        accountType: accountType,
      );
      
      if (result['success']) {
        await _loadQueueData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic 
                  ? 'تم إعادة ترتيب القائمة بنجاح'
                  : 'Queue reordered successfully',
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? (isArabic ? 'فشل في إعادة الترتيب' : 'Failed to reorder queue'),
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        await _loadQueueData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'حدث خطأ في إعادة الترتيب' : 'Error reordering queue: $e',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      await _loadQueueData();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _removeFromQueue(String queueId, String userName) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'إزالة من القائمة' : 'Remove from Queue'),
        content: Text(
          isArabic 
            ? 'هل تريد إزالة $userName من قائمة الانتظار؟'
            : 'Are you sure you want to remove $userName from the queue?',
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
            child: Text(isArabic ? 'إزالة' : 'Remove'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await _queueService.removeFromQueue(queueId);
        await _loadQueueData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic ? 'تم إزالة المستخدم من القائمة' : 'User removed from queue',
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic ? 'فشل في إزالة المستخدم' : 'Failed to remove user',
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              gameTitle,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            Text(
              displayName,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadQueueData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isArabic ? 'ابحث عن مستخدم...' : 'Search users...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                filled: true,
                fillColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
              ),
            ),
          ),
          
          // Statistics Bar
          if (_queueEntries.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic 
                      ? 'العدد الكلي: ${_queueEntries.length}'
                      : 'Total: ${_queueEntries.length}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    Text(
                      isArabic 
                        ? 'النتائج: ${_filteredQueueEntries.length}'
                        : 'Results: ${_filteredQueueEntries.length}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          
          // Queue List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _queueEntries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.queue,
                              size: 64.sp,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              isArabic ? 'لا توجد قوائم انتظار' : 'No queue entries',
                              style: TextStyle(
                                fontSize: 18.sp,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              isArabic 
                                ? 'لا يوجد مستخدمون في قائمة الانتظار لهذا الحساب'
                                : 'No users are queued for this account',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : _buildQueueList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList() {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    
    final entriesToShow = _searchQuery.isNotEmpty ? _filteredQueueEntries : _queueEntries;
    
    return Column(
      children: [
        // Instruction header
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.primaryColor,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  isArabic 
                    ? 'اسحب وأفلت العناصر لإعادة ترتيب القائمة'
                    : 'Drag and drop items to reorder the queue',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Queue list
        Expanded(
          child: ReorderableListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: entriesToShow.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final entryId = entriesToShow[oldIndex]['id'];
              _reorderQueue(entryId, oldIndex + 1, newIndex + 1);
            },
            itemBuilder: (context, index) {
              final entry = entriesToShow[index];
              final joinedAt = (entry['joinedAt'] as Timestamp?)?.toDate();
              
              return Card(
                key: ValueKey(entry['id']),
                margin: EdgeInsets.only(bottom: 12.h),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      '${entry['position'] ?? index + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    entry['userName'] ?? 'Unknown User',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Score: ${entry['contributionScore'] ?? 0}',
                    style: TextStyle(fontSize: 14.sp),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Icon(
                          Icons.drag_handle,
                          color: AppTheme.primaryColor,
                          size: 20.sp,
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
                          _buildDetailRow('User ID', entry['userId']),
                          _buildDetailRow('Member ID', entry['memberId'] ?? 'N/A'),
                          _buildDetailRow('Email', entry['userEmail'] ?? 'N/A'),
                          _buildDetailRow('Phone', entry['userPhone'] ?? 'N/A'),
                          _buildDetailRow('Tier', entry['userTier'] ?? 'N/A'),
                          _buildDetailRow(
                            'Total Shares',
                            entry['userTotalShares']?.toString() ?? '0',
                          ),
                          _buildDetailRow(
                            'Joined At',
                            joinedAt != null
                                ? '${joinedAt.day}/${joinedAt.month}/${joinedAt.year} ${joinedAt.hour}:${joinedAt.minute}'
                                : 'N/A',
                          ),
                          _buildDetailRow(
                            'Estimated Wait',
                            '${(entry['position'] ?? 1) * 30} days',
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _removeFromQueue(
                                  entry['id'],
                                  entry['userName'] ?? 'Unknown User',
                                ),
                                icon: Icon(Icons.remove_circle),
                                label: Text(isArabic ? 'إزالة' : 'Remove'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}