// lib/presentation/screens/user/my_contributions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_loading.dart';
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
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(isArabic ? 'الرجاء تسجيل الدخول' : 'Please login'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          isArabic ? 'مساهماتي' : 'My Contributions',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddContributionScreen(),
                ),
              ).then((_) {
                // Refresh after returning
                setState(() {});
              });
            },
            tooltip: isArabic ? 'إضافة مساهمة' : 'Add Contribution',
          ),
        ],
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
          _buildPendingTab(user.uid),
          _buildApprovedTab(user.uid),
          _buildRejectedTab(user.uid),
        ],
      ),
    );
  }

  // Build Pending Tab
  Widget _buildPendingTab(String userId) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('contribution_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CustomLoading());
        }

        // Debug print
        print('Pending contributions count: ${snapshot.data?.docs.length ?? 0}');

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: FontAwesomeIcons.clock,
            title: isArabic ? 'لا توجد مساهمات معلقة' : 'No pending contributions',
            subtitle: isArabic
                ? 'المساهمات في انتظار موافقة المسؤول'
                : 'Contributions waiting for admin approval',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            data['docId'] = doc.id; // Store document ID for reference
            return _buildContributionCard(data, 'pending');
          },
        );
      },
    );
  }

  // Build Approved Tab
  Widget _buildApprovedTab(String userId) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('contribution_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CustomLoading());
        }

        final approvedContributions = snapshot.data?.docs ?? [];

        // Also get games that this user contributed directly
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('games')
              .snapshots(),
          builder: (context, gamesSnapshot) {
            if (gamesSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CustomLoading());
            }

            final List<Map<String, dynamic>> allContributions = [];

            // Add approved contribution requests
            for (var doc in approvedContributions) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              data['source'] = 'contribution_request';
              allContributions.add(data);
            }

            // Add games where user is a contributor
            if (gamesSnapshot.hasData) {
              for (var doc in gamesSnapshot.data!.docs) {
                final gameData = doc.data() as Map<String, dynamic>;

                // Check if this user contributed to this game
                if (gameData['accounts'] != null) {
                  final accounts = gameData['accounts'] as List<dynamic>;
                  for (var account in accounts) {
                    if (account['contributorId'] == userId) {
                      allContributions.add({
                        'id': doc.id,
                        'gameTitle': gameData['title'] ?? 'Unknown Game',
                        'gameValue': account['gameValue'] ?? gameData['totalValue'] ?? 0,
                        'platforms': account['platforms'] ?? [],
                        'sharingOptions': account['sharingOptions'] ?? [],
                        'status': 'approved',
                        'type': 'game_account',
                        'approvedAt': account['dateAdded'],
                        'source': 'game',
                      });
                      break; // Only add once per game even if multiple accounts
                    }
                  }
                }
              }
            }

            if (allContributions.isEmpty) {
              return _buildEmptyState(
                icon: FontAwesomeIcons.checkCircle,
                title: isArabic ? 'لا توجد مساهمات معتمدة' : 'No approved contributions',
                subtitle: isArabic
                    ? 'المساهمات المعتمدة ستظهر هنا'
                    : 'Your approved contributions will appear here',
              );
            }

            // Sort by date (newest first)
            allContributions.sort((a, b) {
              final dateA = _parseDate(a['approvedAt']);
              final dateB = _parseDate(b['approvedAt']);
              if (dateA == null || dateB == null) return 0;
              return dateB.compareTo(dateA);
            });

            return ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: allContributions.length,
              itemBuilder: (context, index) {
                return _buildContributionCard(allContributions[index], 'approved');
              },
            );
          },
        );
      },
    );
  }

  // Build Rejected Tab
  Widget _buildRejectedTab(String userId) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('contribution_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'rejected')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CustomLoading());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: FontAwesomeIcons.timesCircle,
            title: isArabic ? 'لا توجد مساهمات مرفوضة' : 'No rejected contributions',
            subtitle: isArabic
                ? 'المساهمات المرفوضة ستظهر هنا'
                : 'Rejected contributions will appear here',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return _buildContributionCard(data, 'rejected');
          },
        );
      },
    );
  }

  // Build contribution card
  Widget _buildContributionCard(Map<String, dynamic> data, String status) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    final isGameContribution = data['type'] == 'game_account' || data['type'] == 'game';
    final isFundContribution = data['type'] == 'fund_share' || data['type'] == 'fund';

    // Parse dates
    DateTime? date = _parseDate(
        status == 'approved' ? data['approvedAt'] :
        status == 'rejected' ? data['rejectedAt'] :
        data['submittedAt']
    );

    // Get status color
    Color statusColor = status == 'approved'
        ? AppTheme.successColor
        : status == 'rejected'
        ? AppTheme.errorColor
        : AppTheme.warningColor;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () => _showContributionDetails(data, status),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    isGameContribution
                        ? FontAwesomeIcons.gamepad
                        : isFundContribution
                        ? FontAwesomeIcons.dollarSign
                        : FontAwesomeIcons.playstation,
                    color: statusColor,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        data['gameTitle'] ?? 'Unknown Game',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      // Type and Value
                      Row(
                        children: [
                          if (isGameContribution) ...[
                            Icon(Icons.attach_money, size: 14.sp, color: Colors.grey),
                            Text(
                              '${data['gameValue'] ?? 0} LE',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 12.w),
                          ],
                          if (isFundContribution) ...[
                            Icon(Icons.savings, size: 14.sp, color: Colors.grey),
                            Text(
                              '${data['amount'] ?? 0} LE',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppTheme.secondaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 12.w),
                          ],
                          // Platforms
                          if (data['platforms'] != null) ...[
                            ..._buildPlatformChips(data['platforms']),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),
                      // Date and Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            date != null ? _formatDate(date) : '',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              _getStatusText(status, isArabic),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16.sp,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPlatformChips(dynamic platforms) {
    if (platforms == null) return [];

    List<String> platformList = [];
    if (platforms is List) {
      platformList = platforms.map((p) => p.toString()).toList();
    }

    return platformList.map((platform) {
      final isPS5 = platform.toLowerCase().contains('ps5');
      return Container(
        margin: EdgeInsets.only(right: 4.w),
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: isPS5 ? Colors.blue : Colors.indigo,
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Text(
          platform.toUpperCase(),
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }).toList();
  }

  String _getStatusText(String status, bool isArabic) {
    switch (status) {
      case 'pending':
        return isArabic ? 'معلق' : 'Pending';
      case 'approved':
        return isArabic ? 'معتمد' : 'Approved';
      case 'rejected':
        return isArabic ? 'مرفوض' : 'Rejected';
      default:
        return status;
    }
  }

  DateTime? _parseDate(dynamic dateField) {
    if (dateField == null) return null;

    try {
      if (dateField is Timestamp) {
        return dateField.toDate();
      } else if (dateField is DateTime) {
        return dateField;
      }
    } catch (e) {
      print('Error parsing date: $e');
    }
    return null;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showContributionDetails(Map<String, dynamic> data, String status) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 50.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Title
            Text(
              isArabic ? 'تفاصيل المساهمة' : 'Contribution Details',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20.h),

            // Game Title
            _buildDetailRow(
              isArabic ? 'اللعبة' : 'Game',
              data['gameTitle'] ?? 'Unknown',
              Icons.games,
            ),

            // Type
            _buildDetailRow(
              isArabic ? 'النوع' : 'Type',
              data['type'] == 'game_account' ? (isArabic ? 'حساب لعبة' : 'Game Account') :
              data['type'] == 'fund_share' ? (isArabic ? 'مساهمة مالية' : 'Fund Contribution') :
              'PS Plus',
              FontAwesomeIcons.tag,
            ),

            // Value
            if (data['gameValue'] != null)
              _buildDetailRow(
                isArabic ? 'القيمة' : 'Value',
                '${data['gameValue']} LE',
                Icons.attach_money,
              ),

            if (data['amount'] != null)
              _buildDetailRow(
                isArabic ? 'المبلغ' : 'Amount',
                '${data['amount']} LE',
                Icons.attach_money,
              ),

            // Platforms
            if (data['platforms'] != null && (data['platforms'] as List).isNotEmpty)
              _buildDetailRow(
                isArabic ? 'المنصات' : 'Platforms',
                (data['platforms'] as List).join(', '),
                FontAwesomeIcons.playstation,
              ),

            // Sharing Options
            if (data['sharingOptions'] != null && (data['sharingOptions'] as List).isNotEmpty)
              _buildDetailRow(
                isArabic ? 'خيارات المشاركة' : 'Sharing Options',
                (data['sharingOptions'] as List).join(', '),
                Icons.share,
              ),

            // Status
            _buildDetailRow(
              isArabic ? 'الحالة' : 'Status',
              _getStatusText(status, isArabic),
              Icons.info_outline,
            ),

            // Rejection Reason
            if (status == 'rejected' && data['rejectionReason'] != null) ...[
              SizedBox(height: 12.h),
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
                        data['rejectionReason'],
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

            SizedBox(height: 20.h),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  isArabic ? 'إغلاق' : 'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 20.sp, color: AppTheme.primaryColor),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDarkMode = Provider.of<AppProvider>(context).isDarkMode;
    final isArabic = Provider.of<AppProvider>(context).isArabic;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64.sp,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddContributionScreen(),
                ),
              );
            },
            icon: Icon(Icons.add, color: Colors.white),
            label: Text(
              isArabic ? 'إضافة مساهمة' : 'Add Contribution',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          ),
        ],
      ),
    );
  }
}