import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide StatefulWidget;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';

// Import screens
import '../user/user_dashboard.dart';
import '../user/browse_games_screen.dart' hide StatefulWidget;
import '../user/my_borrowings_screen.dart';
import '../user/profile_screen.dart';
import '../admin/admin_dashboard.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  // User screens
  final List<Widget> _userScreens = [
    const UserDashboard(),
    const BrowseGamesScreen(),
    const MyBorrowingsScreen(),
    const EnhancedProfileScreen(),
  ];

  // Admin screens
  final List<Widget> _adminScreens = [
    const AdminDashboard(),
    const BrowseGamesScreen(), // Admin can also browse
    const MyBorrowingsScreen(), // Admin can see their borrowings
    const EnhancedProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final isAdmin = authProvider.isAdmin;

    // Select screens based on user role
    final screens = isAdmin ? _adminScreens : _userScreens;

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkSurface : Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(0.1),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 8.h),
            child: GNav(
              rippleColor: AppTheme.primaryColor.withOpacity(0.1),
              hoverColor: AppTheme.primaryColor.withOpacity(0.1),
              gap: 8,
              activeColor: Colors.white,
              iconSize: 24.sp,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: AppTheme.primaryColor,
              color: isDarkMode ? Colors.white60 : Colors.black54,
              tabs: [
                GButton(
                  icon: isAdmin ? FontAwesomeIcons.gaugeHigh : FontAwesomeIcons.house,
                  text: isArabic
                      ? (isAdmin ? 'لوحة التحكم' : 'الرئيسية')
                      : (isAdmin ? 'Dashboard' : 'Home'),
                ),
                GButton(
                  icon: FontAwesomeIcons.gamepad,
                  text: isArabic ? 'الألعاب' : 'Games',
                ),
                GButton(
                  icon: FontAwesomeIcons.handHolding,
                  text: isArabic ? 'استعاراتي' : 'Borrowings',
                ),
                GButton(
                  icon: FontAwesomeIcons.user,
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
}