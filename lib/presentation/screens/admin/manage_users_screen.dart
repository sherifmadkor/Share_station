// lib/presentation/screens/admin/manage_users_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/suspension_service.dart';
import '../../../services/balance_service.dart';
import '../../../data/models/user_model.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({Key? key}) : super(key: key);

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SuspensionService _suspensionService = SuspensionService();
  final BalanceService _balanceService = BalanceService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  String _selectedTier = 'all';
  String _selectedStatus = 'all';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      _allUsers = usersSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _applyFilters();
    } catch (e) {
      print('Error loading users: $e');
      Fluttertoast.showToast(
        msg: 'Error loading users',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    _filteredUsers = _allUsers.where((user) {
      // Search filter
      if (_searchController.text.isNotEmpty) {
        final searchTerm = _searchController.text.toLowerCase();
        final name = (user['name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final memberId = (user['memberId'] ?? '').toString().toLowerCase();

        if (!name.contains(searchTerm) &&
            !email.contains(searchTerm) &&
            !memberId.contains(searchTerm)) {
          return false;
        }
      }

      // Tier filter
      if (_selectedTier != 'all' && user['tier'] != _selectedTier) {
        return false;
      }

      // Status filter
      if (_selectedStatus != 'all' && user['status'] != _selectedStatus) {
        return false;
      }

      return true;
    }).toList();

    setState(() {});
  }

  Future<void> _updateUserStatus(String userId, String newStatus) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reload users
      await _loadUsers();

      Fluttertoast.showToast(
        msg: 'User status updated successfully',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error updating user status',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  Future<void> _promoteToVIP(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'tier': 'vip',
        'vipPromotionDate': FieldValue.serverTimestamp(),
        'borrowLimit': 5,
        'canWithdrawBalance': true,
        'withdrawalFeePercentage': 20,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _loadUsers();

      Fluttertoast.showToast(
        msg: 'User promoted to VIP successfully',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error promoting user',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    // Calculate statistics
    final totalUsers = _allUsers.length;
    final activeUsers = _allUsers.where((u) => u['status'] == 'active').length;
    final vipUsers = _allUsers.where((u) => u['tier'] == 'vip').length;
    final suspendedUsers = _allUsers.where((u) => u['status'] == 'suspended').length;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          isArabic ? 'إدارة المستخدمين' : 'Manage Users',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadUsers,
            tooltip: isArabic ? 'تحديث' : 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case 'check_suspensions':
                  final result = await _suspensionService.checkAndApplySuspensions();
                  Fluttertoast.showToast(
                    msg: 'Checked ${result['checked']} users, suspended ${result['suspended']}',
                    backgroundColor: AppTheme.infoColor,
                  );
                  await _loadUsers();
                  break;
                case 'check_vip':
                  final result = await _suspensionService.batchCheckVIPPromotions();
                  Fluttertoast.showToast(
                    msg: 'Promoted ${result['promoted']} users to VIP',
                    backgroundColor: AppTheme.successColor,
                  );
                  await _loadUsers();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'check_suspensions',
                child: Row(
                  children: [
                    Icon(Icons.person_off, size: 18.sp),
                    SizedBox(width: 8.w),
                    Text(isArabic ? 'فحص التعليقات' : 'Check Suspensions'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'check_vip',
                child: Row(
                  children: [
                    Icon(FontAwesomeIcons.crown, size: 18.sp),
                    SizedBox(width: 8.w),
                    Text(isArabic ? 'فحص ترقيات VIP' : 'Check VIP Promotions'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50.h),
          child: Container(
            color: AppTheme.primaryColor.withOpacity(0.1),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip(
                  label: isArabic ? 'الكل' : 'Total',
                  value: totalUsers.toString(),
                  color: AppTheme.primaryColor,
                ),
                _buildStatChip(
                  label: isArabic ? 'نشط' : 'Active',
                  value: activeUsers.toString(),
                  color: AppTheme.successColor,
                ),
                _buildStatChip(
                  label: 'VIP',
                  value: vipUsers.toString(),
                  color: Colors.amber,
                ),
                _buildStatChip(
                  label: isArabic ? 'معلق' : 'Suspended',
                  value: suspendedUsers.toString(),
                  color: AppTheme.errorColor,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search and Filters
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkSurface : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: isArabic
                        ? 'البحث بالاسم أو البريد أو معرف العضو...'
                        : 'Search by name, email, or member ID...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? AppTheme.darkBackground
                        : Colors.grey[100],
                  ),
                  onChanged: (value) => _applyFilters(),
                ),
                SizedBox(height: 12.h),
                // Filter Chips
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Tier Filter
                            _buildFilterChip(
                              label: isArabic ? 'الفئة:' : 'Tier:',
                              value: _selectedTier,
                              options: {
                                'all': isArabic ? 'الكل' : 'All',
                                'vip': 'VIP',
                                'member': isArabic ? 'عضو' : 'Member',
                                'client': isArabic ? 'عميل' : 'Client',
                                'user': isArabic ? 'مستخدم' : 'User',
                              },
                              onChanged: (value) {
                                setState(() => _selectedTier = value);
                                _applyFilters();
                              },
                            ),
                            SizedBox(width: 12.w),
                            // Status Filter
                            _buildFilterChip(
                              label: isArabic ? 'الحالة:' : 'Status:',
                              value: _selectedStatus,
                              options: {
                                'all': isArabic ? 'الكل' : 'All',
                                'active': isArabic ? 'نشط' : 'Active',
                                'suspended': isArabic ? 'معلق' : 'Suspended',
                                'inactive': isArabic ? 'غير نشط' : 'Inactive',
                              },
                              onChanged: (value) {
                                setState(() => _selectedStatus = value);
                                _applyFilters();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Users List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                ? _buildEmptyState(isArabic, isDarkMode)
                : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  return _buildUserCard(user, isArabic, isDarkMode);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required Map<String, String> options,
    required Function(String) onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: DropdownButton<String>(
            value: value,
            items: options.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(
                  entry.value,
                  style: TextStyle(fontSize: 12.sp),
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
            underline: SizedBox(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(
      Map<String, dynamic> user,
      bool isArabic,
      bool isDarkMode,
      ) {
    final name = user['name'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final memberId = user['memberId'] ?? 'N/A';
    final tier = user['tier'] ?? 'member';
    final status = user['status'] ?? 'active';
    final joinDate = (user['joinDate'] as Timestamp?)?.toDate();
    final lastActivityDate = (user['lastActivityDate'] as Timestamp?)?.toDate();

    // Calculate metrics
    final totalShares = (user['totalShares'] ?? 0).toDouble();
    final points = (user['points'] ?? 0).toInt();
    final balance = _calculateTotalBalance(user);
    final borrowsCount = (user['totalBorrowsCount'] ?? 0).toInt();

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.all(16.w),
          childrenPadding: EdgeInsets.all(16.w),
          leading: CircleAvatar(
            radius: 24.r,
            backgroundColor: _getTierColor(tier).withOpacity(0.2),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: _getTierColor(tier),
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'ID: $memberId',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isDarkMode ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              // Tier Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _getTierColor(tier).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: _getTierColor(tier).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  tier.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: _getTierColor(tier),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              // Status Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: _getStatusColor(status).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4.h),
              Text(
                email,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDarkMode ? Colors.white38 : Colors.black38,
                ),
              ),
              if (lastActivityDate != null)
                Text(
                  '${isArabic ? "آخر نشاط:" : "Last active:"} ${_formatDate(lastActivityDate)}',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                  ),
                ),
            ],
          ),
          children: [
            // User Details
            Column(
              children: [
                // Metrics Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCard(
                      icon: FontAwesomeIcons.coins,
                      label: isArabic ? 'النقاط' : 'Points',
                      value: points.toString(),
                      color: AppTheme.warningColor,
                    ),
                    _buildMetricCard(
                      icon: FontAwesomeIcons.wallet,
                      label: isArabic ? 'الرصيد' : 'Balance',
                      value: '${balance.toStringAsFixed(0)} LE',
                      color: AppTheme.successColor,
                    ),
                    _buildMetricCard(
                      icon: FontAwesomeIcons.handHoldingDollar,
                      label: isArabic ? 'المساهمات' : 'Shares',
                      value: totalShares.toStringAsFixed(1),
                      color: AppTheme.primaryColor,
                    ),
                    _buildMetricCard(
                      icon: FontAwesomeIcons.gamepad,
                      label: isArabic ? 'الاستعارات' : 'Borrows',
                      value: borrowsCount.toString(),
                      color: AppTheme.infoColor,
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // Additional Info
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppTheme.darkBackground
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        label: isArabic ? 'تاريخ الانضمام:' : 'Join Date:',
                        value: joinDate != null
                            ? DateFormat('dd MMM yyyy').format(joinDate)
                            : 'N/A',
                      ),
                      SizedBox(height: 8.h),
                      _buildInfoRow(
                        label: isArabic ? 'معرف المُحيل:' : 'Referrer ID:',
                        value: user['recruiterId'] ?? 'None',
                      ),
                      SizedBox(height: 8.h),
                      _buildInfoRow(
                        label: isArabic ? 'المستخدمون المُحالون:' : 'Referred Users:',
                        value: (user['referredUsers'] as List?)?.length.toString() ?? '0',
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // Action Buttons
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    // Edit User
                    _buildActionButton(
                      icon: Icons.edit,
                      label: isArabic ? 'تعديل' : 'Edit',
                      color: AppTheme.primaryColor,
                      onTap: () => _showEditUserDialog(user, isArabic),
                    ),

                    // Suspend/Activate
                    if (status == 'active')
                      _buildActionButton(
                        icon: Icons.person_off,
                        label: isArabic ? 'تعليق' : 'Suspend',
                        color: AppTheme.warningColor,
                        onTap: () => _updateUserStatus(user['id'], 'suspended'),
                      )
                    else
                      _buildActionButton(
                        icon: Icons.person_add,
                        label: isArabic ? 'تفعيل' : 'Activate',
                        color: AppTheme.successColor,
                        onTap: () => _updateUserStatus(user['id'], 'active'),
                      ),

                    // Promote to VIP
                    if (tier != 'vip')
                      _buildActionButton(
                        icon: FontAwesomeIcons.crown,
                        label: isArabic ? 'ترقية إلى VIP' : 'Promote to VIP',
                        color: Colors.amber,
                        onTap: () => _promoteToVIP(user['id']),
                      ),

                    // View Details
                    _buildActionButton(
                      icon: Icons.info_outline,
                      label: isArabic ? 'التفاصيل' : 'Details',
                      color: AppTheme.infoColor,
                      onTap: () => _showUserDetailsDialog(user, isArabic),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20.sp),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14.sp, color: color),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isArabic, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64.sp,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16.h),
          Text(
            isArabic ? 'لا يوجد مستخدمون' : 'No users found',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            isArabic
                ? 'حاول تغيير معايير البحث أو الفلاتر'
                : 'Try changing your search or filters',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user, bool isArabic) {
    // TODO: Implement edit user dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تعديل المستخدم' : 'Edit User'),
        content: Text('Edit user functionality coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showUserDetailsDialog(Map<String, dynamic> user, bool isArabic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['name'] ?? 'User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Member ID', user['memberId'] ?? 'N/A'),
              _buildDetailItem('Email', user['email'] ?? 'N/A'),
              _buildDetailItem('Phone', user['phoneNumber'] ?? 'N/A'),
              _buildDetailItem('Platform', user['platform'] ?? 'N/A'),
              _buildDetailItem('PS ID', user['psId'] ?? 'N/A'),
              Divider(),
              _buildDetailItem('Total Shares', '${user['totalShares'] ?? 0}'),
              _buildDetailItem('Game Shares', '${user['gameShares'] ?? 0}'),
              _buildDetailItem('Fund Shares', '${user['fundShares'] ?? 0}'),
              Divider(),
              _buildDetailItem('Station Limit', '${user['stationLimit'] ?? 0} LE'),
              _buildDetailItem('Remaining Limit', '${user['remainingStationLimit'] ?? 0} LE'),
              _buildDetailItem('Current Borrows', '${user['currentBorrows'] ?? 0}'),
              _buildDetailItem('Total Borrows', '${user['totalBorrowsCount'] ?? 0}'),
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalBalance(Map<String, dynamic> userData) {
    double total = 0;

    // Add balance components
    final borrowValue = userData['borrowValue'];
    if (borrowValue != null) {
      total += borrowValue is int ? borrowValue.toDouble() : borrowValue;
    }

    final sellValue = userData['sellValue'];
    if (sellValue != null) {
      total += sellValue is int ? sellValue.toDouble() : sellValue;
    }

    final refunds = userData['refunds'];
    if (refunds != null) {
      total += refunds is int ? refunds.toDouble() : refunds;
    }

    final referralEarnings = userData['referralEarnings'];
    if (referralEarnings != null) {
      total += referralEarnings is int ? referralEarnings.toDouble() : referralEarnings;
    }

    final cashIn = userData['cashIn'];
    if (cashIn != null) {
      total += cashIn is int ? cashIn.toDouble() : cashIn;
    }

    return total;
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'vip':
        return Colors.amber;
      case 'client':
        return Colors.blue;
      case 'member':
        return AppTheme.primaryColor;
      case 'admin':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppTheme.successColor;
      case 'suspended':
        return AppTheme.errorColor;
      case 'inactive':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }
}