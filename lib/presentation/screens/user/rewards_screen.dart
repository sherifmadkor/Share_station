// lib/presentation/screens/user/rewards_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/referral_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({Key? key}) : super(key: key);

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ReferralService _referralService = ReferralService();
  String _referralCode = '';
  bool _isLoadingReferralCode = true;
  Map<String, dynamic> _referralStats = {};
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    setState(() {
      _isLoadingReferralCode = true;
      _isLoadingStats = true;
    });
    
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    
    if (currentUser != null) {
      // Load referral code and stats simultaneously
      final code = await _referralService.getUserReferralCode(currentUser.uid);
      final stats = await _referralService.getReferralStats(currentUser.uid);
      
      setState(() {
        _referralCode = code;
        _referralStats = stats;
        _isLoadingReferralCode = false;
        _isLoadingStats = false;
      });
    }
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

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          isArabic ? 'المكافآت والإحالات' : 'Rewards & Referrals',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadReferralData,
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: isArabic ? 'المكافآت' : 'Rewards',
              icon: Icon(Icons.card_giftcard, size: 20.sp),
            ),
            Tab(
              text: isArabic ? 'الإحالات' : 'Referrals',
              icon: Icon(FontAwesomeIcons.userGroup, size: 18.sp),
            ),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: user == null
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRewardsTab(isArabic, isDarkMode, user),
                _buildReferralsTab(isArabic, isDarkMode, user),
              ],
            ),
    );
  }

  Widget _buildRewardsTab(bool isArabic, bool isDarkMode, dynamic user) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Points Summary Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.warningColor, AppTheme.warningColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.warningColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(FontAwesomeIcons.coins, color: Colors.white, size: 32.sp),
                SizedBox(height: 12.h),
                Text(
                  isArabic ? 'نقاطك الحالية' : 'Your Current Points',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '${user.points ?? 0}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Available Rewards Section
          Text(
            isArabic ? 'المكافآت المتاحة' : 'Available Rewards',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),

          // Reward Cards
          _buildRewardCard(
            title: isArabic ? 'خصم 50 جنيه' : '50 LE Discount',
            description: isArabic ? 'خصم على رسوم العضوية' : 'Discount on membership fees',
            pointsCost: 100,
            icon: Icons.discount,
            color: AppTheme.successColor,
            isArabic: isArabic,
            isDarkMode: isDarkMode,
          ),

          _buildRewardCard(
            title: isArabic ? 'أولوية في الطابور' : 'Queue Priority',
            description: isArabic ? 'تخطي الطابور لمرة واحدة' : 'Skip queue once',
            pointsCost: 150,
            icon: Icons.fast_forward,
            color: AppTheme.infoColor,
            isArabic: isArabic,
            isDarkMode: isDarkMode,
          ),

          _buildRewardCard(
            title: isArabic ? 'استعارة إضافية' : 'Extra Borrow',
            description: isArabic ? 'استعارة إضافية لمدة شهر' : 'One extra borrow for a month',
            pointsCost: 200,
            icon: FontAwesomeIcons.plus,
            color: AppTheme.primaryColor,
            isArabic: isArabic,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildReferralsTab(bool isArabic, bool isDarkMode, dynamic user) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Referral Code Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.secondaryColor, AppTheme.secondaryColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.secondaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(FontAwesomeIcons.shareNodes, color: Colors.white, size: 32.sp),
                SizedBox(height: 12.h),
                Text(
                  isArabic ? 'كود الإحالة الخاص بك' : 'Your Referral Code',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: _isLoadingReferralCode
                      ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text(
                          _referralCode.isEmpty ? 'Loading...' : _referralCode,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _referralCode.isNotEmpty ? () => _copyReferralCode(_referralCode) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.secondaryColor,
                      ),
                      icon: Icon(Icons.copy),
                      label: Text(isArabic ? 'نسخ' : 'Copy'),
                    ),
                    SizedBox(width: 12.w),
                    ElevatedButton.icon(
                      onPressed: _referralCode.isNotEmpty ? () => _shareReferralCode(_referralCode, isArabic) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.secondaryColor,
                      ),
                      icon: Icon(Icons.share),
                      label: Text(isArabic ? 'مشاركة' : 'Share'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Referral Stats
          Text(
            isArabic ? 'إحصائيات الإحالة' : 'Referral Stats',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: isArabic ? 'إجمالي الإحالات' : 'Total Referrals',
                  value: _isLoadingStats ? '...' : (_referralStats['totalReferrals'] ?? 0).toString(),
                  icon: FontAwesomeIcons.users,
                  color: AppTheme.infoColor,
                  isDarkMode: isDarkMode,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildStatCard(
                  title: isArabic ? 'الأرباح المدفوعة' : 'Paid Earnings',
                  value: _isLoadingStats ? '...' : '${(_referralStats['paidRevenue'] ?? 0.0).toStringAsFixed(0)} LE',
                  icon: FontAwesomeIcons.coins,
                  color: AppTheme.successColor,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // Pending Revenue Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: isArabic ? 'الأرباح المعلقة' : 'Pending Revenue',
                  value: _isLoadingStats ? '...' : '${(_referralStats['pendingRevenue'] ?? 0.0).toStringAsFixed(0)} LE',
                  icon: FontAwesomeIcons.clock,
                  color: AppTheme.warningColor,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // How it works
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkSurface : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'كيف يعمل برنامج الإحالة' : 'How Referral Program Works',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),
                _buildHowItWorksItem(
                  step: '1',
                  text: isArabic 
                    ? 'شارك كود الإحالة مع أصدقائك'
                    : 'Share your referral code with friends',
                ),
                _buildHowItWorksItem(
                  step: '2',
                  text: isArabic 
                    ? 'يستخدم صديقك الكود عند التسجيل'
                    : 'Your friend uses the code during registration',
                ),
                _buildHowItWorksItem(
                  step: '3',
                  text: isArabic 
                    ? 'احصل على مكافآت عند انضمامه'
                    : 'Get rewards when they join and contribute',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard({
    required String title,
    required String description,
    required int pointsCost,
    required IconData icon,
    required Color color,
    required bool isArabic,
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
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '$pointsCost',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                isArabic ? 'نقطة' : 'pts',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksItem({
    required String step,
    required String text,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  void _copyReferralCode(String code) {
    if (code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: code));
      Fluttertoast.showToast(
        msg: 'Referral code copied!',
        backgroundColor: AppTheme.successColor,
        textColor: Colors.white,
      );
    }
  }

  void _shareReferralCode(String code, bool isArabic) {
    if (code.isNotEmpty) {
      final message = isArabic
          ? 'انضم إلى Share Station باستخدام كود الإحالة الخاص بي: $code'
          : 'Join Share Station using my referral code: $code';
      
      Share.share(message);
    }
  }
}