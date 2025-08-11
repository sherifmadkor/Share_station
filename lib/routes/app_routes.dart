// lib/routes/app_routes.dart

class AppRoutes {
  // Authentication
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Main Layout
  static const String mainLayout = '/main';

  // User Screens
  static const String userDashboard = '/user-dashboard';
  static const String browseGames = '/browse-games';
  static const String borrowGame = '/borrow-game';
  static const String myContributions = '/my-contributions';
  static const String addContribution = '/add-contribution';
  static const String profileScreen = '/profile';

  // User Metrics & Features
  static const String pointsRedemption = '/points-redemption';
  static const String balanceDetails = '/balance-details';
  static const String queueManagement = '/queue-management';
  static const String sellGame = '/sell-game';
  static const String referralDashboard = '/referral-dashboard';
  static const String clientDashboard = '/client-dashboard';
  static const String leaderboard = '/leaderboard';
  static const String netMetrics = '/net-metrics';
  
  // Profile Related Screens
  static const String accountInformation = '/account-information';
  static const String transactionHistory = '/transaction-history';
  static const String rewards = '/rewards';

  // Admin Screens
  static const String adminDashboard = '/admin-dashboard';
  static const String adminApproval = '/admin-approval';
  static const String manageGames = '/manage-games';
  static const String manageUsers = '/manage-users';
  static const String adminAnalytics = '/admin-analytics';
  static const String adminSettings = '/admin-settings';
  static const String adminReferralManagement = '/admin-referral-management';
}