// lib/presentation/screens/user/borrow_game_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_model.dart' as game_models;
import '../../../services/borrow_service.dart';
// import '../../widgets/custom_loading.dart'; // Unused import removed

class BorrowGameScreen extends StatefulWidget {
  final game_models.GameAccount game;

  const BorrowGameScreen({
    Key? key,
    required this.game,
  }) : super(key: key);

  @override
  State<BorrowGameScreen> createState() => _BorrowGameScreenState();
}

class _BorrowGameScreenState extends State<BorrowGameScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BorrowService _borrowService = BorrowService();

  game_models.Platform? _selectedPlatform;
  game_models.AccountType? _selectedAccountType;
  String? _selectedAccountId;
  Map<String, dynamic>? _selectedSlot;

  bool _isSubmitting = false;
  bool _isWindowOpen = false;

  // Available slots for this game
  List<Map<String, dynamic>> _availableSlots = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableSlots();
    _checkBorrowWindow();
  }

  Future<void> _checkBorrowWindow() async {
    try {
      final windowDoc = await _firestore
          .collection('settings')
          .doc('borrow_window')
          .get();

      if (mounted) {
        setState(() {
          _isWindowOpen = windowDoc.data()?['isOpen'] ?? false;
        });
      }
    } catch (e) {
      print('Error checking borrow window: $e');
    }
  }

  void _loadAvailableSlots() {
    _availableSlots.clear();

    if (widget.game.accounts != null && widget.game.accounts!.isNotEmpty) {
      // New structure with multiple accounts
      for (var account in widget.game.accounts!) {
        final accountId = account['accountId'] as String?;
        final slots = account['slots'] as Map<String, dynamic>? ?? {};

        slots.forEach((slotKey, slotData) {
          if (slotData is Map<String, dynamic> && slotData['status'] == 'available') {
            // Parse the slot key to get platform and account type
            final parts = slotKey.split('_');
            if (parts.length >= 2) {
              _availableSlots.add({
                'accountId': accountId,
                'slotKey': slotKey,
                'platform': parts[0], // e.g., 'ps5' or 'ps4'
                'accountType': parts.length > 2 ? parts.sublist(1).join('_') : parts[1], // Handle account types with underscores
                'slotData': slotData,
              });
            }
          }
        });
      }
    } else {
      // Old structure - handle legacy game model
      widget.game.slots.forEach((slotKey, slot) {
        if (slot.status == game_models.SlotStatus.available) {
          _availableSlots.add({
            'accountId': widget.game.accountId,
            'slotKey': slotKey,
            'platform': slot.platform.value,
            'accountType': slot.accountType.value,
            'slotData': {
              'status': 'available',
              'platform': slot.platform.value,
              'accountType': slot.accountType.value,
            },
          });
        }
      });
    }

    // Pre-select first available slot
    if (_availableSlots.isNotEmpty) {
      final firstSlot = _availableSlots.first;
      setState(() {
        _selectedAccountId = firstSlot['accountId'];
        _selectedPlatform = _getPlatformFromString(firstSlot['platform']);
        _selectedAccountType = _getAccountTypeFromString(firstSlot['accountType']);
        _selectedSlot = firstSlot;
      });
    }
  }

  game_models.Platform? _getPlatformFromString(String value) {
    switch (value.toLowerCase()) {
      case 'ps5':
        return game_models.Platform.ps5;
      case 'ps4':
        return game_models.Platform.ps4;
      default:
        return null;
    }
  }

  game_models.AccountType? _getAccountTypeFromString(String value) {
    switch (value.toLowerCase()) {
      case 'primary':
        return game_models.AccountType.primary;
      case 'secondary':
        return game_models.AccountType.secondary;
      case 'full':
        return game_models.AccountType.full;
      case 'ps_plus':
      case 'psplus':
        return game_models.AccountType.psPlus;
      default:
        return null;
    }
  }

  double _calculateBorrowValue() {
    if (_selectedAccountType == null) return widget.game.gameValue;

    // Use the borrow multiplier from the account type
    switch (_selectedAccountType!) {
      case game_models.AccountType.primary:
        return widget.game.gameValue * 1.0; // 100%
      case game_models.AccountType.secondary:
        return widget.game.gameValue * 0.75; // 75%
      case game_models.AccountType.full:
        return widget.game.gameValue * 1.0; // 100%
      case game_models.AccountType.psPlus:
        return widget.game.gameValue * 2.0; // 200%
    }
  }

  Future<void> _submitBorrowRequest() async {
    // Using context.read is safer in async methods
    final appProvider = context.read<AppProvider>();
    final authProvider = context.read<AuthProvider>();
    final isArabic = appProvider.isArabic;

    final user = authProvider.currentUser;
    if (user == null) {
      Fluttertoast.showToast(
        msg: isArabic ? 'يجب تسجيل الدخول' : 'Please login',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }

    // Check if borrow window is open (refresh check)
    await _checkBorrowWindow();

    if (!_isWindowOpen && !authProvider.isAdmin) {
      Fluttertoast.showToast(
        msg: isArabic
            ? 'نافذة الاستعارة مغلقة حالياً. يرجى المحاولة يوم الخميس.'
            : 'Borrow window is currently closed. Please try on Thursday.',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }

    if (_selectedSlot == null || _selectedPlatform == null || _selectedAccountType == null) {
      Fluttertoast.showToast(
        msg: isArabic ? 'يرجى اختيار خيار الاستعارة' : 'Please select a borrow option',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await _borrowService.submitBorrowRequest(
        userId: user.uid,
        userName: user.name,
        memberId: user.memberId,
        gameId: widget.game.accountId,
        gameTitle: widget.game.title,
        accountId: _selectedAccountId ?? '',
        platform: _selectedPlatform!,
        accountType: _selectedAccountType!,
        borrowValue: _calculateBorrowValue(),
      );

      if (result['success'] == true) {
        Fluttertoast.showToast(
          msg: isArabic
              ? 'تم إرسال طلب الاستعارة بنجاح! في انتظار موافقة المشرف.'
              : 'Borrow request submitted successfully! Waiting for admin approval.',
          backgroundColor: AppTheme.successColor,
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        Fluttertoast.showToast(
          msg: result['message'] ?? (isArabic ? 'حدث خطأ' : 'An error occurred'),
          backgroundColor: AppTheme.errorColor,
        );
      }
    } catch (e) {
      print('Error submitting borrow request: $e');
      Fluttertoast.showToast(
        msg: isArabic ? 'حدث خطأ. حاول مرة أخرى.' : 'An error occurred. Please try again.',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Color _getLenderColor(game_models.LenderTier tier) {
    switch (tier) {
      case game_models.LenderTier.member:
        return Colors.blue;
      case game_models.LenderTier.gamesVault:
        return Colors.green;
      case game_models.LenderTier.nonMember:
        return Colors.orange;
      case game_models.LenderTier.admin:
        return Colors.purple; // FIXED: Added admin case
    }
  }

  String _getLenderLabel(game_models.LenderTier tier, bool isArabic) {
    switch (tier) {
      case game_models.LenderTier.member:
        return isArabic ? 'ألعاب الأعضاء' : "Members' Games";
      case game_models.LenderTier.gamesVault:
        return isArabic ? 'خزنة الألعاب' : 'Games Vault';
      case game_models.LenderTier.nonMember:
        return isArabic ? 'غير الأعضاء' : 'Non-Members';
      case game_models.LenderTier.admin: // FIXED: Added admin case
        return isArabic ? 'مشرف' : 'Admin';
    }
  }

  // FIXED: Added helper function for Platform label
  String _getPlatformLabel(game_models.Platform platform) {
    switch (platform) {
      case game_models.Platform.ps5:
        return 'PS5';
      case game_models.Platform.ps4:
        return 'PS4';
      case game_models.Platform.na:
        return 'N/A';
    }
  }

  // FIXED: Added helper function for AccountType label
  String _getAccountTypeLabel(game_models.AccountType accountType, bool isArabic) {
    switch (accountType) {
      case game_models.AccountType.primary:
        return isArabic ? 'أساسي' : 'Primary';
      case game_models.AccountType.secondary:
        return isArabic ? 'ثانوي' : 'Secondary';
      case game_models.AccountType.full:
        return isArabic ? 'كامل' : 'Full';
      case game_models.AccountType.psPlus:
        return 'PS Plus';
    }
  }


  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = appProvider.isDarkMode;
    final isArabic = appProvider.isArabic;
    final user = authProvider.currentUser;

    final borrowValue = _calculateBorrowValue();
    final remainingAfterBorrow = (user?.remainingStationLimit ?? 0) - borrowValue;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(isArabic ? 'طلب استعارة' : 'Borrow Request'),
        backgroundColor: isDarkMode ? AppTheme.darkSurface : AppTheme.primaryColor,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('settings').doc('borrow_window').snapshots(),
        builder: (context, snapshot) {
          _isWindowOpen = snapshot.data?.data() != null
              ? (snapshot.data!.data() as Map<String, dynamic>)['isOpen'] ?? false
              : false;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Borrow Window Status
                if (!_isWindowOpen && !authProvider.isAdmin)
                  Container(
                    margin: EdgeInsets.only(bottom: 16.h),
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withAlpha(26), // FIXED: withOpacity
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppTheme.errorColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: AppTheme.errorColor, size: 24.sp),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isArabic ? 'نافذة الاستعارة مغلقة' : 'Borrow Window Closed',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.errorColor,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                isArabic
                                    ? 'يمكن الاستعارة فقط أيام الخميس'
                                    : 'Borrowing is only available on Thursdays',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppTheme.errorColor.withAlpha(204), // FIXED: withOpacity
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_isWindowOpen)
                  Container(
                    margin: EdgeInsets.only(bottom: 16.h),
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withAlpha(26), // FIXED: withOpacity
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppTheme.successColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.successColor, size: 24.sp),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            isArabic ? 'نافذة الاستعارة مفتوحة الآن' : 'Borrow Window is Open',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Game Info Card
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(26), // FIXED: withOpacity
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Cover Image
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                        child: CachedNetworkImage(
                          imageUrl: widget.game.coverImageUrl ?? '',
                          height: 200.h,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.withAlpha(77), // FIXED: withOpacity
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.withAlpha(77), // FIXED: withOpacity
                            child: Icon(FontAwesomeIcons.gamepad, size: 50.sp, color: Colors.grey),
                          ),
                        ),
                      ),
                      // Game Details
                      Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.game.title,
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Text(
                                  '${widget.game.gameValue.toStringAsFixed(0)} LE',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                Text(
                                  ' • ',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.grey,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: _getLenderColor(widget.game.lenderTier).withAlpha(26), // FIXED: withOpacity
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    _getLenderLabel(widget.game.lenderTier, isArabic),
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: _getLenderColor(widget.game.lenderTier),
                                      fontWeight: FontWeight.bold,
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

                SizedBox(height: 24.h),

                // Available Slots Section
                Text(
                  isArabic ? 'الخيارات المتاحة' : 'Available Options',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),

                if (_availableSlots.isEmpty)
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withAlpha(26), // FIXED: withOpacity
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: AppTheme.errorColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppTheme.errorColor),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            isArabic
                                ? 'لا توجد نسخ متاحة حالياً'
                                : 'No copies available currently',
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: _availableSlots.map((slot) {
                      final platform = _getPlatformFromString(slot['platform']);
                      final accountType = _getAccountTypeFromString(slot['accountType']);
                      final isSelected = _selectedSlot == slot;

                      if (platform == null || accountType == null) {
                        return SizedBox.shrink();
                      }

                      return Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withAlpha(26) // FIXED: withOpacity
                              : isDarkMode ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor : Colors.grey.withAlpha(77), // FIXED: withOpacity
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedSlot = slot;
                              _selectedAccountId = slot['accountId'];
                              _selectedPlatform = platform;
                              _selectedAccountType = accountType;
                            });
                          },
                          borderRadius: BorderRadius.circular(12.r),
                          child: Padding(
                            padding: EdgeInsets.all(12.w),
                            child: Row(
                              children: [
                                // Platform Icon
                                Container(
                                  width: 40.w,
                                  height: 40.w,
                                  decoration: BoxDecoration(
                                    color: platform == game_models.Platform.ps5
                                        ? Colors.blue.withAlpha(26) // FIXED: withOpacity
                                        : Colors.indigo.withAlpha(26), // FIXED: withOpacity
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Icon(
                                    FontAwesomeIcons.playstation,
                                    color: platform == game_models.Platform.ps5
                                        ? Colors.blue
                                        : Colors.indigo,
                                    size: 20.sp,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getPlatformLabel(platform), // FIXED: Use helper
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _getAccountTypeLabel(accountType, isArabic), // FIXED: Use helper
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Borrow Value
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${(widget.game.gameValue * accountType.borrowMultiplier).toStringAsFixed(0)} LE',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    Text(
                                      '${(accountType.borrowMultiplier * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isSelected)
                                  Padding(
                                    padding: EdgeInsets.only(left: 8.w),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: AppTheme.primaryColor,
                                      size: 24.sp,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                SizedBox(height: 24.h),

                // Station Limit Info
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: (isDarkMode ? Colors.blue : Colors.blue.shade50),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.blue.withAlpha(77)), // FIXED: withOpacity
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'معلومات الحد الأقصى' : 'Station Limit Info',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isArabic ? 'الحد المتبقي الحالي:' : 'Current Remaining:'),
                          Text(
                            '${user?.remainingStationLimit.toStringAsFixed(0) ?? '0'} LE',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isArabic ? 'قيمة الاستعارة:' : 'Borrow Value:'),
                          Text(
                            '${borrowValue.toStringAsFixed(0)} LE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isArabic ? 'المتبقي بعد الاستعارة:' : 'Remaining After:'),
                          Text(
                            '${remainingAfterBorrow.toStringAsFixed(0)} LE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                              color: remainingAfterBorrow >= 0
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // Warning Note
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(26), // FIXED: withOpacity
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.orange.withAlpha(77)), // FIXED: withOpacity
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          isArabic
                              ? 'سيتم خصم الحد الأقصى فقط بعد موافقة المشرف'
                              : 'Station Limit will only be deducted after admin approval',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24.h),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || remainingAfterBorrow < 0 || (!_isWindowOpen && !authProvider.isAdmin))
                        ? null
                        : _submitBorrowRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      disabledBackgroundColor: Colors.grey.withAlpha(77), // FIXED: withOpacity
                    ),
                    child: _isSubmitting
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                      (!_isWindowOpen && !authProvider.isAdmin)
                          ? (isArabic ? 'نافذة الاستعارة مغلقة' : 'Borrow Window Closed')
                          : remainingAfterBorrow < 0
                          ? (isArabic ? 'الحد الأقصى غير كافي' : 'Insufficient Station Limit')
                          : (isArabic ? 'إرسال طلب الاستعارة' : 'Submit Borrow Request'),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}