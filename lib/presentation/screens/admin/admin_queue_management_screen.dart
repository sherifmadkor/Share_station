import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../services/queue_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../providers/app_provider.dart';

class AdminQueueManagementScreen extends StatefulWidget {
  final String? gameId;
  
  const AdminQueueManagementScreen({
    Key? key,
    this.gameId,
  }) : super(key: key);

  @override
  State<AdminQueueManagementScreen> createState() => _AdminQueueManagementScreenState();
}

class _AdminQueueManagementScreenState extends State<AdminQueueManagementScreen> {
  final QueueService _queueService = QueueService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _gamesWithQueues = [];
  List<Map<String, dynamic>> _filteredGames = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadQueueData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterQueues();
    });
  }

  void _filterQueues() {
    if (_searchQuery.isEmpty) {
      _filteredGames = List.from(_gamesWithQueues);
    } else {
      _filteredGames = _gamesWithQueues.where((game) {
        final gameName = (game['gameTitle'] ?? '').toString().toLowerCase();
        return gameName.contains(_searchQuery);
      }).toList();
    }
  }
  
  Future<void> _loadQueueData() async {
    setState(() => _isLoading = true);
    
    try {
      _gamesWithQueues = await _queueService.getGamesWithQueues();
      _filteredGames = List.from(_gamesWithQueues);
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading queue data: $e');
      setState(() => _isLoading = false);
    }
  }
  
  
  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(isArabic ? 'إدارة قوائم الانتظار' : 'Queue Management'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadQueueData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isArabic ? 'ابحث عن لعبة أو مستخدم...' : 'Search games or users...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                filled: true,
                fillColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
              ),
            ),
          ),
          
          // Statistics Bar
          if (_gamesWithQueues.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic 
                      ? 'الألعاب: ${_gamesWithQueues.length}'
                      : 'Games: ${_gamesWithQueues.length}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isArabic 
                      ? 'إجمالي القوائم: ${_gamesWithQueues.fold(0, (sum, game) => sum + (game['totalQueue'] as int))}'
                      : 'Total Queues: ${_gamesWithQueues.fold(0, (sum, game) => sum + (game['totalQueue'] as int))}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    Text(
                      isArabic 
                        ? 'النتائج: ${_filteredGames.length}'
                        : 'Results: ${_filteredGames.length}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          
          // Queue List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _gamesWithQueues.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videogame_asset,
                              size: 64.sp,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              isArabic ? 'لا توجد ألعاب في قوائم الانتظار' : 'No games with active queues',
                              style: TextStyle(
                                fontSize: 18.sp,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              isArabic 
                                ? 'ستظهر الألعاب هنا عندما ينضم المستخدمون للقوائم'
                                : 'Games will appear here when users join queues',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : _buildGamesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesList() {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    
    final gamesToShow = _searchQuery.isNotEmpty ? _filteredGames : _gamesWithQueues;
    
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: gamesToShow.length,
      itemBuilder: (context, index) {
        final game = gamesToShow[index];
        final accountsList = game['accountsList'] as List<dynamic>;
        
        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                '${game['totalQueue']}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ),
            title: Text(
              game['gameTitle'] ?? 'Unknown Game',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
            subtitle: Text(
              isArabic 
                ? 'عدد الحسابات: ${accountsList.length} • إجمالي القوائم: ${game['totalQueue']}'
                : 'Accounts: ${accountsList.length} • Total Queues: ${game['totalQueue']}',
              style: TextStyle(fontSize: 14.sp),
            ),
            trailing: Icon(Icons.chevron_right),
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'الحسابات المتاحة:' : 'Available Accounts:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    ...accountsList.map((account) => Container(
                      margin: EdgeInsets.only(bottom: 8.h),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.accentColor,
                          radius: 20.r,
                          child: Text(
                            '${account['queueCount']}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                        title: Text(
                          account['displayName'] ?? 'Unknown Account',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          isArabic 
                            ? 'في القائمة: ${account['queueCount']}'
                            : 'In Queue: ${account['queueCount']}',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            _navigateToAccountQueue(game, account);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 8.h,
                            ),
                          ),
                          child: Text(
                            isArabic ? 'إدارة القائمة' : 'Manage Queue',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _navigateToAccountQueue(Map<String, dynamic> game, Map<String, dynamic> account) {
    Navigator.pushNamed(
      context,
      AppRoutes.adminAccountQueue,
      arguments: {
        'gameId': game['gameId'],
        'gameTitle': game['gameTitle'],
        'accountId': account['accountId'],
        'platform': account['platform'],
        'accountType': account['accountType'],
        'displayName': account['displayName'],
      },
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}