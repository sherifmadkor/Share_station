class Environment {
  static const String appName = 'Share Station';
  static const String appVersion = '1.0.0';

  // Member IDs configuration
  static const int memberIdStart = 100;
  static const int memberIdEnd = 999;

  // Subscription fees
  static const double memberFee = 1500.0;
  static const double clientFee = 750.0;

  // Balance & Points rules
  static const double sellValuePercentage = 0.9;
  static const double borrowValuePercentage = 0.7;
  static const double withdrawalFeePercentage = 0.2;
  static const double referralFeePercentage = 0.2;
  static const int pointsToLERate = 25;
  static const int maxPointsPerTransaction = 2500;

  // Contribution thresholds
  static const int vipContributionThreshold = 15;
  static const int vipFundShareThreshold = 5;

  // Time periods
  static const int balanceExpiryDays = 90;
  static const int suspensionMonths = 6;
  static const int borrowCooldownDays = 7;

  // Borrow limits per tier
  static const Map<int, int> borrowLimitsByContributions = {
    4: 1,
    9: 2,
    15: 3,
    999: 4, // 15+ contributions
  };
}