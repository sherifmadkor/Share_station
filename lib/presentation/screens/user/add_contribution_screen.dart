// lib/presentation/screens/user/add_contribution_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_model.dart';
import '../../../services/contribution_service.dart';

class AddContributionScreen extends StatefulWidget {
  const AddContributionScreen({Key? key}) : super(key: key);

  @override
  State<AddContributionScreen> createState() => _AddContributionScreenState();
}

class _AddContributionScreenState extends State<AddContributionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ContributionService _contributionService = ContributionService();

  // --- Game Contribution Controllers ---
  final _gameTitleController = TextEditingController();
  final _gameDescriptionController = TextEditingController();
  final _accountEmailController = TextEditingController();
  final _accountPasswordController = TextEditingController();
  final _gameValueController = TextEditingController(text: '500'); // Default value

  // --- PS Plus Contribution Controllers ---
  final _psPlusAccountEmailController = TextEditingController();
  final _psPlusAccountPasswordController = TextEditingController();

  // --- Fund Contribution Controllers ---
  final _fundAmountController = TextEditingController();
  File? _paymentReceiptImage;
  String? _selectedFundGameId;
  Map<String, dynamic>? _selectedFundGame;
  List<Map<String, dynamic>> _availableFundGames = [];

  // --- Selected Values ---
  String _selectedEdition = 'Standard';
  String _selectedRegion = 'US';

  // Using the Platform and AccountType from game_model.dart
  List<Platform> _selectedPlatforms = [Platform.ps5];
  List<AccountType> _selectedAccountTypes = [AccountType.primary];
  String _selectedPaymentMethod = 'InstaPay';

  bool _isLoading = false;

  // Game suggestions
  List<Map<String, dynamic>> _gameSuggestions = [];
  bool _showSuggestions = false;
  String? _selectedExistingGameId;
  Map<String, dynamic>? _selectedExistingGame;

  // Available regions and editions
  final List<String> _availableRegions = [
    'US', 'EU', 'UK', 'JP', 'AU', 'CA', 'BR', 'MX', 'RU', 'IN',
    'KR', 'TW', 'HK', 'SG', 'MENA', 'ZA', 'GLOBAL'
  ];

  final List<String> _availableEditions = [
    'Standard', 'Deluxe', 'Ultimate', 'Gold', 'Complete', 'Premium',
    'Collector\'s', 'Special', 'Anniversary', 'Director\'s Cut',
    'Game of the Year', 'Definitive', 'Enhanced', 'Remastered'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAvailableFundGames();

    // Listen to game title changes for suggestions
    _gameTitleController.addListener(_onGameTitleChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gameTitleController.removeListener(_onGameTitleChanged);
    _gameTitleController.dispose();
    _gameDescriptionController.dispose();
    _accountEmailController.dispose();
    _accountPasswordController.dispose();
    _gameValueController.dispose();
    _fundAmountController.dispose();
    _psPlusAccountEmailController.dispose();
    _psPlusAccountPasswordController.dispose();
    super.dispose();
  }

  // Search for existing games as user types
  void _onGameTitleChanged() async {
    final query = _gameTitleController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _gameSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    if (query.length < 2) return; // Don't search for very short queries

    try {
      // Search for games that contain the query (case-insensitive)
      final snapshot = await _firestore
          .collection('games')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(5)
          .get();

      setState(() {
        _gameSuggestions = snapshot.docs.map((doc) => {
          'id': doc.id,
          'title': doc.data()['title'],
          'coverImageUrl': doc.data()['coverImageUrl'],
          'gameValue': doc.data()['gameValue'] ?? doc.data()['totalValue'],
          'accountsCount': (doc.data()['accounts'] as List?)?.length ?? 0,
        }).toList();
        _showSuggestions = _gameSuggestions.isNotEmpty;
      });
    } catch (e) {
      print('Error searching games: $e');
    }
  }

  // Select an existing game from suggestions
  void _selectExistingGame(Map<String, dynamic> game) {
    setState(() {
      _selectedExistingGameId = game['id'];
      _selectedExistingGame = game;
      _gameTitleController.text = game['title'];
      _gameValueController.text = game['gameValue'].toString();
      _showSuggestions = false;
    });

    // Show toast to inform user
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    Fluttertoast.showToast(
      msg: isArabic
          ? 'تم اختيار لعبة موجودة. سيتم إضافة حسابك إلى هذه اللعبة.'
          : 'Existing game selected. Your account will be added to this game.',
      backgroundColor: AppTheme.infoColor,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  // Load games available for funding
  Future<void> _loadAvailableFundGames() async {
    try {
      // For now, load all games that are vault games
      final snapshot = await _firestore
          .collection('games')
          .where('lenderTier', isEqualTo: 'gamesVault')
          .get();

      setState(() {
        _availableFundGames = snapshot.docs.map((doc) => {
          'id': doc.id,
          'title': doc.data()['title'] ?? 'Unknown Game',
          'targetPrice': doc.data()['totalValue'] ?? 0,
          'currentFunding': doc.data()['currentFunding'] ?? 0,
        }).toList();
      });
    } catch (e) {
      print('Error loading fund games: $e');
    }
  }

  // Pick payment receipt image
  Future<void> _pickPaymentReceipt() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _paymentReceiptImage = File(image.path);
      });
    }
  }

  // Upload receipt to Firebase Storage
  Future<String?> _uploadReceiptImage() async {
    if (_paymentReceiptImage == null) return null;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'receipts/${authProvider.currentUser?.uid}_$timestamp.jpg';

      final ref = _storage.ref().child(fileName);
      final uploadTask = await ref.putFile(_paymentReceiptImage!);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading receipt: $e');
      return null;
    }
  }

  // Calculate how many slots will be created based on account type
  Map<String, int> _calculateSlots() {
    Map<String, int> slots = {};

    for (var accountType in _selectedAccountTypes) {
      if (accountType == AccountType.full) {
        // Full account creates multiple slots based on platforms
        for (var platform in _selectedPlatforms) {
          if (platform == Platform.ps5) {
            // PS5 Full = Primary PS5, Secondary PS5, Primary PS4, Secondary PS4
            slots['PS5 Primary'] = 1;
            slots['PS5 Secondary'] = 1;
            slots['PS4 Primary'] = 1;
            slots['PS4 Secondary'] = 1;
          } else if (platform == Platform.ps4) {
            // PS4 Full = Primary PS4, Secondary PS4
            slots['PS4 Primary'] = 1;
            slots['PS4 Secondary'] = 1;
          }
        }
      } else {
        // Primary or Secondary account
        for (var platform in _selectedPlatforms) {
          String key = '${platform == Platform.ps5 ? "PS5" : "PS4"} ${accountType == AccountType.primary ? "Primary" : "Secondary"}';
          slots[key] = 1;
        }
      }
    }

    return slots;
  }

  // Extension to ContributionService to handle existing games
  // Add these parameters to submitContribution method:
  // existingGameId: String? - ID of existing game to add account to
  // isFullAccount: bool - Whether this is a full account

  // Submit game contribution using the contribution service
  Future<void> _submitGameContributionRequest() async {
    if (_gameTitleController.text.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter game title', backgroundColor: AppTheme.warningColor);
      return;
    }

    if (_accountEmailController.text.isEmpty || _accountPasswordController.text.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter account credentials', backgroundColor: AppTheme.warningColor);
      return;
    }

    if (_gameValueController.text.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter game value', backgroundColor: AppTheme.warningColor);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final gameValue = double.tryParse(_gameValueController.text) ?? 500;

      // Prepare sharing options based on account type selection
      List<AccountType> actualSharingOptions = [];
      List<Platform> actualPlatforms = [];

      // Handle Full account special case
      if (_selectedAccountTypes.contains(AccountType.full)) {
        if (_selectedPlatforms.contains(Platform.ps5)) {
          // PS5 Full account includes PS5 and PS4 primary and secondary
          actualSharingOptions = [AccountType.primary, AccountType.secondary];
          actualPlatforms = [Platform.ps5, Platform.ps4];
        } else if (_selectedPlatforms.contains(Platform.ps4)) {
          // PS4 Full account includes PS4 primary and secondary
          actualSharingOptions = [AccountType.primary, AccountType.secondary];
          actualPlatforms = [Platform.ps4];
        }
      } else {
        actualSharingOptions = _selectedAccountTypes;
        actualPlatforms = _selectedPlatforms;
      }

      // Use the contribution service to submit
      final result = await _contributionService.submitContribution(
        userId: currentUser.uid,
        userName: currentUser.name,
        gameTitle: _gameTitleController.text.trim(),
        includedTitles: [_gameTitleController.text.trim()],
        platforms: actualPlatforms,
        sharingOptions: actualSharingOptions,
        gameValue: gameValue,
        email: _accountEmailController.text.trim(),
        password: _accountPasswordController.text,
        edition: _selectedEdition,
        region: _selectedRegion,
        description: _gameDescriptionController.text.trim().isEmpty ? null : _gameDescriptionController.text.trim(),
        coverImageUrl: _selectedExistingGame?['coverImageUrl'],
        existingGameId: _selectedExistingGameId, // Pass the existing game ID if selected
        isFullAccount: _selectedAccountTypes.contains(AccountType.full), // Flag for full account
      );

      if (result['success']) {
        Fluttertoast.showToast(
          msg: _selectedExistingGameId != null
              ? 'Contribution request submitted! Your account will be added to the existing game after approval.'
              : 'Game contribution request submitted! Awaiting admin approval.',
          backgroundColor: AppTheme.successColor,
          toastLength: Toast.LENGTH_LONG,
        );

        _gameTitleController.clear();
        _gameDescriptionController.clear();
        _accountEmailController.clear();
        _accountPasswordController.clear();
        _gameValueController.text = '500';
        setState(() {
          _selectedExistingGameId = null;
          _selectedExistingGame = null;
          _selectedEdition = 'Standard';
          _selectedRegion = 'US';
        });

        Navigator.pop(context);
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: ${e.toString()}',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Submit fund contribution
  Future<void> _submitFundContributionRequest() async {
    if (_selectedFundGameId == null || _selectedFundGame == null) {
      Fluttertoast.showToast(msg: 'Please select a game to fund', backgroundColor: AppTheme.warningColor);
      return;
    }

    if (_fundAmountController.text.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter contribution amount', backgroundColor: AppTheme.warningColor);
      return;
    }

    final amount = double.tryParse(_fundAmountController.text) ?? 0;
    if (amount < 50) {
      Fluttertoast.showToast(msg: 'Minimum contribution is 50 LE', backgroundColor: AppTheme.warningColor);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      String? receiptUrl;
      if (_paymentReceiptImage != null) {
        receiptUrl = await _uploadReceiptImage();
      }

      // Use contribution service for fund contribution
      final result = await _contributionService.submitFundContribution(
        userId: currentUser.uid,
        userName: currentUser.name,
        gameTitle: _selectedFundGame!['title'],
        amount: amount,
        notes: 'Payment method: $_selectedPaymentMethod${receiptUrl != null ? ', Receipt: $receiptUrl' : ''}',
      );

      if (result['success']) {
        Fluttertoast.showToast(
          msg: 'Fund contribution request submitted!',
          backgroundColor: AppTheme.successColor,
          toastLength: Toast.LENGTH_LONG,
        );

        _fundAmountController.clear();
        setState(() {
          _paymentReceiptImage = null;
          _selectedFundGameId = null;
          _selectedFundGame = null;
        });
        Navigator.pop(context);
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: ${e.toString()}',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Submit PS Plus contribution
  Future<void> _submitPSPlusContributionRequest() async {
    if (_psPlusAccountEmailController.text.isEmpty || _psPlusAccountPasswordController.text.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter PS Plus account credentials', backgroundColor: AppTheme.warningColor);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Submit PS Plus as a game contribution with PS Plus account type
      final result = await _contributionService.submitContribution(
        userId: currentUser.uid,
        userName: currentUser.name,
        gameTitle: 'PS Plus Account',
        includedTitles: ['PlayStation Plus Subscription'],
        platforms: [Platform.ps4, Platform.ps5], // Works on both
        sharingOptions: [AccountType.psPlus],
        gameValue: 200, // PS Plus has double value
        email: _psPlusAccountEmailController.text.trim(),
        password: _psPlusAccountPasswordController.text,
        edition: 'Premium',
        region: 'GLOBAL',
        description: 'PS Plus subscription account',
      );

      if (result['success']) {
        Fluttertoast.showToast(
          msg: 'PS Plus contribution request submitted!',
          backgroundColor: AppTheme.successColor,
          toastLength: Toast.LENGTH_LONG,
        );

        _psPlusAccountEmailController.clear();
        _psPlusAccountPasswordController.clear();
        Navigator.pop(context);
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: ${e.toString()}',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
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
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          isArabic ? 'طلب مساهمة' : 'Contribution Request',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3.h,
          tabs: [
            Tab(
              icon: Icon(FontAwesomeIcons.gamepad, color: Colors.white),
              text: isArabic ? 'لعبة' : 'Game',
            ),
            Tab(
              icon: Icon(FontAwesomeIcons.moneyBill, color: Colors.white),
              text: isArabic ? 'تمويل' : 'Fund',
            ),
            Tab(
              icon: Icon(FontAwesomeIcons.playstation, color: Colors.white),
              text: 'PS Plus',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGameContributionTab(isArabic, isDarkMode),
          _buildFundContributionTab(isArabic, isDarkMode),
          _buildPSPlusContributionTab(isArabic, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildGameContributionTab(bool isArabic, bool isDarkMode) {
    final slots = _calculateSlots();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Important Notice Card
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppTheme.warningColor),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.warningColor, size: 24.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    isArabic ? 'جميع المساهمات تحتاج موافقة المدير' : 'All contributions require admin approval',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppTheme.warningColor),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Game Title with autocomplete
          Stack(
            children: [
              TextField(
                controller: _gameTitleController,
                decoration: InputDecoration(
                  labelText: isArabic ? 'اسم اللعبة' : 'Game Title',
                  hintText: isArabic ? 'ابدأ الكتابة للبحث عن لعبة موجودة' : 'Start typing to search existing games',
                  prefixIcon: Icon(Icons.games, color: AppTheme.primaryColor),
                  suffixIcon: _selectedExistingGameId != null
                      ? Icon(Icons.check_circle, color: AppTheme.successColor)
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
              if (_showSuggestions)
                Positioned(
                  top: 60.h,
                  left: 0,
                  right: 0,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      constraints: BoxConstraints(maxHeight: 200.h),
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _gameSuggestions.length,
                        itemBuilder: (context, index) {
                          final game = _gameSuggestions[index];
                          return ListTile(
                            leading: game['coverImageUrl'] != null
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(4.r),
                              child: Image.network(
                                game['coverImageUrl'],
                                width: 40.w,
                                height: 40.w,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(FontAwesomeIcons.gamepad),
                              ),
                            )
                                : Icon(FontAwesomeIcons.gamepad),
                            title: Text(game['title']),
                            subtitle: Text('${game['accountsCount']} ${isArabic ? "حساب" : "accounts"}'),
                            trailing: Chip(
                              label: Text('${game['gameValue']} LE'),
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            ),
                            onTap: () => _selectExistingGame(game),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),

          if (_selectedExistingGameId != null) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppTheme.successColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.successColor, size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'سيتم إضافة حسابك إلى هذه اللعبة الموجودة'
                          : 'Your account will be added to this existing game',
                      style: TextStyle(fontSize: 13.sp, color: AppTheme.successColor),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 16.h),

          // Game Value
          TextField(
            controller: _gameValueController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: isArabic ? 'قيمة اللعبة (جنيه)' : 'Game Value (LE)',
              hintText: isArabic ? 'مثال: 500' : 'e.g., 500',
              prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),

          SizedBox(height: 16.h),

          // Platform Selection
          Text(
            isArabic ? 'المنصة:' : 'Platform:',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            children: [
              FilterChip(
                label: Text('PS4'),
                selected: _selectedPlatforms.contains(Platform.ps4),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedPlatforms.add(Platform.ps4);
                    } else {
                      _selectedPlatforms.remove(Platform.ps4);
                    }
                  });
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              ),
              FilterChip(
                label: Text('PS5'),
                selected: _selectedPlatforms.contains(Platform.ps5),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedPlatforms.add(Platform.ps5);
                    } else {
                      _selectedPlatforms.remove(Platform.ps5);
                    }
                  });
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Account Type Selection
          Text(
            isArabic ? 'نوع الحساب:' : 'Account Type:',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              FilterChip(
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isArabic ? 'أساسي' : 'Primary'),
                    Text('100%', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
                selected: _selectedAccountTypes.contains(AccountType.primary),
                onSelected: (selected) {
                  setState(() {
                    _selectedAccountTypes.clear();
                    if (selected) {
                      _selectedAccountTypes.add(AccountType.primary);
                    }
                  });
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              ),
              FilterChip(
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isArabic ? 'ثانوي' : 'Secondary'),
                    Text('75%', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
                selected: _selectedAccountTypes.contains(AccountType.secondary),
                onSelected: (selected) {
                  setState(() {
                    _selectedAccountTypes.clear();
                    if (selected) {
                      _selectedAccountTypes.add(AccountType.secondary);
                    }
                  });
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              ),
              FilterChip(
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isArabic ? 'كامل' : 'Full'),
                    Text(isArabic ? 'متعدد' : 'Multiple', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
                selected: _selectedAccountTypes.contains(AccountType.full),
                onSelected: (selected) {
                  setState(() {
                    _selectedAccountTypes.clear();
                    if (selected) {
                      _selectedAccountTypes.add(AccountType.full);
                    }
                  });
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              ),
            ],
          ),

          // Show what slots will be created
          if (slots.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'سيتم إنشاء الفتحات التالية:' : 'Following slots will be created:',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4.h),
                  ...slots.entries.map((entry) => Text(
                    '• ${entry.key}',
                    style: TextStyle(fontSize: 12.sp),
                  )),
                ],
              ),
            ),
          ],

          SizedBox(height: 16.h),

          // Region Dropdown
          DropdownButtonFormField<String>(
            value: _selectedRegion,
            decoration: InputDecoration(
              labelText: isArabic ? 'المنطقة' : 'Region',
              prefixIcon: Icon(Icons.language, color: AppTheme.primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            items: _availableRegions.map((region) => DropdownMenuItem(
              value: region,
              child: Text(region),
            )).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRegion = value ?? 'US';
              });
            },
          ),

          SizedBox(height: 16.h),

          // Edition Dropdown
          DropdownButtonFormField<String>(
            value: _selectedEdition,
            decoration: InputDecoration(
              labelText: isArabic ? 'الإصدار' : 'Edition',
              prefixIcon: Icon(Icons.book, color: AppTheme.primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            items: _availableEditions.map((edition) => DropdownMenuItem(
              value: edition,
              child: Text(edition),
            )).toList(),
            onChanged: (value) {
              setState(() {
                _selectedEdition = value ?? 'Standard';
              });
            },
          ),

          SizedBox(height: 24.h),

          // Account Credentials
          Text(
            isArabic ? 'بيانات الحساب:' : 'Account Credentials:',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),

          TextField(
            controller: _accountEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: isArabic ? 'البريد الإلكتروني للحساب' : 'Account Email',
              prefixIcon: Icon(Icons.email, color: AppTheme.primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),

          SizedBox(height: 16.h),

          TextField(
            controller: _accountPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: isArabic ? 'كلمة مرور الحساب' : 'Account Password',
              prefixIcon: Icon(Icons.lock, color: AppTheme.primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),

          SizedBox(height: 32.h),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitGameContributionRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                isArabic ? 'إرسال طلب المساهمة' : 'Submit Contribution Request',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundContributionTab(bool isArabic, bool isDarkMode) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'المساهمة في تمويل لعبة:' : 'Contribute to Fund a Game:',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),

          if (_availableFundGames.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Text(
                  isArabic ? 'لا توجد ألعاب متاحة للتمويل حالياً' : 'No games available for funding currently',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                ),
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedFundGameId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: isArabic ? 'اختر اللعبة' : 'Select Game',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              items: _availableFundGames.map((game) {
                return DropdownMenuItem<String>(
                  value: game['id'],
                  child: Text(game['title'] ?? 'Unknown Game'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFundGameId = value;
                  if (value != null) {
                    _selectedFundGame = _availableFundGames.firstWhere((doc) => doc['id'] == value);
                  } else {
                    _selectedFundGame = null;
                  }
                });
              },
            ),

          if (_selectedFundGameId != null) ...[
            SizedBox(height: 24.h),

            TextField(
              controller: _fundAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isArabic ? 'المبلغ (جنيه مصري)' : 'Amount (EGP)',
                hintText: isArabic ? 'الحد الأدنى 50 جنيه' : 'Minimum 50 LE',
                prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),

            SizedBox(height: 32.h),

            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitFundContributionRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                  isArabic ? 'إرسال طلب التمويل' : 'Submit Fund Request',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPSPlusContributionTab(bool isArabic, bool isDarkMode) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade600]),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                Icon(FontAwesomeIcons.playstation, color: Colors.white, size: 48.sp),
                SizedBox(height: 12.h),
                Text(
                  'PlayStation Plus',
                  style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),
                Text(
                  isArabic ? 'قيمة حد المحطة: 200 جنيه' : 'Station Limit Value: 200 LE',
                  style: TextStyle(color: Colors.white, fontSize: 18.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  isArabic ? 'قيمة الاستعارة: مضاعفة (200%)' : 'Borrow Value: Double (200%)',
                  style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          Text(
            isArabic ? 'بيانات حساب PS Plus:' : 'PS Plus Account Details:',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),

          TextField(
            controller: _psPlusAccountEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: isArabic ? 'البريد الإلكتروني' : 'Account Email',
              prefixIcon: Icon(Icons.email, color: Colors.blue),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),

          SizedBox(height: 16.h),

          TextField(
            controller: _psPlusAccountPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: isArabic ? 'كلمة المرور' : 'Account Password',
              prefixIcon: Icon(Icons.lock, color: Colors.blue),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),

          SizedBox(height: 32.h),

          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitPSPlusContributionRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                isArabic ? 'إرسال طلب PS Plus' : 'Submit PS Plus Request',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}