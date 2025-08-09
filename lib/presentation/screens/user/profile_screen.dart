// lib/presentation/screens/user/enhanced_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../user/add_contribution_screen.dart';

class EnhancedProfileScreen extends StatefulWidget {
  const EnhancedProfileScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedProfileScreen> createState() => _EnhancedProfileScreenState();
}

class _EnhancedProfileScreenState extends State<EnhancedProfileScreen> {

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final user = authProvider.currentUser;

    // Show loading indicator if user is null
    if (user == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // Show loading state while waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            );
          }

          // Handle errors gracefully
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppTheme.errorColor,
                    size: 60.sp,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    isArabic ? 'حدث خطأ في تحميل البيانات' : 'Error loading data',
                    style: TextStyle(fontSize: 16.sp),
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () {
                      // Trigger rebuild
                      setState(() {});
                    },
                    child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                  ),
                ],
              ),
            );
          }

          Map<String, dynamic> userData = {};
          if (snapshot.hasData && snapshot.data!.exists) {
            try {
              userData = snapshot.data!.data() as Map<String, dynamic>;
            } catch (e) {
              print('Error parsing user data: $e');
            }
          }

          return _buildProfileContent(
            context,
            userData,
            user,
            isArabic,
            isDarkMode,
          );
        },
      ),
    );
  }

  Widget _buildProfileContent(
      BuildContext context,
      Map<String, dynamic> userData,
      UserModel? user,
      bool isArabic,
      bool isDarkMode,
      ) {
    // Calculate VIP progress - prioritize Firestore data and ensure int type
    final int totalShares = userData.isNotEmpty
        ? (userData['totalShares'] ?? 0).toInt()
        : (user?.totalShares ?? 0);
    final int fundShares = userData.isNotEmpty
        ? (userData['fundShares'] ?? 0).toInt()
        : (user?.fundShares ?? 0);
    final vipProgressPercentage = ((totalShares / 15) * 0.7 + (fundShares / 5) * 0.3)
        .clamp(0.0, 1.0);
    final isVipEligible = totalShares >= 15 && fundShares >= 5;

    // Get tier - handle both String from Firestore and enum from UserModel
    UserTier tier;
    if (userData.isNotEmpty && userData['tier'] != null) {
      // Data from Firestore - will be a String
      tier = UserTier.fromString(userData['tier'].toString());
    } else if (user?.tier != null) {
      // Data from UserModel - already a UserTier enum
      tier = user!.tier!;
    } else {
      // Default
      tier = UserTier.member;
    }

    final isVip = tier == UserTier.vip;
    final isAdmin = tier == UserTier.admin;

    // Get suspension status
    final status = userData.isNotEmpty && userData['status'] != null
        ? userData['status'].toString()
        : 'active';
    final isSuspended = status == 'suspended';

    DateTime? lastContribution;
    if (userData.isNotEmpty && userData['lastContributionDate'] != null) {
      try {
        lastContribution = (userData['lastContributionDate'] as Timestamp).toDate();
      } catch (e) {
        // Handle if it's not a Timestamp
        lastContribution = null;
      }
    }

    final daysSinceContribution = lastContribution != null
        ? DateTime.now().difference(lastContribution).inDays
        : 999;
    final daysUntilSuspension = 180 - daysSinceContribution;
    final showWarning = !isVip && !isAdmin && daysUntilSuspension <= 60;
    final criticalWarning = !isVip && !isAdmin && daysUntilSuspension <= 30;

    // Determine gradient colors based on tier
    List<Color> gradientColors;
    if (isAdmin) {
      gradientColors = [Colors.purple, Colors.purple.shade700];
    } else if (isVip) {
      gradientColors = [Colors.amber, Colors.amber.shade700];
    } else {
      gradientColors = [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.7)];
    }

    return CustomScrollView(
      slivers: [
        // Enhanced Profile Header
        SliverAppBar(
          expandedHeight: 280.h,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Profile Picture with Status Indicator
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50.r,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            size: 60.sp,
                            color: gradientColors[0],
                          ),
                        ),
                        if (isSuspended)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: EdgeInsets.all(4.w),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.block,
                                color: Colors.white,
                                size: 20.sp,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    // User Name
                    Text(
                      user?.name ?? 'User',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    // Member ID and Tier with Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ID: ${user?.memberId ?? '000'}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: isVip
                                  ? Colors.amber
                                  : isAdmin
                                  ? Colors.purple
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              children: [
                                if (isVip || isAdmin)
                                  Icon(
                                    isVip ? Icons.star : Icons.shield,
                                    color: Colors.white,
                                    size: 14.sp,
                                  ),
                                if (isVip || isAdmin) SizedBox(width: 4.w),
                                Text(
                                  _getTierText(tier, isArabic),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.h),
                    // Status Indicator
                    if (isSuspended)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          isArabic ? 'حساب موقوف' : 'Account Suspended',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Profile Content
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // VIP Progress Section (if not already VIP)
                if (!isVip && !isAdmin && !isSuspended) ...[
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.withOpacity(0.1),
                          Colors.amber.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 24.sp,
                            ),
                            SizedBox(width: 8.w),
                            // Wrap the Text widget with Expanded
                            Expanded(
                              child: Text(
                                isArabic ? 'التقدم نحو VIP' : 'VIP Progress',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),

                        // Overall Progress
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return LinearPercentIndicator(
                              width: constraints.maxWidth, // Use the available width from the parent
                              lineHeight: 22.h,
                              percent: vipProgressPercentage,
                              center: Text(
                                '${(vipProgressPercentage * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                ),
                              ),
                              backgroundColor: Colors.grey.shade300,
                              progressColor: isVipEligible ? Colors.green : Colors.amber,
                              barRadius: Radius.circular(11.r),
                            );
                          },
                        ),

                        SizedBox(height: 16.h),

                        // Requirements
                        Row(
                          children: [
                            Expanded(
                              child: _buildRequirementCard(
                                icon: Icons.gamepad,
                                label: isArabic ? 'إجمالي المساهمات' : 'Total Shares',
                                current: totalShares,
                                required: 15,
                                color: totalShares >= 15 ? Colors.green : Colors.orange,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _buildRequirementCard(
                                icon: Icons.attach_money,
                                label: isArabic ? 'المساهمات المالية' : 'Fund Shares',
                                current: fundShares,
                                required: 5,
                                color: fundShares >= 5 ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),

                        if (isVipEligible) ...[
                          SizedBox(height: 12.h),
                          Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20.sp,
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    isArabic
                                        ? 'تهانينا! أنت مؤهل لعضوية VIP'
                                        : 'Congratulations! You are eligible for VIP',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],

                // Suspension Warning Section
                if (showWarning && !isSuspended) ...[
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: criticalWarning
                          ? Colors.red.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: criticalWarning ? Colors.red : Colors.orange,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: criticalWarning ? Colors.red : Colors.orange,
                              size: 24.sp,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                isArabic
                                    ? 'تحذير: حسابك معرض للإيقاف'
                                    : 'Warning: Account at Risk of Suspension',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: criticalWarning ? Colors.red : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          isArabic
                              ? 'لم تساهم منذ $daysSinceContribution يوم. سيتم إيقاف حسابك بعد $daysUntilSuspension يوم من عدم المساهمة.'
                              : 'You haven\'t contributed for $daysSinceContribution days. Your account will be suspended in $daysUntilSuspension days without contribution.',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          isArabic
                              ? 'قم بإضافة مساهمة جديدة لتجنب الإيقاف'
                              : 'Add a new contribution to avoid suspension',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: criticalWarning ? Colors.red : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],

                // Statistics Section
                Text(
                  isArabic ? 'الإحصائيات' : 'Statistics',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.account_balance_wallet,
                        label: isArabic ? 'الرصيد' : 'Balance',
                        value: '${user?.totalBalance.toStringAsFixed(0) ?? '0'} LE',
                        color: AppTheme.successColor,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.stars,
                        label: isArabic ? 'النقاط' : 'Points',
                        value: '${user?.points ?? 0}',
                        color: AppTheme.warningColor,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.trending_up,
                        label: isArabic ? 'حد المحطة' : 'Station Limit',
                        value: '${user?.stationLimit ?? 0}',
                        color: AppTheme.primaryColor,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.gamepad,
                        label: isArabic ? 'المساهمات' : 'Contributions',
                        value: '${totalShares}',
                        color: AppTheme.infoColor,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),

                // Quick Actions Section
                Text(
                  isArabic ? 'الإجراءات السريعة' : 'Quick Actions',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),

                // Add Contribution Button (Original Style)
                _buildActionButton(
                  icon: FontAwesomeIcons.plus,
                  title: isArabic ? 'إضافة مساهمة' : 'Add Contribution',
                  subtitle: isArabic
                      ? 'ساهم بلعبة أو مبلغ مالي'
                      : 'Contribute a game or fund',
                  color: isSuspended ? Colors.grey : AppTheme.successColor,
                  onTap: isSuspended
                      ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic
                              ? 'الحساب موقوف. قم بإضافة مساهمة لإعادة التفعيل'
                              : 'Account suspended. Add a contribution to reactivate',
                        ),
                      ),
                    );
                  }
                      : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddContributionScreen(),
                      ),
                    );
                  },
                  isDarkMode: isDarkMode,
                ),

                SizedBox(height: 24.h),

                // Activity Information
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppTheme.darkSurface
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'معلومات النشاط' : 'Activity Information',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _buildInfoRow(
                        label: isArabic ? 'تاريخ الانضمام' : 'Join Date',
                        value: userData.isNotEmpty && userData['joinDate'] != null
                            ? _formatDate(
                          (userData['joinDate'] as Timestamp).toDate(),
                          isArabic,
                        )
                            : '-',
                        icon: Icons.calendar_today,
                      ),
                      SizedBox(height: 8.h),
                      _buildInfoRow(
                        label: isArabic ? 'آخر مساهمة' : 'Last Contribution',
                        value: lastContribution != null
                            ? _formatRelativeTime(lastContribution, isArabic)
                            : isArabic
                            ? 'لا توجد مساهمات'
                            : 'No contributions',
                        icon: Icons.access_time,
                      ),
                      if (isVip && userData.isNotEmpty && userData['vipPromotionDate'] != null) ...[
                        SizedBox(height: 8.h),
                        _buildInfoRow(
                          label: isArabic ? 'ترقية VIP' : 'VIP Promotion',
                          value: _formatDate(
                            (userData['vipPromotionDate'] as Timestamp).toDate(),
                            isArabic,
                          ),
                          icon: Icons.star,
                        ),
                      ],
                      if (isSuspended && userData.isNotEmpty && userData['suspensionDate'] != null) ...[
                        SizedBox(height: 8.h),
                        _buildInfoRow(
                          label: isArabic ? 'تاريخ الإيقاف' : 'Suspension Date',
                          value: _formatDate(
                            (userData['suspensionDate'] as Timestamp).toDate(),
                            isArabic,
                          ),
                          icon: Icons.block,
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: 24.h),

                // Settings Section
                Text(
                  isArabic ? 'الإعدادات' : 'Settings',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),

                _buildMenuItem(
                  icon: Icons.person_outline,
                  title: isArabic ? 'معلومات الحساب' : 'Account Information',
                  onTap: () {
                    // Navigate to account info
                  },
                  isDarkMode: isDarkMode,
                ),
                _buildMenuItem(
                  icon: Icons.history,
                  title: isArabic ? 'سجل المعاملات' : 'Transaction History',
                  onTap: () {
                    // Navigate to transaction history
                  },
                  isDarkMode: isDarkMode,
                ),
                _buildMenuItem(
                  icon: Icons.card_giftcard,
                  title: isArabic ? 'المكافآت والإحالات' : 'Rewards & Referrals',
                  onTap: () {
                    // Navigate to rewards
                  },
                  isDarkMode: isDarkMode,
                ),
                _buildMenuItem(
                  icon: Icons.notifications_outlined,
                  title: isArabic ? 'الإشعارات' : 'Notifications',
                  onTap: () {
                    // Navigate to notifications
                  },
                  isDarkMode: isDarkMode,
                ),
                _buildMenuItem(
                  icon: Icons.language,
                  title: isArabic ? 'اللغة' : 'Language',
                  trailing: Text(
                    isArabic ? 'العربية' : 'English',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 14.sp,
                    ),
                  ),
                  onTap: () {
                    Provider.of<AppProvider>(context, listen: false)
                        .toggleLanguage();
                  },
                  isDarkMode: isDarkMode,
                ),
                _buildMenuItem(
                  icon: isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  title: isArabic ? 'المظهر' : 'Theme',
                  trailing: Switch(
                    value: isDarkMode,
                    onChanged: (value) {
                      Provider.of<AppProvider>(context, listen: false)
                          .toggleTheme();
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                  onTap: () {
                    Provider.of<AppProvider>(context, listen: false)
                        .toggleTheme();
                  },
                  isDarkMode: isDarkMode,
                ),
                _buildMenuItem(
                  icon: Icons.help_outline,
                  title: isArabic ? 'المساعدة والدعم' : 'Help & Support',
                  onTap: () {
                    // Navigate to help
                  },
                  isDarkMode: isDarkMode,
                ),
                _buildMenuItem(
                  icon: Icons.info_outline,
                  title: isArabic ? 'حول التطبيق' : 'About App',
                  onTap: () {
                    // Navigate to about
                  },
                  isDarkMode: isDarkMode,
                ),

                SizedBox(height: 24.h),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: () {
                      _showLogoutDialog(context, isArabic);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: Colors.white),
                        SizedBox(width: 8.w),
                        Text(
                          isArabic ? 'تسجيل الخروج' : 'Logout',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementCard({
    required IconData icon,
    required String label,
    required int current,
    required int required,
    required Color color,
  }) {
    final progress = (current / required).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22.sp),
          SizedBox(height: 6.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$current / $required',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(2.r),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 3.h,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode
            ? color.withOpacity(0.2)
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 28.sp,
          ),
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
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: isDarkMode
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppTheme.darkSurface
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: AppTheme.primaryColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
          ),
        ),
        trailing: trailing ?? Icon(
          Icons.chevron_right,
          color: Colors.grey,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: Colors.grey),
        SizedBox(width: 8.w),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _getTierText(UserTier? tier, bool isArabic) {
    if (tier == null) return '';

    switch (tier) {
      case UserTier.admin:
        return isArabic ? 'مدير' : 'Admin';
      case UserTier.vip:
        return isArabic ? 'VIP' : 'VIP';
      case UserTier.member:
        return isArabic ? 'عضو' : 'Member';
      case UserTier.client:
        return isArabic ? 'عميل' : 'Client';
      case UserTier.user:
        return isArabic ? 'مستخدم' : 'User';
    }
  }

  String _formatDate(DateTime date, bool isArabic) {
    final months = isArabic
        ? ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر']
        : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatRelativeTime(DateTime date, bool isArabic) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      final months = difference.inDays ~/ 30;
      return isArabic
          ? 'منذ $months ${months == 1 ? 'شهر' : 'شهور'}'
          : '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return isArabic
          ? 'منذ ${difference.inDays} ${difference.inDays == 1 ? 'يوم' : 'أيام'}'
          : '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return isArabic
          ? 'منذ ${difference.inHours} ${difference.inHours == 1 ? 'ساعة' : 'ساعات'}'
          : '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else {
      return isArabic ? 'منذ قليل' : 'Recently';
    }
  }

  void _showLogoutDialog(BuildContext context, bool isArabic) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            isArabic ? 'تسجيل الخروج' : 'Logout',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            isArabic
                ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟'
                : 'Are you sure you want to logout?',
            style: TextStyle(fontSize: 16.sp),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                isArabic ? 'إلغاء' : 'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16.sp,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                await authProvider.signOut();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                      (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                isArabic ? 'تسجيل الخروج' : 'Logout',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}