import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

// Import providers
import 'presentation/providers/app_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/game_provider.dart';
// Temporarily comment out missing providers
// import 'presentation/providers/user_provider.dart';

// Import screens
import 'presentation/screens/common/splash_screen.dart';
import 'presentation/screens/common/main_layout.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/user/user_dashboard.dart';
import 'presentation/screens/admin/admin_dashboard.dart';

// ADD THESE NEW IMPORTS
import 'presentation/screens/user/add_contribution_screen.dart';
import 'presentation/screens/user/my_contributions_screen.dart';
import 'presentation/screens/user/borrow_request_screen.dart';
import 'presentation/screens/admin/admin_approval_dashboard.dart';

// Import theme
import 'core/theme/app_theme.dart';

// Import routes
import 'routes/app_routes.dart';
// import 'routes/route_generator.dart';

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
        // Temporarily comment out missing providers
        // ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, _) {
          return ScreenUtilInit(
            designSize: const Size(375, 812), // iPhone X size as reference
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

                // Routes - UPDATED WITH NEW ROUTES
                initialRoute: AppRoutes.splash,
                routes: {
                  AppRoutes.splash: (context) => const SplashScreen(),
                  AppRoutes.login: (context) => const LoginScreen(),
                  AppRoutes.register: (context) => const RegisterScreen(),
                  AppRoutes.userDashboard: (context) => const MainLayout(),
                  AppRoutes.adminDashboard: (context) => const MainLayout(),

                  // ADD THESE NEW ROUTES
                  '/add-contribution': (context) => const AddContributionScreen(),
                  '/my-contributions': (context) => const MyContributionsScreen(),
                  '/admin-approval-dashboard': (context) => const AdminApprovalDashboard(),
                },

                // ADD THIS onGenerateRoute FOR ROUTES WITH PARAMETERS
                onGenerateRoute: (settings) {
                  // Handle BorrowRequestScreen which needs a game parameter
                  if (settings.name == '/borrow-request') {
                    final args = settings.arguments as Map<String, dynamic>?;
                    if (args != null && args['game'] != null) {
                      return MaterialPageRoute(
                        builder: (context) => BorrowRequestScreen(
                          game: args['game'],
                        ),
                      );
                    }
                  }

                  // Return null for unhandled routes
                  return null;
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