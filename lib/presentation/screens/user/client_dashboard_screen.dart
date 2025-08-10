// lib/presentation/screens/user/client_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../../data/models/user_model.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/client_service.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ClientService _clientService = ClientService();

  bool _isLoading = false;
  Map<String, dynamic> _clientData = {};
  List<Map<String, dynamic>> _cycleHistory = [];
  bool _needsRenewal = false;

  @override
  void initState() {
    super.initState();
    _loadClientData();
  }

  Future<void> _loadClientData() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    // Check if user is actually a client
    if (user.tier != UserTier.client) {
      Navigator.pop(context);
      Fluttertoast.showToast(
        msg: 'This dashboard is for client members only',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data()!;

      _clientData = {
        'totalBorrows': userData['totalBorrowsCount'] ?? 0,
        'borrowLimit': userData['borrowLimit'] ?? 10,
        'freeborrowings': userData['freeborrowings'] ?? 5,
        'usedFreeborrowings': 5 - (userData['freeborrowings'] ?? 5),
        'membershipStartDate': userData['membershipStartDate'],
        'membershipRenewalDate': userData['membershipRenewalDate'],
        'currentCycle': ((userData['totalBorrowsCount'] ?? 0) ~/ 10) + 1,
        'stationLimit': userData['stationLimit'] ?? 3000,
        'remainingStationLimit': userData['remainingStationLimit'] ?? 3000,
      };

      // Check renewal status
      final renewalCheck = await _clientService.checkClientRenewal(user.uid);
      _needsRenewal = renewalCheck['needsRenewal'] ?? false;

      // Load cycle history
      await _loadCycleHistory(user.uid);

    } catch (e) {
      print('Error loading client data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCycleHistory(String userId) async {
    try {
      final historySnapshot = await _firestore
          .collection('client_cycles')
          .where('userId', isEqualTo: userId)
          .orderBy('startDate', descending: true)
          .limit(5)
          .get();

      _cycleHistory = historySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error loading cycle history: $e');
      _cycleHistory = [];
    }
  }

  Future<void> _renewMembership() async {
    final appProvider = context.read<AppProvider>();
    final authProvider = context.read<AuthProvider>();
    final isArabic = appProvider.isArabic;
    final user = authProvider.currentUser;

    if (user == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تجديد العضوية' : 'Renew Membership'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic
                  ? 'لقد وصلت إلى حد الاستعارة (10 ألعاب).'
                  : 'You have reached your borrowing limit (10 games).',
            ),
            SizedBox(height: 12.h),
            Text(
              isArabic
                  ? 'لتجديد عضويتك والحصول على 10 استعارات إضافية:'
                  : 'To renew your membership and get 10 more borrows:',
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'رسوم التجديد:' : 'Renewal Fee:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '750 LE',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              isArabic
                  ? 'سيشمل التجديد:\n• 10 استعارات جديدة\n• 5 استعارات مجانية\n• استمرار جميع المزايا'
                  : 'Renewal includes:\n• 10 new borrows\n• 5 free borrows\n• All benefits continue',
              style: TextStyle(fontSize: 12.sp),
            ),
          ],
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
            child: Text(isArabic ? 'تجديد الآن' : 'Renew Now'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await _clientService.renewClientMembership(
        userId: user.uid,
        renewalFee: 750,
      );

      if (result['success']) {
        Fluttertoast.showToast(
          msg: result['message'],
          backgroundColor: AppTheme.successColor,
        );

        // Reload data
        await _loadClientData();
      } else {
        Fluttertoast.showToast(
          msg: result['message'],
          backgroundColor: AppTheme.errorColor,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: $e',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    final borrowsUsed = _clientData['totalBorrows'] ?? 0;
    final borrowsRemaining = 10 - (borrowsUsed % 10);
    final freeborrowsRemaining = _clientData['freeborrowings'] ?? 0;
    final currentCycle = _clientData['currentCycle'] ?? 1;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          isArabic ? 'لوحة العميل' : 'Client Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadClientData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Renewal Alert
              if (_needsRenewal)
                Container(
                  margin: EdgeInsets.only(bottom: 16.h),
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppTheme.warningColor,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.warningColor,
                            size: 24.sp,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isArabic ? 'التجديد مطلوب' : 'Renewal Required',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                                Text(
                                  isArabic
                                      ? 'لقد وصلت إلى حد الاستعارة'
                                      : 'You have reached your borrowing limit',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _renewMembership,
                          icon: Icon(Icons.refresh),
                          label: Text(
                            isArabic ? 'تجديد الآن (750 LE)' : 'Renew Now (750 LE)',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warningColor,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Current Cycle Card
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue,
                      Colors.blue.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      offset: Offset(0, 4),
                      blurRadius: 12,
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
                          isArabic ? 'الدورة الحالية' : 'Current Cycle',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14.sp,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            '#$currentCycle',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularPercentIndicator(
                          radius: 60.r,
                          lineWidth: 8.w,
                          percent: (borrowsUsed % 10) / 10,
                          center: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${borrowsUsed % 10}/10',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isArabic ? 'استعارة' : 'Borrows',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          ),
                          progressColor: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          circularStrokeCap: CircularStrokeCap.round,
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCycleStat(
                          label: isArabic ? 'متبقي' : 'Remaining',
                          value: borrowsRemaining.toString(),
                          icon: Icons.timer,
                        ),
                        Container(
                          width: 1,
                          height: 30.h,
                          color: Colors.white24,
                        ),
                        _buildCycleStat(
                          label: isArabic ? 'مجاني متبقي' : 'Free Left',
                          value: freeborrowsRemaining.toString(),
                          icon: Icons.card_giftcard,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // Stats Grid
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard(
                    title: isArabic ? 'حد المحطة' : 'Station Limit',
                    value: '${(_clientData['stationLimit'] ?? 0).toStringAsFixed(0)} LE',
                    icon: Icons.account_balance_wallet,
                    color: AppTheme.primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                  _buildStatCard(
                    title: isArabic ? 'المتبقي' : 'Remaining',
                    value: '${(_clientData['remainingStationLimit'] ?? 0).toStringAsFixed(0)} LE',
                    icon: Icons.account_balance,
                    color: AppTheme.successColor,
                    isDarkMode: isDarkMode,
                  ),
                  _buildStatCard(
                    title: isArabic ? 'إجمالي الاستعارات' : 'Total Borrows',
                    value: borrowsUsed.toString(),
                    icon: FontAwesomeIcons.gamepad,
                    color: AppTheme.infoColor,
                    isDarkMode: isDarkMode,
                  ),
                  _buildStatCard(
                    title: isArabic ? 'استعارات مجانية مستخدمة' : 'Free Used',
                    value: '${_clientData['usedFreeborrowings'] ?? 0}/5',
                    icon: Icons.card_giftcard,
                    color: AppTheme.warningColor,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              // Benefits Section
              Text(
                isArabic ? 'مزايا العضوية' : 'Membership Benefits',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),

              _buildBenefitItem(
                icon: Icons.check_circle,
                title: isArabic ? '10 استعارات لكل دورة' : '10 borrows per cycle',
                subtitle: isArabic
                    ? 'استعر حتى 10 ألعاب قبل التجديد'
                    : 'Borrow up to 10 games before renewal',
                isDarkMode: isDarkMode,
              ),
              _buildBenefitItem(
                icon: Icons.card_giftcard,
                title: isArabic ? '5 استعارات مجانية' : '5 free borrows',
                subtitle: isArabic
                    ? 'الخمس الأولى من ألعاب الأعضاء مجانية'
                    : 'First 5 from member games are free',
                isDarkMode: isDarkMode,
              ),
              _buildBenefitItem(
                icon: Icons.attach_money,
                title: isArabic ? 'رسوم تجديد منخفضة' : 'Low renewal fee',
                subtitle: isArabic
                    ? '750 LE فقط لكل 10 استعارات'
                    : 'Only 750 LE per 10 borrows',
                isDarkMode: isDarkMode,
              ),
              _buildBenefitItem(
                icon: Icons.all_inclusive,
                title: isArabic ? 'وصول كامل للمكتبة' : 'Full library access',
                subtitle: isArabic
                    ? 'استعر من جميع الألعاب المتاحة'
                    : 'Borrow from all available games',
                isDarkMode: isDarkMode,
              ),

              if (_cycleHistory.isNotEmpty) ...[
                SizedBox(height: 24.h),

                // Cycle History
                Text(
                  isArabic ? 'سجل الدورات' : 'Cycle History',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),

                ..._cycleHistory.map((cycle) => _buildCycleHistoryCard(
                  cycle: cycle,
                  isArabic: isArabic,
                  isDarkMode: isDarkMode,
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCycleStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20.sp),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24.sp),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDarkMode ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: Colors.blue, size: 20.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleHistoryCard({
    required Map<String, dynamic> cycle,
    required bool isArabic,
    required bool isDarkMode,
  }) {
    final cycleNumber = cycle['cycleNumber'] ?? 0;
    final borrowsCount = cycle['borrowsCount'] ?? 0;
    final startDate = (cycle['startDate'] as Timestamp?)?.toDate();
    final endDate = (cycle['endDate'] as Timestamp?)?.toDate();
    final isComplete = cycle['isComplete'] ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isComplete ? AppTheme.successColor.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: (isComplete ? AppTheme.successColor : Colors.grey).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$cycleNumber',
                style: TextStyle(
                  color: isComplete ? AppTheme.successColor : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isArabic ? "الدورة" : "Cycle"} $cycleNumber',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  startDate != null && endDate != null
                      ? '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}'
                      : startDate != null
                      ? '${isArabic ? "بدأت في" : "Started"} ${DateFormat('dd/MM/yyyy').format(startDate)}'
                      : 'N/A',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$borrowsCount/10',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: isComplete ? AppTheme.successColor : AppTheme.primaryColor,
                ),
              ),
              Text(
                isArabic ? 'استعارات' : 'Borrows',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: isDarkMode ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}