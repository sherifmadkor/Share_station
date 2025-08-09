class AppRoutes {
  // Auth Routes
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';

  // User Routes
  static const String userDashboard = '/user-dashboard';
  static const String browseGames = '/browse-games';
  static const String gameDetails = '/game-details';
  static const String myBorrowings = '/my-borrowings';
  static const String myContributions = '/my-contributions';
  static const String userProfile = '/user-profile';
  static const String borrowHistory = '/borrow-history';
  static const String referrals = '/referrals';

  // Admin Routes
  static const String adminDashboard = '/admin-dashboard';
  static const String manageUsers = '/manage-users';
  static const String userDetails = '/user-details';
  static const String manageGames = '/manage-games';
  static const String manageContributions = '/manage-contributions';
  static const String addGame = '/add-game';
  static const String editGame = '/edit-game';
  static const String manageVault = '/manage-vault';
  static const String analytics = '/analytics';
  static const String adminSettings = '/admin-settings';
  static const String pendingApprovals = '/pending-approvals';
  static const String borrowRequests = '/borrow-requests';
  static const String contributions = '/contributions';
  static const String systemLogs = '/system-logs';
  static const String dataMigration = '/data-migration';


  // Common Routes
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String help = '/help';
  static const String about = '/about';

  // List of routes that don't require authentication
  static const List<String> publicRoutes = [
    splash,
    login,
    register,
    forgotPassword,
    onboarding,
  ];

  // List of admin-only routes
  static const List<String> adminRoutes = [
    adminDashboard,
    manageUsers,
    userDetails,
    manageGames,
    addGame,
    editGame,
    manageVault,
    analytics,
    adminSettings,
    pendingApprovals,
    borrowRequests,
    contributions,
    systemLogs,
    dataMigration,
  ];

  // List of user routes
  static const List<String> userRoutes = [
    userDashboard,
    browseGames,
    gameDetails,
    myBorrowings,
    myContributions,
    userProfile,
    borrowHistory,
    referrals,
  ];
}