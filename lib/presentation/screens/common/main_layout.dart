// lib/presentation/screens/common/main_layout.dart - Add this to your existing MainLayout

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';

// Import screens
import '../user/user_dashboard.dart';
import '../user/browse_games_screen.dart';
import '../user/my_contributions_screen.dart';
import '../user/profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  
  // Define pages for each tab
  final List<Widget> _pages = [
    const UserDashboard(),
    const BrowseGamesScreen(),
    const MyContributionsScreen(),
    const EnhancedProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.locale.languageCode == 'ar';
    final isDarkMode = appProvider.isDarkMode;
    final isAdmin = authProvider.currentUser?.tier == UserTier.admin;

    return Scaffold(
      body: _pages[_selectedIndex],
      
      // Floating Action Button for Quick Access
      floatingActionButton: _buildQuickAccessFAB(isArabic, isDarkMode),
      
      // Bottom Navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black : Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(.1),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 8.h),
            child: GNav(
              rippleColor: AppTheme.primaryColor.withOpacity(0.3),
              hoverColor: AppTheme.primaryColor.withOpacity(0.1),
              gap: 8,
              activeColor: AppTheme.primaryColor,
              iconSize: 24.sp,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              color: Colors.grey,
              tabs: [
                GButton(
                  icon: Icons.home,
                  text: isArabic ? 'الرئيسية' : 'Home',
                ),
                GButton(
                  icon: Icons.gamepad,
                  text: isArabic ? 'الألعاب' : 'Games',
                ),
                GButton(
                  icon: Icons.inventory,
                  text: isArabic ? 'مساهماتي' : 'My Shares',
                ),
                GButton(
                  icon: Icons.person,
                  text: isArabic ? 'الملف الشخصي' : 'Profile',
                ),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessFAB(bool isArabic, bool isDarkMode) {
    return SpeedDial(
      animatedIcon: AnimatedIcons.menu_close,
      animatedIconTheme: const IconThemeData(size: 22.0),
      backgroundColor: AppTheme.primaryColor,
      visible: true,
      curve: Curves.bounceIn,
      children: [
        // Points Redemption
        SpeedDialChild(
          child: const Icon(Icons.stars, color: Colors.white),
          backgroundColor: Colors.orange,
          label: isArabic ? 'استبدال النقاط' : 'Redeem Points',
          labelStyle: TextStyle(fontSize: 14.sp),
          onTap: () => Navigator.pushNamed(context, AppRoutes.pointsRedemption),
        ),
        
        // Balance Details
        SpeedDialChild(
          child: const Icon(Icons.account_balance_wallet, color: Colors.white),
          backgroundColor: Colors.green,
          label: isArabic ? 'تفاصيل الرصيد' : 'Balance Details',
          labelStyle: TextStyle(fontSize: 14.sp),
          onTap: () => Navigator.pushNamed(context, AppRoutes.balanceDetails),
        ),
        
        // Queue Management
        SpeedDialChild(
          child: const Icon(Icons.queue, color: Colors.white),
          backgroundColor: Colors.blue,
          label: isArabic ? 'إدارة الطابور' : 'Queue Management',
          labelStyle: TextStyle(fontSize: 14.sp),
          onTap: () => Navigator.pushNamed(context, AppRoutes.queueManagement),
        ),
        
        // Referral Dashboard
        SpeedDialChild(
          child: const Icon(Icons.share, color: Colors.white),
          backgroundColor: Colors.purple,
          label: isArabic ? 'لوحة الإحالة' : 'Referral Dashboard',
          labelStyle: TextStyle(fontSize: 14.sp),
          onTap: () => Navigator.pushNamed(context, AppRoutes.referralDashboard),
        ),
        
        // Leaderboard
        SpeedDialChild(
          child: const Icon(Icons.leaderboard, color: Colors.white),
          backgroundColor: Colors.amber,
          label: isArabic ? 'المتصدرين' : 'Leaderboard',
          labelStyle: TextStyle(fontSize: 14.sp),
          onTap: () => Navigator.pushNamed(context, AppRoutes.leaderboard),
        ),
        
        // Net Metrics
        SpeedDialChild(
          child: const Icon(Icons.analytics, color: Colors.white),
          backgroundColor: Colors.teal,
          label: isArabic ? 'المقاييس الصافية' : 'Net Metrics',
          labelStyle: TextStyle(fontSize: 14.sp),
          onTap: () => Navigator.pushNamed(context, AppRoutes.netMetrics),
        ),
      ],
    );
  }
}

// Note: You'll need to add this package to pubspec.yaml:
// flutter_speed_dial: ^6.2.0