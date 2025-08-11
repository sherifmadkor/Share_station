// lib/main.dart - Updated routes section

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'presentation/providers/app_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/game_provider.dart';
import 'core/theme/app_theme.dart';

// Import all screens
import 'presentation/screens/common/splash_screen.dart';
import 'presentation/screens/common/main_layout.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';

// User screens
import 'presentation/screens/user/user_dashboard.dart';
import 'presentation/screens/user/browse_games_screen.dart';
import 'presentation/screens/user/borrow_game_screen.dart';
import 'presentation/screens/user/my_borrowings_screen.dart';
import 'presentation/screens/user/my_contributions_screen.dart';
import 'presentation/screens/user/add_contribution_screen.dart';
import 'presentation/screens/user/profile_screen.dart';
import 'presentation/screens/user/points_redemption_screen.dart';
import 'presentation/screens/user/balance_details_screen.dart';
import 'presentation/screens/user/queue_management_screen.dart';
import 'presentation/screens/user/sell_game_screen.dart';
import 'presentation/screens/user/account_information_screen.dart';
import 'presentation/screens/user/transaction_history_screen.dart';
import 'presentation/screens/user/rewards_screen.dart';
import 'presentation/screens/user/enhanced_referral_dashboard.dart';
// TODO: Create these screens when needed
// import 'presentation/screens/user/referral_dashboard_screen.dart';
// import 'presentation/screens/user/client_dashboard_screen.dart';
// import 'presentation/screens/user/leaderboard_screen.dart';
// import 'presentation/screens/user/net_metrics_dashboard_screen.dart';

// Admin screens
import 'presentation/screens/admin/admin_dashboard.dart';
// TODO: Create AdminApprovalDashboard screen
// import 'presentation/screens/admin/admin_approval_dashboard.dart';
import 'presentation/screens/admin/manage_games_screen.dart';
import 'presentation/screens/admin/manage_users_screen.dart';
import 'presentation/screens/admin/manage_return_requests_screen.dart';
import 'presentation/screens/admin/admin_queue_management_screen.dart';
import 'presentation/screens/admin/admin_account_queue_screen.dart';
import 'presentation/screens/admin/analytics_screen.dart';
import 'presentation/screens/admin/settings_screen.dart';
import 'presentation/screens/admin/admin_referral_management.dart';

// Routes
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  runApp(ShareStationApp(prefs: prefs));
}

class ShareStationApp extends StatelessWidget {
  final SharedPreferences prefs;

  const ShareStationApp({
    Key? key,
    required this.prefs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider(prefs)),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, _) {
          return ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return MaterialApp(
                title: 'Share Station',
                debugShowCheckedModeBanner: false,

                // Theme
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: appProvider.themeMode,

                // Localization
                locale: appProvider.locale,
                supportedLocales: const [
                  Locale('en', ''),
                  Locale('ar', ''),
                ],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                initialRoute: AppRoutes.splash,
                onGenerateRoute: (settings) {
                  switch (settings.name) {
                    case '/admin/account-queue':
                      final arguments = settings.arguments as Map<String, dynamic>? ?? {};
                      return MaterialPageRoute(
                        builder: (context) => AdminAccountQueueScreen(arguments: arguments),
                      );
                    default:
                      return null;
                  }
                },
                routes: {
                  // Authentication Routes
                  AppRoutes.splash: (context) => const SplashScreen(),
                  AppRoutes.login: (context) => const LoginScreen(),
                  AppRoutes.register: (context) => const RegisterScreen(),

                  // Main Layout
                  AppRoutes.mainLayout: (context) => const MainLayout(),

                  // User Routes
                  AppRoutes.userDashboard: (context) => const UserDashboard(),
                  AppRoutes.browseGames: (context) => const BrowseGamesScreen(),
                  AppRoutes.myBorrowings: (context) => const MyBorrowingsScreen(),
                  AppRoutes.myContributions: (context) => const MyContributionsScreen(),
                  AppRoutes.addContribution: (context) => const AddContributionScreen(),
                  AppRoutes.profileScreen: (context) => const EnhancedProfileScreen(),

                  // User Metrics & Features Routes
                  AppRoutes.pointsRedemption: (context) => const PointsRedemptionScreen(),
                  AppRoutes.balanceDetails: (context) => const BalanceDetailsScreen(),
                  AppRoutes.queueManagement: (context) => const QueueManagementScreen(),
                  AppRoutes.sellGame: (context) => const SellGameScreen(),
                  
                  // Profile Related Routes
                  AppRoutes.accountInformation: (context) => const AccountInformationScreen(),
                  AppRoutes.transactionHistory: (context) => const TransactionHistoryScreen(),
                  AppRoutes.rewards: (context) => const RewardsScreen(),
                  AppRoutes.referralDashboard: (context) => const EnhancedReferralDashboard(),
                  // AppRoutes.clientDashboard: (context) => const ClientDashboardScreen(),
                  // AppRoutes.leaderboard: (context) => const LeaderboardScreen(),
                  // AppRoutes.netMetrics: (context) => const NetMetricsDashboardScreen(),

                  // Admin Routes
                  AppRoutes.adminDashboard: (context) => const AdminDashboard(),
                  // TODO: Create AdminApprovalDashboard screen
                  // AppRoutes.adminApproval: (context) => const AdminApprovalDashboard(),
                  AppRoutes.manageGames: (context) => const ManageGamesScreen(),
                  AppRoutes.manageUsers: (context) => const ManageUsersScreen(),
                  AppRoutes.manageReturns: (context) => const ManageReturnRequestsScreen(),
                  AppRoutes.adminQueueManagement: (context) => const AdminQueueManagementScreen(),
                  AppRoutes.adminAnalytics: (context) => const AnalyticsScreen(),
                  AppRoutes.adminSettings: (context) => const SettingsScreen(),
                  AppRoutes.adminReferralManagement: (context) => const AdminReferralManagement(),
                },

                // Builder for RTL support
                builder: (context, widget) {
                  return Directionality(
                    textDirection: appProvider.locale.languageCode == 'ar'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: widget!,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}