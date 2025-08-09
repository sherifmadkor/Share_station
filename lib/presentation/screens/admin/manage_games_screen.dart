// lib/presentation/screens/admin/manage_games_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_model.dart' as game_models;
import '../../widgets/custom_loading.dart';

class ManageGamesScreen extends StatefulWidget {
  const ManageGamesScreen({Key? key}) : super(key: key);

  @override
  State<ManageGamesScreen> createState() => _ManageGamesScreenState();
}

class _ManageGamesScreenState extends State<ManageGamesScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  // Filters
  String _searchQuery = '';
  game_models.LenderTier? _selectedCategory;
  game_models.Platform? _selectedPlatform;

  // Statistics
  int _totalGames = 0;
  int _totalAccounts = 0;
  int _availableSlots = 0;
  int _borrowedSlots = 0;
  double _totalValue = 0;
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    try {
      final gamesSnapshot = await _firestore.collection('games').get();

      int totalGames = 0;
      int totalAccounts = 0;
      int availableSlots = 0;
      int borrowedSlots = 0;
      double totalValue = 0;
      double totalRevenue = 0;

      for (var doc in gamesSnapshot.docs) {
        final data = doc.data();
        totalGames++;

        // Count accounts and slots
        if (data['accounts'] != null) {
          final accounts = data['accounts'] as List<dynamic>;
          totalAccounts += accounts.length;

          for (var account in accounts) {
            final slots = account['slots'] as Map<String, dynamic>? ?? {};
            for (var slot in slots.values) {
              if (slot['status'] == 'available') {
                availableSlots++;
              } else if (slot['status'] == 'taken') {
                borrowedSlots++;
              }
            }
          }
        }

        totalValue += (data['gameValue'] ?? data['totalValue'] ?? 0).toDouble();
        totalRevenue += (data['totalRevenues'] ?? 0).toDouble();
      }

      setState(() {
        _totalGames = totalGames;
        _totalAccounts = totalAccounts;
        _availableSlots = availableSlots;
        _borrowedSlots = borrowedSlots;
        _totalValue = totalValue;
        _totalRevenue = totalRevenue;
      });
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  void _showAddEditGameDialog({Map<String, dynamic>? gameData, String? gameId}) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    // Controllers for game details
    final titleController = TextEditingController(text: gameData?['title'] ?? '');
    final includedTitlesController = TextEditingController(
        text: (gameData?['includedTitles'] as List<dynamic>?)?.join(', ') ?? ''
    );
    final coverImageController = TextEditingController(text: gameData?['coverImageUrl'] ?? '');
    final descriptionController = TextEditingController(text: gameData?['description'] ?? '');
    final gameValueController = TextEditingController(
        text: gameData?['gameValue']?.toString() ?? gameData?['totalValue']?.toString() ?? ''
    );

    // Show dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
          title: Text(
            gameId == null
                ? (isArabic ? 'إضافة لعبة جديدة' : 'Add New Game')
                : (isArabic ? 'تعديل اللعبة' : 'Edit Game'),
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
          content: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title Field
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'عنوان اللعبة' : 'Game Title',
                      prefixIcon: Icon(FontAwesomeIcons.gamepad),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Included Titles
                  TextField(
                    controller: includedTitlesController,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'العناوين المضمنة' : 'Included Titles',
                      helperText: isArabic ? 'افصل بين العناوين بفاصلة' : 'Separate titles with comma',
                      prefixIcon: Icon(Icons.list),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Game Value
                  TextField(
                    controller: gameValueController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'قيمة اللعبة (LE)' : 'Game Value (LE)',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Cover Image URL
                  TextField(
                    controller: coverImageController,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'رابط صورة الغلاف' : 'Cover Image URL',
                      prefixIcon: Icon(Icons.image),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Description
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'الوصف' : 'Description',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                isArabic ? 'إلغاء' : 'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || gameValueController.text.isEmpty) {
                  Fluttertoast.showToast(
                    msg: isArabic ? 'يرجى ملء الحقول المطلوبة' : 'Please fill required fields',
                    backgroundColor: AppTheme.errorColor,
                  );
                  return;
                }

                try {
                  final updates = {
                    'title': titleController.text.trim(),
                    'includedTitles': includedTitlesController.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                    'gameValue': double.parse(gameValueController.text),
                    'coverImageUrl': coverImageController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  if (gameId != null) {
                    // Update existing game
                    await _firestore.collection('games').doc(gameId).update(updates);
                    Fluttertoast.showToast(
                      msg: isArabic ? 'تم تحديث اللعبة بنجاح' : 'Game updated successfully',
                      backgroundColor: AppTheme.successColor,
                    );
                  } else {
                    // Add new game (basic structure - accounts will be added separately)
                    updates['createdAt'] = FieldValue.serverTimestamp();
                    updates['accounts'] = [];
                    updates['totalAccounts'] = 0;
                    updates['availableAccounts'] = 0;
                    updates['totalValue'] = 0;
                    updates['totalRevenues'] = 0;
                    updates['isActive'] = true;
                    updates['lenderTier'] = 'member';

                    await _firestore.collection('games').add(updates);
                    Fluttertoast.showToast(
                      msg: isArabic ? 'تمت إضافة اللعبة بنجاح' : 'Game added successfully',
                      backgroundColor: AppTheme.successColor,
                    );
                  }

                  Navigator.pop(dialogContext);
                  _loadStatistics();
                } catch (e) {
                  Fluttertoast.showToast(
                    msg: isArabic ? 'حدث خطأ' : 'An error occurred',
                    backgroundColor: AppTheme.errorColor,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: Text(
                gameId == null
                    ? (isArabic ? 'إضافة' : 'Add')
                    : (isArabic ? 'حفظ' : 'Save'),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAccountDetailsDialog(String gameId, Map<String, dynamic> gameData, Map<String, dynamic> account) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    // Controllers for account details
    final emailController = TextEditingController(text: account['credentials']?['email'] ?? '');
    final passwordController = TextEditingController(text: account['credentials']?['password'] ?? '');
    
    // Fix: Ensure edition has a valid value from the list
    String editionValue = account['edition'] ?? 'Standard';
    final availableEditions = [
      'Standard', 'Deluxe', 'Ultimate', 'Gold', 'Complete', 'Premium',
      'Collectors', 'Special', 'Anniversary', 'Directors Cut',
      'Game of the Year', 'Definitive', 'Enhanced', 'Remastered'
    ];
    
    // Ensure the edition value exists in the list
    if (!availableEditions.contains(editionValue)) {
      editionValue = 'Standard';
    }
    
    String regionValue = account['region'] ?? 'US';
    final availableRegions = [
      'US', 'EU', 'UK', 'JP', 'AU', 'CA', 'BR', 'MX', 'RU', 'IN',
      'KR', 'TW', 'HK', 'SG', 'MENA', 'ZA', 'GLOBAL'
    ];
    
    // Ensure the region value exists in the list
    if (!availableRegions.contains(regionValue)) {
      regionValue = 'US';
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
          title: Text(
            isArabic ? 'تفاصيل الحساب' : 'Account Details',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
          content: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account ID
                  ListTile(
                    leading: Icon(Icons.fingerprint, color: AppTheme.primaryColor),
                    title: Text(isArabic ? 'معرف الحساب' : 'Account ID'),
                    subtitle: Text(account['accountId'] ?? 'N/A'),
                  ),

                  // Contributor Info
                  ListTile(
                    leading: Icon(Icons.person, color: AppTheme.primaryColor),
                    title: Text(isArabic ? 'المساهم' : 'Contributor'),
                    subtitle: Text('${account['contributorName'] ?? 'Unknown'} (ID: ${account['contributorId'] ?? 'N/A'})'),
                  ),

                  // Date Added
                  if (account['dateAdded'] != null)
                    ListTile(
                      leading: Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                      title: Text(isArabic ? 'تاريخ الإضافة' : 'Date Added'),
                      subtitle: Text(
                        account['dateAdded'] is Timestamp
                            ? DateFormat('dd/MM/yyyy').format((account['dateAdded'] as Timestamp).toDate())
                            : 'N/A'
                      ),
                    ),

                  Divider(),

                  // Editable Fields
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'البريد الإلكتروني' : 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'كلمة المرور' : 'Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Edition Dropdown - FIXED
                  DropdownButtonFormField<String>(
                    value: editionValue,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'الإصدار' : 'Edition',
                      prefixIcon: Icon(Icons.book),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    items: availableEditions.map((edition) => DropdownMenuItem(
                      value: edition,
                      child: Text(edition),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        editionValue = value;
                      }
                    },
                  ),
                  SizedBox(height: 12.h),

                  // Region Dropdown - FIXED
                  DropdownButtonFormField<String>(
                    value: regionValue,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'المنطقة' : 'Region',
                      prefixIcon: Icon(Icons.language),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    items: availableRegions.map((region) => DropdownMenuItem(
                      value: region,
                      child: Text(region),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        regionValue = value;
                      }
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Platforms and Sharing Options
                  Text(
                    isArabic ? 'المنصات المدعومة:' : 'Supported Platforms:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 8.w,
                    children: (account['platforms'] as List<dynamic>? ?? [])
                        .map((platform) => Chip(
                      label: Text(platform.toString().toUpperCase()),
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                    ))
                        .toList(),
                  ),
                  SizedBox(height: 12.h),

                  Text(
                    isArabic ? 'خيارات المشاركة:' : 'Sharing Options:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 8.w,
                    children: (account['sharingOptions'] as List<dynamic>? ?? [])
                        .map((option) => Chip(
                      label: Text(option.toString().toUpperCase()),
                      backgroundColor: Colors.green.withOpacity(0.2),
                    ))
                        .toList(),
                  ),

                  // Slots Status
                  SizedBox(height: 16.h),
                  Text(
                    isArabic ? 'حالة الفتحات:' : 'Slots Status:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...((account['slots'] as Map<String, dynamic>? ?? {}).entries.map((entry) {
                    final slot = entry.value as Map<String, dynamic>;
                    final status = slot['status'] ?? 'unknown';
                    final borrowerId = slot['borrowerId'];

                    return ListTile(
                      leading: Icon(
                        status == 'available' ? Icons.check_circle : Icons.cancel,
                        color: status == 'available' ? Colors.green : Colors.red,
                      ),
                      title: Text(entry.key.toUpperCase()),
                      subtitle: borrowerId != null
                          ? Text('Borrowed by: ${slot['borrowerName'] ?? borrowerId}')
                          : Text(status),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Toggle availability button
                          IconButton(
                            icon: Icon(
                              status == 'available' ? Icons.lock : Icons.lock_open,
                              color: status == 'available' ? Colors.orange : Colors.green,
                            ),
                            onPressed: () => _toggleSlotAvailability(gameId, account['accountId'], entry.key, status),
                            tooltip: status == 'available' 
                                ? (isArabic ? 'جعله غير متاح' : 'Make Unavailable')
                                : (isArabic ? 'جعله متاح' : 'Make Available'),
                          ),
                          if (status == 'taken')
                            IconButton(
                              icon: Icon(Icons.refresh),
                              onPressed: () => _returnSlot(gameId, account['accountId'], entry.key),
                              tooltip: isArabic ? 'إرجاع' : 'Return',
                            ),
                        ],
                      ),
                    );
                  }).toList()),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                isArabic ? 'إلغاء' : 'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Update account credentials
                try {
                  final gameDoc = await _firestore.collection('games').doc(gameId).get();
                  final accounts = List<Map<String, dynamic>>.from(gameDoc.data()?['accounts'] ?? []);

                  final accountIndex = accounts.indexWhere((a) => a['accountId'] == account['accountId']);
                  if (accountIndex != -1) {
                    accounts[accountIndex]['credentials'] = {
                      'email': emailController.text,
                      'password': passwordController.text,
                    };
                    accounts[accountIndex]['edition'] = editionValue;
                    accounts[accountIndex]['region'] = regionValue;

                    await _firestore.collection('games').doc(gameId).update({
                      'accounts': accounts,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    Fluttertoast.showToast(
                      msg: isArabic ? 'تم تحديث الحساب' : 'Account updated',
                      backgroundColor: AppTheme.successColor,
                    );
                  }

                  Navigator.pop(dialogContext);
                  setState(() {}); // Refresh the UI
                } catch (e) {
                  Fluttertoast.showToast(
                    msg: isArabic ? 'حدث خطأ' : 'Error occurred',
                    backgroundColor: AppTheme.errorColor,
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: Text(
                isArabic ? 'حفظ التغييرات' : 'Save Changes',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _returnSlot(String gameId, String accountId, String slotKey) async {
    try {
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      final accounts = List<Map<String, dynamic>>.from(gameDoc.data()?['accounts'] ?? []);

      final accountIndex = accounts.indexWhere((a) => a['accountId'] == accountId);
      if (accountIndex != -1) {
        accounts[accountIndex]['slots'][slotKey] = {
          'platform': slotKey.split('_')[0],
          'accountType': slotKey.split('_').skip(1).join('_'),
          'status': 'available',
          'borrowerId': null,
          'borrowerName': null,
          'borrowDate': null,
          'expectedReturnDate': null,
        };

        await _firestore.collection('games').doc(gameId).update({
          'accounts': accounts,
          'availableAccounts': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        Fluttertoast.showToast(
          msg: 'Slot returned successfully',
          backgroundColor: AppTheme.successColor,
        );

        setState(() {});
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error returning slot',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  // Add this new method to toggle slot availability
  Future<void> _toggleSlotAvailability(String gameId, String accountId, String slotKey, String currentStatus) async {
    try {
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      final accounts = List<Map<String, dynamic>>.from(gameDoc.data()?['accounts'] ?? []);

      final accountIndex = accounts.indexWhere((a) => a['accountId'] == accountId);
      if (accountIndex != -1) {
        final newStatus = currentStatus == 'available' ? 'unavailable' : 'available';
        
        accounts[accountIndex]['slots'][slotKey]['status'] = newStatus;
        
        // Update available accounts count
        int availableCount = 0;
        for (var acc in accounts) {
          final slots = acc['slots'] as Map<String, dynamic>? ?? {};
          for (var slot in slots.values) {
            if (slot['status'] == 'available') {
              availableCount++;
              break; // Count account once if it has any available slot
            }
          }
        }

        await _firestore.collection('games').doc(gameId).update({
          'accounts': accounts,
          'availableAccounts': availableCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        Fluttertoast.showToast(
          msg: newStatus == 'available' ? 'Slot made available' : 'Slot made unavailable',
          backgroundColor: AppTheme.successColor,
        );

        setState(() {});
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error updating slot',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  Future<void> _deleteGame(String gameId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تأكيد الحذف' : 'Confirm Delete'),
        content: Text(
            isArabic
                ? 'هل أنت متأكد من حذف هذه اللعبة؟ لا يمكن التراجع عن هذا الإجراء.'
                : 'Are you sure you want to delete this game? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: Text(isArabic ? 'حذف' : 'Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('games').doc(gameId).delete();
        Fluttertoast.showToast(
          msg: isArabic ? 'تم حذف اللعبة' : 'Game deleted',
          backgroundColor: AppTheme.successColor,
        );
        _loadStatistics();
      } catch (e) {
        Fluttertoast.showToast(
          msg: isArabic ? 'فشل حذف اللعبة' : 'Failed to delete game',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  Widget _buildStatisticsCard() {
    final appProvider = Provider.of<AppProvider>(context);
    final isDarkMode = appProvider.isDarkMode;
    final isArabic = appProvider.isArabic;

    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: FontAwesomeIcons.gamepad,
                label: isArabic ? 'الألعاب' : 'Games',
                value: _totalGames.toString(),
              ),
              _buildStatItem(
                icon: Icons.account_box,
                label: isArabic ? 'الحسابات' : 'Accounts',
                value: _totalAccounts.toString(),
              ),
              _buildStatItem(
                icon: Icons.check_circle,
                label: isArabic ? 'متاح' : 'Available',
                value: _availableSlots.toString(),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.lock,
                label: isArabic ? 'مستعار' : 'Borrowed',
                value: _borrowedSlots.toString(),
              ),
              _buildStatItem(
                icon: Icons.attach_money,
                label: isArabic ? 'القيمة' : 'Value',
                value: '${_totalValue.toStringAsFixed(0)} LE',
              ),
              _buildStatItem(
                icon: Icons.trending_up,
                label: isArabic ? 'الإيرادات' : 'Revenue',
                value: '${_totalRevenue.toStringAsFixed(0)} LE',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24.sp),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildGameCard(DocumentSnapshot doc) {
    final appProvider = Provider.of<AppProvider>(context);
    final isDarkMode = appProvider.isDarkMode;
    final isArabic = appProvider.isArabic;

    final data = doc.data() as Map<String, dynamic>;
    final gameId = doc.id;
    final title = data['title'] ?? 'Unknown Game';
    final coverImageUrl = data['coverImageUrl'];
    final gameValue = (data['gameValue'] ?? data['totalValue'] ?? 0).toDouble();
    final accounts = data['accounts'] as List<dynamic>? ?? [];
    final lenderTier = data['lenderTier'] ?? 'member';

    // Calculate metrics
    int availableSlots = 0;
    int totalSlots = 0;
    double totalRevenue = (data['totalRevenues'] ?? 0).toDouble();
    double profit = totalRevenue - (data['totalCost'] ?? gameValue);

    for (var account in accounts) {
      final slots = account['slots'] as Map<String, dynamic>? ?? {};
      totalSlots += slots.length;
      for (var slot in slots.values) {
        if (slot['status'] == 'available') availableSlots++;
      }
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      child: InkWell(
        onTap: () => _showGameDetailsBottomSheet(gameId, data),
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          children: [
            // Header with image and basic info
            Container(
              height: 120.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                image: coverImageUrl != null
                    ? DecorationImage(
                  image: CachedNetworkImageProvider(coverImageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.3),
                    BlendMode.darken,
                  ),
                )
                    : null,
                gradient: coverImageUrl == null
                    ? LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.8),
                    AppTheme.primaryColor.withOpacity(0.6),
                  ],
                )
                    : null,
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: _getLenderColor(lenderTier),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            _getLenderLabel(lenderTier, isArabic),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '${gameValue.toStringAsFixed(0)} LE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Metrics Section
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  // Accounts and Slots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricItem(
                        icon: Icons.account_box,
                        label: isArabic ? 'الحسابات' : 'Accounts',
                        value: accounts.length.toString(),
                        color: Colors.blue,
                      ),
                      _buildMetricItem(
                        icon: Icons.grid_view,
                        label: isArabic ? 'الفتحات' : 'Slots',
                        value: '$availableSlots/$totalSlots',
                        color: Colors.green,
                      ),
                      _buildMetricItem(
                        icon: Icons.trending_up,
                        label: isArabic ? 'الإيرادات' : 'Revenue',
                        value: '${totalRevenue.toStringAsFixed(0)} LE',
                        color: Colors.orange,
                      ),
                    ],
                  ),

                  SizedBox(height: 12.h),

                  // Profit Indicator
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: profit >= 0
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: profit >= 0 ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          profit >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          color: profit >= 0 ? Colors.green : Colors.red,
                          size: 16.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '${isArabic ? 'الربح:' : 'Profit:'} ${profit.toStringAsFixed(0)} LE',
                          style: TextStyle(
                            color: profit >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddEditGameDialog(gameData: data, gameId: gameId),
                          icon: Icon(Icons.edit, size: 16.sp),
                          label: Text(isArabic ? 'تعديل' : 'Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _deleteGame(gameId),
                          icon: Icon(Icons.delete, size: 16.sp),
                          label: Text(isArabic ? 'حذف' : 'Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20.sp),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  void _showGameDetailsBottomSheet(String gameId, Map<String, dynamic> data) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    final accounts = data['accounts'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: 12.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),

            // Title
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                data['title'] ?? 'Game Details',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Accounts List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index] as Map<String, dynamic>;
                  final slots = account['slots'] as Map<String, dynamic>? ?? {};

                  int availableSlots = 0;
                  for (var slot in slots.values) {
                    if (slot['status'] == 'available') availableSlots++;
                  }

                  return Card(
                    margin: EdgeInsets.only(bottom: 12.h),
                    color: isDarkMode ? AppTheme.darkBackground : Colors.grey[50],
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        '${account['contributorName'] ?? 'Unknown'}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${account['accountId']?.toString().substring(0, 8) ?? 'N/A'}'),
                          Text('${isArabic ? 'الفتحات:' : 'Slots:'} $availableSlots/${slots.length}'),
                          Text('${isArabic ? 'القيمة:' : 'Value:'} ${account['gameValue']} LE'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.info_outline, color: AppTheme.primaryColor),
                        onPressed: () => _showAccountDetailsDialog(gameId, data, account),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLenderColor(String tier) {
    switch (tier) {
      case 'member':
        return Colors.blue;
      case 'gamesVault':
        return Colors.green;
      case 'nonMember':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getLenderLabel(String tier, bool isArabic) {
    switch (tier) {
      case 'member':
        return isArabic ? 'ألعاب الأعضاء' : "Members' Games";
      case 'gamesVault':
        return isArabic ? 'خزنة الألعاب' : 'Games Vault';
      case 'nonMember':
        return isArabic ? 'غير الأعضاء' : 'Non-Members';
      default:
        return tier;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isDarkMode = appProvider.isDarkMode;
    final isArabic = appProvider.isArabic;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(isArabic ? 'إدارة الألعاب' : 'Manage Games'),
        backgroundColor: isDarkMode ? AppTheme.darkSurface : AppTheme.primaryColor,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: isArabic ? 'الكل' : 'All'),
            Tab(text: isArabic ? 'الأعضاء' : 'Members'),
            Tab(text: isArabic ? 'الخزنة' : 'Vault'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Card
          _buildStatisticsCard(),

          // Search and Filter Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: isArabic ? 'بحث...' : 'Search...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                PopupMenuButton<game_models.Platform?>(
                  icon: Icon(Icons.filter_list),
                  onSelected: (platform) => setState(() => _selectedPlatform = platform),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: null,
                      child: Text(isArabic ? 'الكل' : 'All Platforms'),
                    ),
                    PopupMenuItem(
                      value: game_models.Platform.ps4,
                      child: Text('PS4'),
                    ),
                    PopupMenuItem(
                      value: game_models.Platform.ps5,
                      child: Text('PS5'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Games List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All Games Tab
                _buildGamesListView(null),
                // Members Games Tab
                _buildGamesListView('member'),
                // Vault Games Tab
                _buildGamesListView('gamesVault'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditGameDialog(),
        backgroundColor: AppTheme.primaryColor,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          isArabic ? 'إضافة لعبة' : 'Add Game',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildGamesListView(String? lenderTierFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('games').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CustomLoading());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FontAwesomeIcons.gamepad, size: 64.sp, color: Colors.grey),
                SizedBox(height: 16.h),
                Text(
                  'No games found',
                  style: TextStyle(fontSize: 18.sp, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        var games = snapshot.data!.docs;

        // Apply filters
        if (lenderTierFilter != null) {
          games = games.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['lenderTier'] == lenderTierFilter;
          }).toList();
        }

        if (_searchQuery.isNotEmpty) {
          games = games.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title']?.toString().toLowerCase() ?? '';
            return title.contains(_searchQuery.toLowerCase());
          }).toList();
        }

        if (_selectedPlatform != null) {
          games = games.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final accounts = data['accounts'] as List<dynamic>? ?? [];
            return accounts.any((account) {
              final platforms = account['platforms'] as List<dynamic>? ?? [];
              return platforms.contains(_selectedPlatform!.value);
            });
          }).toList();
        }

        return ListView.builder(
          padding: EdgeInsets.only(bottom: 80.h),
          itemCount: games.length,
          itemBuilder: (context, index) => _buildGameCard(games[index]),
        );
      },
    );
  }

  // Enhanced Edit Game Dialog with Tabs
  void _showEnhancedEditGameDialog({required Map<String, dynamic> gameData, required String gameId}) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _GameEditDialog(
          gameId: gameId,
          gameData: gameData,
          isArabic: isArabic,
          isDarkMode: isDarkMode,
          onSaved: () {
            _loadStatistics();
            setState(() {});
          },
        );
      },
    );
  }
}

// Create a stateful widget for the edit dialog with tabs
class _GameEditDialog extends StatefulWidget {
  final String gameId;
  final Map<String, dynamic> gameData;
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onSaved;

  const _GameEditDialog({
    Key? key,
    required this.gameId,
    required this.gameData,
    required this.isArabic,
    required this.isDarkMode,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<_GameEditDialog> createState() => _GameEditDialogState();
}

class _GameEditDialogState extends State<_GameEditDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Controllers for game details tab
  late TextEditingController titleController;
  late TextEditingController includedTitlesController;
  late TextEditingController gameValueController;
  late TextEditingController totalCostController;
  
  // Controllers for appearance tab
  late TextEditingController coverImageController;
  late TextEditingController descriptionController;
  late TextEditingController batchNumberController;
  
  String selectedLenderTier = 'member';
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize controllers with existing data
    titleController = TextEditingController(text: widget.gameData['title'] ?? '');
    includedTitlesController = TextEditingController(
      text: (widget.gameData['includedTitles'] as List<dynamic>?)?.join(', ') ?? ''
    );
    gameValueController = TextEditingController(
      text: (widget.gameData['gameValue'] ?? widget.gameData['totalValue'] ?? 0).toString()
    );
    totalCostController = TextEditingController(
      text: (widget.gameData['totalCost'] ?? widget.gameData['gameValue'] ?? 0).toString()
    );
    coverImageController = TextEditingController(text: widget.gameData['coverImageUrl'] ?? '');
    descriptionController = TextEditingController(text: widget.gameData['description'] ?? '');
    batchNumberController = TextEditingController(
      text: (widget.gameData['batchNumber'] ?? '').toString()
    );
    
    selectedLenderTier = widget.gameData['lenderTier'] ?? 'member';
    isActive = widget.gameData['isActive'] ?? true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    titleController.dispose();
    includedTitlesController.dispose();
    gameValueController.dispose();
    totalCostController.dispose();
    coverImageController.dispose();
    descriptionController.dispose();
    batchNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.isDarkMode ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.isArabic ? 'تعديل اللعبة' : 'Edit Game',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  // Tab Bar
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: [
                      Tab(
                        icon: Icon(Icons.info),
                        text: widget.isArabic ? 'التفاصيل' : 'Details',
                      ),
                      Tab(
                        icon: Icon(Icons.palette),
                        text: widget.isArabic ? 'المظهر' : 'Appearance',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Details Tab
                  SingleChildScrollView(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: widget.isArabic ? 'عنوان اللعبة' : 'Game Title',
                            prefixIcon: Icon(FontAwesomeIcons.gamepad),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Included Titles
                        TextField(
                          controller: includedTitlesController,
                          decoration: InputDecoration(
                            labelText: widget.isArabic ? 'العناوين المضمنة' : 'Included Titles',
                            helperText: widget.isArabic ? 'افصل بين العناوين بفاصلة' : 'Separate titles with comma',
                            prefixIcon: Icon(Icons.list),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Game Value and Total Cost
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: gameValueController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: widget.isArabic ? 'قيمة اللعبة' : 'Game Value',
                                  prefixIcon: Icon(Icons.attach_money),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: TextField(
                                controller: totalCostController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: widget.isArabic ? 'التكلفة الإجمالية' : 'Total Cost',
                                  prefixIcon: Icon(Icons.paid),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),

                        // Lender Tier
                        DropdownButtonFormField<String>(
                          value: selectedLenderTier,
                          decoration: InputDecoration(
                            labelText: widget.isArabic ? 'فئة المُقرض' : 'Lender Tier',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'member',
                              child: Text(widget.isArabic ? 'ألعاب الأعضاء' : "Members' Games"),
                            ),
                            DropdownMenuItem(
                              value: 'gamesVault',
                              child: Text(widget.isArabic ? 'خزنة الألعاب' : 'Games Vault'),
                            ),
                            DropdownMenuItem(
                              value: 'nonMember',
                              child: Text(widget.isArabic ? 'غير الأعضاء' : 'Non-Members'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedLenderTier = value ?? 'member';
                            });
                          },
                        ),
                        SizedBox(height: 16.h),

                        // Active Status
                        SwitchListTile(
                          title: Text(widget.isArabic ? 'اللعبة نشطة' : 'Game Active'),
                          subtitle: Text(
                            widget.isArabic 
                                ? 'عرض اللعبة في المكتبة'
                                : 'Show game in library'
                          ),
                          value: isActive,
                          onChanged: (value) {
                            setState(() {
                              isActive = value;
                            });
                          },
                          secondary: Icon(
                            isActive ? Icons.visibility : Icons.visibility_off,
                            color: isActive ? Colors.green : Colors.grey,
                          ),
                        ),

                        // Batch Number (for Games Vault)
                        if (selectedLenderTier == 'gamesVault') ...[
                          SizedBox(height: 16.h),
                          TextField(
                            controller: batchNumberController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: widget.isArabic ? 'رقم الدفعة' : 'Batch Number',
                              prefixIcon: Icon(Icons.tag),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Appearance Tab
                  SingleChildScrollView(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover Image URL
                        TextField(
                          controller: coverImageController,
                          decoration: InputDecoration(
                            labelText: widget.isArabic ? 'رابط صورة الغلاف' : 'Cover Image URL',
                            prefixIcon: Icon(Icons.image),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Preview Image
                        if (coverImageController.text.isNotEmpty)
                          Container(
                            height: 200.h,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: Image.network(
                                coverImageController.text,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error, color: Colors.red, size: 48.sp),
                                      SizedBox(height: 8.h),
                                      Text(
                                        widget.isArabic ? 'فشل تحميل الصورة' : 'Failed to load image',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        SizedBox(height: 16.h),

                        // Description
                        TextField(
                          controller: descriptionController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: widget.isArabic ? 'الوصف' : 'Description',
                            prefixIcon: Icon(Icons.description),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      widget.isArabic ? 'إلغاء' : 'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.isEmpty || gameValueController.text.isEmpty) {
                        Fluttertoast.showToast(
                          msg: widget.isArabic ? 'يرجى ملء الحقول المطلوبة' : 'Please fill required fields',
                          backgroundColor: AppTheme.errorColor,
                        );
                        return;
                      }

                      try {
                        final updates = {
                          'title': titleController.text.trim(),
                          'includedTitles': includedTitlesController.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList(),
                          'gameValue': double.parse(gameValueController.text),
                          'totalCost': double.parse(totalCostController.text),
                          'coverImageUrl': coverImageController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'lenderTier': selectedLenderTier,
                          'isActive': isActive,
                          'updatedAt': FieldValue.serverTimestamp(),
                        };

                        if (selectedLenderTier == 'gamesVault' && batchNumberController.text.isNotEmpty) {
                          updates['batchNumber'] = int.tryParse(batchNumberController.text) ?? 0;
                        }

                        await FirebaseFirestore.instance
                            .collection('games')
                            .doc(widget.gameId)
                            .update(updates);

                        Fluttertoast.showToast(
                          msg: widget.isArabic ? 'تم تحديث اللعبة بنجاح' : 'Game updated successfully',
                          backgroundColor: AppTheme.successColor,
                        );

                        widget.onSaved();
                        Navigator.pop(context);
                      } catch (e) {
                        Fluttertoast.showToast(
                          msg: widget.isArabic ? 'حدث خطأ: $e' : 'An error occurred: $e',
                          backgroundColor: AppTheme.errorColor,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    ),
                    child: Text(
                      widget.isArabic ? 'حفظ التغييرات' : 'Save Changes',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}