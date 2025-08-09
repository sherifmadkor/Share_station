// lib/screens/user/borrow_game_screen.dart

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
import '../../widgets/custom_loading.dart';

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

  // Available slots for this game
  List<Map<String, dynamic>> _availableSlots = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableSlots();
  }

  void _loadAvailableSlots() {
    _availableSlots.clear();

    if (widget.game.accounts != null && widget.game.accounts!.isNotEmpty) {
      // New structure with multiple accounts
      for (var account in widget.game.accounts!) {
        final accountId = account['accountId'];
        final platforms = account['platforms'] as List<dynamic>? ?? [];
        final sharingOptions = account['sharingOptions'] as List<dynamic>? ?? [];
        final slots = account['slots'] as Map<String, dynamic>? ?? {};

        slots.forEach((slotKey, slotData) {
          if (slotData['status'] == 'available') {
            _availableSlots.add({
              'accountId': accountId,
              'slotKey': slotKey,
              'platform': slotData['platform'],
              'accountType': slotData['accountType'],
              'slotData': slotData,
            });
          }
        });
      }
    } else {
      // Old structure
      widget.game.slots.forEach((slotKey, slot) {
        if (slot.status == game_models.SlotStatus.available) {
          _availableSlots.add({
            'accountId': widget.game.accountId,
            'slotKey': slotKey,
            'platform': slot.platform.value,
            'accountType': slot.accountType.value,
            'slotData': slot,
          });
        }
      });
    }

    // Pre-select first available slot
    if (_availableSlots.isNotEmpty) {
      final firstSlot = _availableSlots.first;
      setState(() {
        _selectedAccountId = firstSlot['accountId'];
        _selectedPlatform = game_models.Platform.fromString(firstSlot['platform']);
        _selectedAccountType = game_models.AccountType.fromString(firstSlot['accountType']);
        _selectedSlot = firstSlot;
      });
    }
  }

  double _calculateBorrowValue() {
    if (_selectedAccountType == null) return widget.game.gameValue;
    return widget.game.gameValue * _selectedAccountType!.borrowMultiplier;
  }

  Future<void> _submitBorrowRequest() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    final user = authProvider.currentUser;
    if (user == null) {
      Fluttertoast.showToast(
        msg: isArabic ? 'يجب تسجيل الدخول' : 'Please login',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }

    // Check if borrow window is open
    try {
      final windowDoc = await _firestore
          .collection('settings')
          .doc('borrow_window')
          .get();

      final isWindowOpen = windowDoc.data()?['isOpen'] ?? false;

      if (!isWindowOpen && !authProvider.isAdmin) {
        Fluttertoast.showToast(
          msg: isArabic
              ? 'نافذة الاستعارة مغلقة حالياً. يرجى المحاولة يوم الخميس.'
              : 'Borrow window is currently closed. Please try on Thursday.',
          backgroundColor: AppTheme.warningColor,
          toastLength: Toast.LENGTH_LONG,
        );
        return;
      }
    } catch (e) {
      print('Error checking borrow window: $e');
    }

    if (_selectedPlatform == null || _selectedAccountType == null || _selectedAccountId == null) {
      Fluttertoast.showToast(
        msg: isArabic ? 'الرجاء اختيار المنصة ونوع الحساب' : 'Please select platform and account type',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    final borrowValue = _calculateBorrowValue();

    // Check Station Limit (but don't consume it yet)
    if (user.remainingStationLimit < borrowValue) {
      Fluttertoast.showToast(
        msg: isArabic
            ? 'حد المحطة غير كافي. المطلوب: ${borrowValue.toStringAsFixed(0)} LE'
            : 'Insufficient Station Limit. Required: ${borrowValue.toStringAsFixed(0)} LE',
        backgroundColor: AppTheme.errorColor,
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    // Check Borrow Limit
    final borrowCount = _selectedAccountType!.borrowLimitImpact;
    if (user.currentBorrows + borrowCount > user.borrowLimit) {
      Fluttertoast.showToast(
        msg: isArabic
            ? 'لقد وصلت إلى حد الاستعارة المتزامنة (${user.borrowLimit})'
            : 'You have reached your simultaneous borrow limit (${user.borrowLimit})',
        backgroundColor: AppTheme.errorColor,
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await _borrowService.submitBorrowRequest(
        userId: user.uid,
        userName: user.name,
        gameId: widget.game.accountId,
        gameTitle: widget.game.title,
        accountId: _selectedAccountId!,
        platform: _selectedPlatform!,
        accountType: _selectedAccountType!,
        borrowValue: widget.game.gameValue,
      );

      if (result['success']) {
        Fluttertoast.showToast(
          msg: isArabic
              ? 'تم إرسال طلب الاستعارة بنجاح! في انتظار موافقة المسؤول'
              : 'Borrow request submitted successfully! Awaiting admin approval',
          backgroundColor: AppTheme.successColor,
          toastLength: Toast.LENGTH_LONG,
        );

        Navigator.pop(context, true);
      } else {
        Fluttertoast.showToast(
          msg: result['message'] ?? 'Failed to submit request',
          backgroundColor: AppTheme.errorColor,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (e) {
      print('Error submitting borrow request: $e');
      Fluttertoast.showToast(
        msg: isArabic ? 'حدث خطأ' : 'An error occurred',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    final user = authProvider.currentUser;
    final borrowValue = _calculateBorrowValue();

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          isArabic ? 'طلب استعارة' : 'Borrow Request',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Borrow Window Status Check
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('settings').doc('borrow_window').snapshots(),
              builder: (context, snapshot) {
                bool isWindowOpen = false;
                if (snapshot.hasData && snapshot.data!.exists) {
                  isWindowOpen = snapshot.data!.data() as bool;['isOpen'] ?? false;
                }

                if (!isWindowOpen && !authProvider.isAdmin) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 16.h),
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppTheme.errorColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock,
                          color: AppTheme.errorColor,
                          size: 24.sp,
                        ),
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
                                    ? 'يمكن تقديم طلبات الاستعارة فقط عندما يفتح المسؤول النافذة'
                                    : 'Borrow requests can only be submitted when admin opens the window',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppTheme.errorColor.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (isWindowOpen) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 16.h),
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppTheme.successColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.successColor,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          isArabic ? 'نافذة الاستعارة مفتوحة' : 'Borrow window is open',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),
            // Game Info Card
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Game Cover
                  if (widget.game.coverImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                      child: CachedNetworkImage(
                        imageUrl: widget.game.coverImageUrl!,
                        height: 200.h,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200.h,
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200.h,
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          child: Icon(
                            FontAwesomeIcons.gamepad,
                            size: 50.sp,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),

                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Game Title
                        Text(
                          widget.game.title,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),

                        // Lender Info
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16.sp,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              widget.game.contributorName,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: _getLenderColor(widget.game.lenderTier).withOpacity(0.1),
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
                  color: AppTheme.errorColor.withOpacity(0.1),
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
                  final platform = game_models.Platform.fromString(slot['platform']);
                  final accountType = game_models.AccountType.fromString(slot['accountType']);
                  final isSelected = _selectedSlot == slot;

                  return Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : isDarkMode ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey.withOpacity(0.3),
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
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.indigo.withOpacity(0.1),
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
                                  Row(
                                    children: [
                                      Text(
                                        platform.displayName,
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: _getAccountTypeColor(accountType).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                        child: Text(
                                          accountType.displayName,
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: _getAccountTypeColor(accountType),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    '${isArabic ? "قيمة الاستعارة:" : "Borrow Value:"} ${(widget.game.gameValue * accountType.borrowMultiplier).toStringAsFixed(0)} LE',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Selection indicator
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: AppTheme.primaryColor,
                                size: 24.sp,
                              )
                            else
                              Icon(
                                Icons.radio_button_unchecked,
                                color: Colors.grey,
                                size: 24.sp,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            SizedBox(height: 24.h),

            // User Metrics Info
            if (user != null) ...[
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  children: [
                    // Station Limit
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              FontAwesomeIcons.gauge,
                              size: 16.sp,
                              color: AppTheme.infoColor,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              isArabic ? 'حد المحطة المتبقي' : 'Remaining Station Limit',
                              style: TextStyle(fontSize: 14.sp),
                            ),
                          ],
                        ),
                        Text(
                          '${user.remainingStationLimit.toStringAsFixed(0)} LE',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: user.remainingStationLimit >= borrowValue
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8.h),

                    // Borrow Value
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.remove_circle_outline,
                              size: 16.sp,
                              color: AppTheme.warningColor,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              isArabic ? 'قيمة الاستعارة' : 'Borrow Value',
                              style: TextStyle(fontSize: 14.sp),
                            ),
                          ],
                        ),
                        Text(
                          '- ${borrowValue.toStringAsFixed(0)} LE',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),

                    Divider(height: 16.h),

                    // After Borrow
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isArabic ? 'بعد الاستعارة' : 'After Borrow',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${(user.remainingStationLimit - borrowValue).toStringAsFixed(0)} LE',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12.h),

              // Borrow Limit Info
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.gamepad,
                          size: 16.sp,
                          color: AppTheme.secondaryColor,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          isArabic ? 'الاستعارات النشطة' : 'Active Borrows',
                          style: TextStyle(fontSize: 14.sp),
                        ),
                      ],
                    ),
                    Text(
                      '${user.currentBorrows.toStringAsFixed(1)} / ${user.borrowLimit}',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: user.currentBorrows >= user.borrowLimit
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 24.h),

            // Submit Button with Window Status Check
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('settings').doc('borrow_window').snapshots(),
              builder: (context, snapshot) {
                bool isWindowOpen = false;
                if (snapshot.hasData && snapshot.data!.exists) {
                  isWindowOpen = snapshot.data!.data() as bool;['isOpen'] ?? false;
                }

                final canSubmit = (isWindowOpen || authProvider.isAdmin) && _availableSlots.isNotEmpty;

                return SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: _isSubmitting || !canSubmit
                        ? null
                        : _submitBorrowRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      !isWindowOpen && !authProvider.isAdmin
                          ? (isArabic ? 'نافذة الاستعارة مغلقة' : 'Borrow Window Closed')
                          : (isArabic ? 'إرسال طلب الاستعارة' : 'Submit Borrow Request'),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Note about approval
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16.sp,
                    color: AppTheme.warningColor,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'سيتم خصم حد المحطة فقط بعد موافقة المسؤول'
                          : 'Station Limit will only be deducted after admin approval',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.warningColor,
                      ),
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

  Color _getLenderColor(game_models.LenderTier tier) {
    switch (tier) {
      case game_models.LenderTier.gamesVault:
        return AppTheme.vipColor;
      case game_models.LenderTier.member:
        return AppTheme.memberColor;
      case game_models.LenderTier.admin:
        return AppTheme.adminColor;
      case game_models.LenderTier.nonMember:
        return AppTheme.userColor;
    }
  }

  String _getLenderLabel(game_models.LenderTier tier, bool isArabic) {
    switch (tier) {
      case game_models.LenderTier.gamesVault:
        return isArabic ? 'خزينة الألعاب' : 'Games Vault';
      case game_models.LenderTier.member:
        return isArabic ? 'عضو' : 'Member';
      case game_models.LenderTier.admin:
        return isArabic ? 'إدارة' : 'Admin';
      case game_models.LenderTier.nonMember:
        return isArabic ? 'غير عضو' : 'Non-Member';
    }
  }

  Color _getAccountTypeColor(game_models.AccountType type) {
    switch (type) {
      case game_models.AccountType.full:
        return Colors.purple;
      case game_models.AccountType.primary:
        return AppTheme.primaryColor;
      case game_models.AccountType.secondary:
        return AppTheme.secondaryColor;
      case game_models.AccountType.psPlus:
        return Colors.amber;
    }
  }
}