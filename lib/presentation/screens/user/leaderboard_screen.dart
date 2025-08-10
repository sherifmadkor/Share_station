// lib/presentation/screens/user/leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedPeriod = 'all'; // 'weekly', 'monthly', 'all'
  String _selectedScoreType = 'overall'; // 'C', 'F', 'H', 'E', 'overall'
  List<Map<String, dynamic>> _leaderboardData = [];
  Map<String, dynamic>? _currentUserRank;
  bool _isLoading = false;

  final Map<String, String> _scoreTypeNames = {
    'C': 'Contribution Score',
    'F': 'Funding Score',
    'H': 'Hold Score',
    'E': 'Exchange Score',
    'overall': 'Overall Score',
  };

  final Map<String, IconData> _scoreTypeIcons = {
    'C': FontAwesomeIcons.gamepad,
    'F': FontAwesomeIcons.dollarSign,
    'H': FontAwesomeIcons.clock,
    'E': FontAwesomeIcons.arrowRightArrowLeft,
    'overall': FontAwesomeIcons.trophy,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedScoreType = 'overall';
            break;
          case 1:
            _selectedScoreType = 'C';
            break;
          case 2:
            _selectedScoreType = 'F';
            break;
          case 3:
            _selectedScoreType = 'H';
            break;
          case 4:
            _selectedScoreType = 'E';
            break;
        }
      });
      _loadLeaderboard();
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.currentUser?.uid;

      // Build query based on selected period
      Query query = _firestore.collection('users');

      // Filter by tier for more relevant competition
      query = query.where('tier', whereIn: ['VIP', 'member']);

      // Order by selected score type
      String orderField = _selectedScoreType == 'overall'
          ? 'totalScore'
          : 'score$_selectedScoreType';

      query = query.orderBy(orderField, descending: true).limit(100);

      final snapshot = await query.get();

      _leaderboardData = [];
      int rank = 1;
      int? currentUserRankPosition;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final score = (data[orderField] ?? 0).toDouble();

        // Skip users with zero score
        if (score <= 0) continue;

        final entry = {
          'rank': rank,
          'userId': doc.id,
          'name': data['name'] ?? 'Unknown',
          'tier': data['tier'] ?? 'member',
          'score': score,
          'avatar': data['profilePicture'],
          'isCurrentUser': doc.id == currentUserId,
        };

        _leaderboardData.add(entry);

        if (doc.id == currentUserId) {
          currentUserRankPosition = rank;
          _currentUserRank = entry;
        }

        rank++;
      }

      // If current user not in top 100, fetch their rank
      if (currentUserId != null && currentUserRankPosition == null) {
        final userDoc = await _firestore.collection('users').doc(currentUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final userScore = (userData[orderField] ?? 0).toDouble();

          // Count users with higher score
          final higherScoreCount = await _firestore
              .collection('users')
              .where('tier', whereIn: ['VIP', 'member'])
              .where(orderField, isGreaterThan: userScore)
              .count()
              .get();

          _currentUserRank = {
            'rank': higherScoreCount.count! + 1,
            'userId': currentUserId,
            'name': userData['name'] ?? 'Unknown',
            'tier': userData['tier'] ?? 'member',
            'score': userScore,
            'avatar': userData['profilePicture'],
            'isCurrentUser': true,
          };
        }
      }

      // Keep only top 10 for display
      if (_leaderboardData.length > 10) {
        _leaderboardData = _leaderboardData.take(10).toList();
      }

    } catch (e) {
      _showError('Failed to load leaderboard');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.locale.languageCode == 'ar';
    final isDarkMode = appProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic ? 'لوحة المتصدرين' : 'Leaderboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.calendar_today),
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _loadLeaderboard();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'weekly',
                child: Text(isArabic ? 'أسبوعي' : 'Weekly'),
              ),
              PopupMenuItem(
                value: 'monthly',
                child: Text(isArabic ? 'شهري' : 'Monthly'),
              ),
              PopupMenuItem(
                value: 'all',
                child: Text(isArabic ? 'كل الوقت' : 'All Time'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Score Type Tabs
          Container(
            color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              tabs: [
                _buildTab('Overall', FontAwesomeIcons.trophy, isArabic),
                _buildTab('Contribution', FontAwesomeIcons.gamepad, isArabic),
                _buildTab('Funding', FontAwesomeIcons.dollarSign, isArabic),
                _buildTab('Hold', FontAwesomeIcons.clock, isArabic),
                _buildTab('Exchange', FontAwesomeIcons.arrowRightArrowLeft, isArabic),
              ],
            ),
          ),

          // Current User Rank Card
          if (_currentUserRank != null)
            Container(
              margin: EdgeInsets.all(16.w),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15.r),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Rank Badge
                  Container(
                    width: 60.w,
                    height: 60.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '#${_currentUserRank!['rank']}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'ترتيبك الحالي' : 'Your Current Rank',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.sp,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _currentUserRank!['name'],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Score
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currentUserRank!['score'].toStringAsFixed(0),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isArabic ? 'نقطة' : 'points',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Leaderboard List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _leaderboardData.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FontAwesomeIcons.trophy,
                    size: 64.sp,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    isArabic
                        ? 'لا توجد بيانات متاحة'
                        : 'No data available',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              child: ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: _leaderboardData.length,
                itemBuilder: (context, index) {
                  return _buildLeaderboardItem(
                    _leaderboardData[index],
                    isArabic,
                    isDarkMode,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, bool isArabic) {
    String localizedLabel = label;
    if (isArabic) {
      switch (label) {
        case 'Overall':
          localizedLabel = 'الإجمالي';
          break;
        case 'Contribution':
          localizedLabel = 'المساهمة';
          break;
        case 'Funding':
          localizedLabel = 'التمويل';
          break;
        case 'Hold':
          localizedLabel = 'الاحتفاظ';
          break;
        case 'Exchange':
          localizedLabel = 'التبادل';
          break;
      }
    }

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 16.sp),
          SizedBox(width: 8.w),
          Text(localizedLabel),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(
      Map<String, dynamic> item,
      bool isArabic,
      bool isDarkMode,
      ) {
    final isTopThree = item['rank'] <= 3;
    final isCurrentUser = item['isCurrentUser'] ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.primaryColor.withOpacity(0.1)
            : isDarkMode
            ? Colors.grey[900]
            : Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.primaryColor
              : isTopThree
              ? _getRankColor(item['rank'])
              : Colors.transparent,
          width: isCurrentUser || isTopThree ? 2 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 8.h,
        ),
        leading: Stack(
          children: [
            // Avatar
            CircleAvatar(
              radius: 25.r,
              backgroundColor: _getTierColor(item['tier']),
              child: item['avatar'] != null
                  ? ClipOval(
                child: Image.network(
                  item['avatar'],
                  width: 50.r,
                  height: 50.r,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildDefaultAvatar(item['name']);
                  },
                ),
              )
                  : _buildDefaultAvatar(item['name']),
            ),
            // Rank Badge
            if (isTopThree)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 20.w,
                  height: 20.w,
                  decoration: BoxDecoration(
                    color: _getRankColor(item['rank']),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${item['rank']}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            if (!isTopThree)
              Container(
                width: 30.w,
                child: Text(
                  '#${item['rank']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                    color: Colors.grey,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                item['name'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
              ),
            ),
            // Tier Badge
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8.w,
                vertical: 4.h,
              ),
              decoration: BoxDecoration(
                color: _getTierColor(item['tier']).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                item['tier'].toString().toUpperCase(),
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: _getTierColor(item['tier']),
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              item['score'].toStringAsFixed(0),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: isTopThree ? _getRankColor(item['rank']) : null,
              ),
            ),
            Text(
              isArabic ? 'نقطة' : 'points',
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(
        color: Colors.white,
        fontSize: 20.sp,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.brown[400]!;
      default:
        return Colors.grey;
    }
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'vip':
        return Colors.purple;
      case 'member':
        return AppTheme.primaryColor;
      case 'client':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}