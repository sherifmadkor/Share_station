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
import '../../../data/models/game_model.dart' as game;
import '../../../data/models/user_model.dart' as user;

// FIX: Added the enum definition to resolve the 'AccountType not defined' error.
enum AccountType { primary, secondary, full, psPlus }

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

  // --- Game Contribution Controllers ---
  final _gameTitleController = TextEditingController();
  final _gameDescriptionController = TextEditingController();
  // These are for the 'Game' tab specifically
  final _accountEmailController = TextEditingController();
  final _accountPasswordController = TextEditingController();

  // --- PS Plus Contribution Controllers ---
  // FIX: Created separate controllers for the PS Plus tab to avoid conflicts.
  final _psPlusAccountEmailController = TextEditingController();
  final _psPlusAccountPasswordController = TextEditingController();

  // --- Fund Contribution Controllers ---
  final _fundAmountController = TextEditingController();
  File? _paymentReceiptImage;
  String? _selectedFundGameId;
  List<Map<String, dynamic>> _availableFundGames = [];

  // --- Selected Values ---
  // FIX: Declared and initialized the missing state variables.
  String _selectedEdition = 'standard';
  String _selectedRegion = 'us';

  Platform _selectedPlatform = Platform.ps4;
  AccountType _selectedAccountType = AccountType.primary;
  String _selectedPaymentMethod = 'InstaPay';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAvailableFundGames();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gameTitleController.dispose();
    _gameDescriptionController.dispose();
    _accountEmailController.dispose();
    _accountPasswordController.dispose();
    _fundAmountController.dispose();
    // FIX: Dispose the new PS Plus controllers.
    _psPlusAccountEmailController.dispose();
    _psPlusAccountPasswordController.dispose();
    super.dispose();
  }

  // Load games available for funding
  Future<void> _loadAvailableFundGames() async {
    try {
      final snapshot = await _firestore
          .collection('fund_games')
          .where('isActive', isEqualTo: true)
          .where('fullyFunded', isEqualTo: false)
          .get();

      setState(() {
        _availableFundGames = snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
      });
    } catch (e) {
      print('Error loading fund games: $e');
    }
  }

  // Calculate game value based on account type (for Station Limit)
  double _calculateGameValue() {
    // These values represent the currency value to be stored in the database.
    switch (_selectedAccountType) {
      case AccountType.primary:
        return 100.0;
      case AccountType.secondary:
        return 75.0;
      case AccountType.full:
        return 150.0;
      case AccountType.psPlus:
        return 200.0;
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

  // Submit game contribution REQUEST (requires admin approval)
  Future<void> _submitGameContributionRequest() async {
    if (_gameTitleController.text.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter game title', backgroundColor: AppTheme.warningColor);
      return;
    }

    if (_accountEmailController.text.isEmpty ||
        _accountPasswordController.text.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter account credentials', backgroundColor: AppTheme.warningColor);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final gameValue = _calculateGameValue();

      await _firestore.collection('contribution_requests').add({
        'type': 'game',
        'userId': currentUser.uid,
        'userName': currentUser.name,
        'userTier': currentUser.tier.name,
        'gameTitle': _gameTitleController.text.trim(),
        'gameDescription': _gameDescriptionController.text.trim(),
        'platform': _selectedPlatform.name,
        'accountType': _selectedAccountType.name,
        'accountEmail': _accountEmailController.text.trim(),
        'accountPassword': _accountPasswordController.text,
        'edition': _selectedEdition,
        'region': _selectedRegion,
        'gameValue': gameValue,
        'status': 'pending',
        'adminNotes': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Fluttertoast.showToast(
        msg: 'Game contribution request submitted! Awaiting admin approval.',
        backgroundColor: AppTheme.successColor,
        toastLength: Toast.LENGTH_LONG,
      );

      _gameTitleController.clear();
      _gameDescriptionController.clear();
      _accountEmailController.clear();
      _accountPasswordController.clear();

      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error submitting contribution request: $e', backgroundColor: AppTheme.errorColor);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Submit fund contribution REQUEST with receipt
  Future<void> _submitFundContributionRequest() async {
    // This function appears correct and does not need changes.
    if (_selectedFundGameId == null) {
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

    if (_paymentReceiptImage == null) {
      Fluttertoast.showToast(msg: 'Please upload payment receipt', backgroundColor: AppTheme.warningColor);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final receiptUrl = await _uploadReceiptImage();
      if (receiptUrl == null) {
        throw Exception('Failed to upload receipt');
      }

      final selectedGame = _availableFundGames.firstWhere(
            (game) => game['id'] == _selectedFundGameId,
      );

      await _firestore.collection('fund_contribution_requests').add({
        'userId': currentUser.uid,
        'userName': currentUser.name,
        'userTier': currentUser.tier.name,
        'gameId': _selectedFundGameId,
        'gameTitle': selectedGame['title'],
        'amount': amount,
        'paymentMethod': _selectedPaymentMethod,
        'receiptUrl': receiptUrl,
        'status': 'pending',
        'adminNotes': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Fluttertoast.showToast(
        msg: 'Fund contribution request submitted! Admin will verify your payment.',
        backgroundColor: AppTheme.successColor,
        toastLength: Toast.LENGTH_LONG,
      );

      _fundAmountController.clear();
      setState(() {
        _paymentReceiptImage = null;
        _selectedFundGameId = null;
      });
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error submitting fund contribution: $e', backgroundColor: AppTheme.errorColor);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Submit PS Plus contribution REQUEST
  Future<void> _submitPSPlusContributionRequest() async {
    // FIX: Use the new, separate controllers for PS Plus.
    if (_psPlusAccountEmailController.text.isEmpty ||
        _psPlusAccountPasswordController.text.isEmpty) {
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

      const psPlusValue = 200.0;

      await _firestore.collection('contribution_requests').add({
        'type': 'psplus',
        'userId': currentUser.uid,
        'userName': currentUser.name,
        'userTier': currentUser.tier.name,
        // FIX: Use the correct controller values for submission.
        'accountEmail': _psPlusAccountEmailController.text.trim(),
        'accountPassword': _psPlusAccountPasswordController.text,
        'gameValue': psPlusValue,
        'status': 'pending',
        'adminNotes': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Fluttertoast.showToast(
        msg: 'PS Plus contribution request submitted! Awaiting admin approval.',
        backgroundColor: AppTheme.successColor,
      );

      // FIX: Clear the correct controllers.
      _psPlusAccountEmailController.clear();
      _psPlusAccountPasswordController.clear();
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error submitting PS Plus request: $e', backgroundColor: AppTheme.errorColor);
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
      appBar: AppBar(
        title: Text(
          isArabic ? 'طلب مساهمة' : 'Contribution Request',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3.h,
          tabs: [
            Tab(
              icon: Icon(FontAwesomeIcons.gamepad),
              text: isArabic ? 'لعبة' : 'Game',
            ),
            Tab(
              icon: Icon(FontAwesomeIcons.moneyBill),
              text: isArabic ? 'تمويل' : 'Fund',
            ),
            Tab(
              icon: Icon(FontAwesomeIcons.playstation),
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
                Icon(
                  Icons.info_outline,
                  color: AppTheme.warningColor,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'جميع المساهمات تحتاج موافقة المدير'
                        : 'All contributions require admin approval',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // --- CHANGED: Station Limit Value Info Card (Re-implementing the percentage logic) ---
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'عند الموافقة:' : 'Upon Approval:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isArabic ? 'قيمة زيادة حد المحطة:' : 'Station Limit Increase:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                    Text(
                      // The value from _calculateGameValue() is the percentage.
                      '${_calculateGameValue().toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  isArabic
                      ? '* ستحصل على 70% من القيمة كرصيد عندما يستعير الآخرون لعبتك'
                      : '* You\'ll earn 70% as balance when others borrow your game',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.sp,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Game Title
          TextField(
            controller: _gameTitleController,
            decoration: InputDecoration(
              labelText: isArabic ? 'اسم اللعبة' : 'Game Title',
              hintText: isArabic ? 'مثال: God of War Ragnarok' : 'e.g., God of War Ragnarok',
              prefixIcon: Icon(Icons.games, color: AppTheme.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),

          SizedBox(height: 16.h),

          // Game Description
          TextField(
            controller: _gameDescriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: isArabic ? 'وصف اللعبة (اختياري)' : 'Game Description (Optional)',
              hintText: isArabic ? 'وصف مختصر للعبة' : 'Brief description of the game',
              prefixIcon: Icon(Icons.description, color: AppTheme.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),

          SizedBox(height: 16.h),

          // Edition and Region Selection
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'الإصدار:' : 'Edition:',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedEdition,
                        isExpanded: true,
                        underline: SizedBox(),
                        items: [
                          DropdownMenuItem(value: 'standard', child: Text('Standard')),
                          DropdownMenuItem(value: 'deluxe', child: Text('Deluxe')),
                          DropdownMenuItem(value: 'ultimate', child: Text('Ultimate')),
                          DropdownMenuItem(value: 'gold', child: Text('Gold')),
                          DropdownMenuItem(value: 'complete', child: Text('Complete')),
                          DropdownMenuItem(value: 'goty', child: Text('GOTY')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedEdition = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'المنطقة:' : 'Region:',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedRegion,
                        isExpanded: true,
                        underline: SizedBox(),
                        items: [
                          DropdownMenuItem(value: 'us', child: Text('US')),
                          DropdownMenuItem(value: 'eu', child: Text('EU')),
                          DropdownMenuItem(value: 'uk', child: Text('UK')),
                          DropdownMenuItem(value: 'asia', child: Text('Asia')),
                          DropdownMenuItem(value: 'japan', child: Text('Japan')),
                          DropdownMenuItem(value: 'global', child: Text('Global')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedRegion = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Platform Selection
          Text(
            isArabic ? 'المنصة:' : 'Platform:',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              _buildPlatformChip(Platform.ps4, 'PS4', isArabic),
              SizedBox(width: 12.w),
              _buildPlatformChip(Platform.ps5, 'PS5', isArabic),
            ],
          ),

          SizedBox(height: 16.h),

          // Account Type Selection with values
          Text(
            isArabic ? 'نوع الحساب:' : 'Account Type:',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            children: [
              // CHANGED: The value in the chips is now a percentage.
              _buildAccountTypeChip(
                AccountType.primary,
                isArabic ? 'أساسي' : 'Primary',
                '100%',
                isArabic,
              ),
              _buildAccountTypeChip(
                AccountType.secondary,
                isArabic ? 'ثانوي' : 'Secondary',
                '75%',
                isArabic,
              ),
              _buildAccountTypeChip(
                AccountType.full,
                isArabic ? 'كامل' : 'Full',
                '150%',
                isArabic,
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // Account Credentials
          Text(
            isArabic ? 'بيانات الحساب:' : 'Account Credentials:',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),

          TextField(
            controller: _accountEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: isArabic ? 'البريد الإلكتروني للحساب' : 'Account Email',
              prefixIcon: Icon(Icons.email, color: AppTheme.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),

          SizedBox(height: 16.h),

          TextField(
            controller: _accountPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: isArabic ? 'كلمة مرور الحساب' : 'Account Password',
              prefixIcon: Icon(Icons.lock, color: AppTheme.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                isArabic ? 'إرسال طلب المساهمة' : 'Submit Contribution Request',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundContributionTab(bool isArabic, bool isDarkMode) {
    // This entire widget seems correct and requires no changes.
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'الألعاب المتاحة للتمويل:' : 'Games Available for Funding:',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),

          if (_availableFundGames.isEmpty)
            Center(
              child: Text(
                isArabic
                    ? 'لا توجد ألعاب متاحة للتمويل حالياً'
                    : 'No games available for funding currently',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey,
                ),
              ),
            )
          else
            ...(_availableFundGames.map((game) => _buildFundGameCard(
              game,
              isArabic,
              isDarkMode,
            )).toList()),

          if (_selectedFundGameId != null) ...[
            SizedBox(height: 24.h),

            TextField(
              controller: _fundAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isArabic ? 'المبلغ (جنيه مصري)' : 'Amount (EGP)',
                hintText: isArabic ? 'الحد الأدنى 50 جنيه' : 'Minimum 50 LE',
                prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),

            SizedBox(height: 16.h),

            Text(
              isArabic ? 'طريقة الدفع:' : 'Payment Method:',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),

            Column(
              children: [
                _buildPaymentMethodTile('InstaPay', Icons.flash_on, isArabic),
                _buildPaymentMethodTile('Vodafone Cash', Icons.phone_android, isArabic),
                _buildPaymentMethodTile('Bank Transfer', Icons.account_balance, isArabic),
              ],
            ),

            SizedBox(height: 24.h),

            Text(
              isArabic ? 'إيصال الدفع:' : 'Payment Receipt:',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),

            InkWell(
              onTap: _pickPaymentReceipt,
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                height: 150.h,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  color: AppTheme.primaryColor.withOpacity(0.05),
                ),
                child: _paymentReceiptImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Image.file(
                    _paymentReceiptImage!,
                    fit: BoxFit.cover,
                  ),
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 48.sp,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      isArabic
                          ? 'اضغط لرفع إيصال الدفع'
                          : 'Tap to upload payment receipt',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                  isArabic ? 'إرسال طلب التمويل' : 'Submit Fund Request',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade800,
                  Colors.blue.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                Icon(
                  FontAwesomeIcons.playstation,
                  color: Colors.white,
                  size: 48.sp,
                ),
                SizedBox(height: 12.h),
                Text(
                  'PlayStation Plus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  // CHANGED: To reflect the correct value consistently.
                  isArabic
                      ? 'قيمة حد المحطة: 200 جنيه'
                      : 'Station Limit Value: 200 LE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  isArabic
                      ? 'قيمة الاستعارة: مضاعفة (200%)'
                      : 'Borrow Value: Double (200%)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.infoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppTheme.infoColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'ملاحظات مهمة:' : 'Important Notes:',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                _buildBenefitItem(
                  isArabic
                      ? 'يحسب كمساهمة مضاعفة'
                      : 'Counts as double contribution',
                  Icons.star,
                ),
                _buildBenefitItem(
                  isArabic
                      ? 'يتطلب موافقة المدير'
                      : 'Requires admin approval',
                  Icons.admin_panel_settings,
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          Text(
            isArabic ? 'بيانات حساب PS Plus:' : 'PS Plus Account Details:',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),

          // FIX: Use the new PS Plus email controller.
          TextField(
            controller: _psPlusAccountEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: isArabic ? 'البريد الإلكتروني' : 'Account Email',
              prefixIcon: Icon(Icons.email, color: Colors.blue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),

          SizedBox(height: 16.h),

          // FIX: Use the new PS Plus password controller.
          TextField(
            controller: _psPlusAccountPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: isArabic ? 'كلمة المرور' : 'Account Password',
              prefixIcon: Icon(Icons.lock, color: Colors.blue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                isArabic ? 'إرسال طلب PS Plus' : 'Submit PS Plus Request',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildFundGameCard(
      Map<String, dynamic> game,
      bool isArabic,
      bool isDarkMode,
      ) {
    final isSelected = _selectedFundGameId == game['id'];
    final progress = (game['currentFunding'] ?? 0) / (game['targetPrice'] ?? 1);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12.r),
        color: isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : isDarkMode ? AppTheme.darkSurface : Colors.white,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFundGameId = isSelected ? null : game['id'];
          });
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      game['title'] ?? '',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryColor,
                    ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                '${isArabic ? 'السعر المستهدف:' : 'Target Price:'} ${game['targetPrice']} LE',
                style: TextStyle(fontSize: 14.sp),
              ),
              SizedBox(height: 4.h),
              Text(
                '${isArabic ? 'تم جمع:' : 'Collected:'} ${game['currentFunding'] ?? 0} LE',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppTheme.successColor,
                ),
              ),
              SizedBox(height: 8.h),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.successColor),
              ),
              SizedBox(height: 4.h),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% ${isArabic ? 'مكتمل' : 'Complete'}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformChip(Platform platform, String label, bool isArabic) {
    final isSelected = _selectedPlatform == platform;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPlatform = platform;
          });
        }
      },
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildAccountTypeChip(
      AccountType type,
      String label,
      String value,
      bool isArabic,
      ) {
    final isSelected = _selectedAccountType == type;

    return ChoiceChip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppTheme.primaryColor,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedAccountType = type;
          });
        }
      },
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
      ),
    );
  }

  Widget _buildPaymentMethodTile(String method, IconData icon, bool isArabic) {
    final isSelected = _selectedPaymentMethod == method;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12.r),
        color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.primaryColor : Colors.grey,
        ),
        title: Text(
          method,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedPaymentMethod = method;
          });
        },
        trailing: isSelected
            ? Icon(
          Icons.check_circle,
          color: AppTheme.primaryColor,
        )
            : null,
      ),
    );
  }

  Widget _buildBenefitItem(String text, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20.sp,
            color: AppTheme.successColor,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }
}