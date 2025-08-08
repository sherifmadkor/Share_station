import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

// FIX: Changed prefix from 'game' to 'game_models' to avoid conflict with parameter name
import '../../../data/models/game_model.dart' as game_models;
import '../../../data/models/user_model.dart' as user_model;
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class BorrowRequestScreen extends StatefulWidget {
  // Using the prefixed 'game_models' namespace
  final game_models.GameAccount game;

  const BorrowRequestScreen({
    super.key,
    required this.game,
  });

  @override
  State<BorrowRequestScreen> createState() => _BorrowRequestScreenState();
}

class _BorrowRequestScreenState extends State<BorrowRequestScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Using the prefixed 'game_models' namespace for the types
  game_models.Platform? _selectedPlatform;
  game_models.AccountType? _selectedAccountType;
  bool _isSubmitting = false;

  // Queue position if game is unavailable
  int? _queuePosition;
  DateTime? _estimatedAvailability;

  @override
  void initState() {
    super.initState();
    _initializeSelections();
    _checkQueuePosition();
  }

  void _initializeSelections() {
    // Pre-select first available platform
    if (widget.game.supportedPlatforms.isNotEmpty) {
      _selectedPlatform = widget.game.supportedPlatforms.first;
    }

    // Pre-select first available account type
    if (widget.game.sharingOptions.isNotEmpty) {
      _selectedAccountType = widget.game.sharingOptions.first;
    }
  }

  Future<void> _checkQueuePosition() async {
    if (!_isSlotAvailable()) {
      // Check how many people are in queue for this game
      final queue = await _firestore
          .collection('borrow_requests')
          .where('gameId', isEqualTo: widget.game.accountId)
          .where('status', whereIn: ['pending', 'queued'])
          .orderBy('createdAt')
          .get();

      if (mounted) {
        setState(() {
          _queuePosition = queue.docs.length + 1;
          // Estimate 7 days per person in queue (based on weekly Thursday window)
          _estimatedAvailability = DateTime.now().add(
            Duration(days: 7 * (queue.docs.length + 1)),
          );
        });
      }
    }
  }

  bool _isSlotAvailable() {
    if (_selectedPlatform == null || _selectedAccountType == null) return false;

    final slotKey = '${_selectedPlatform!.name}_${_selectedAccountType!.name}';
    final slot = widget.game.slots[slotKey];

    // Using prefixed 'game_models' namespace
    return slot?.status == game_models.SlotStatus.available;
  }

  double _calculateBorrowValue() {
    if (_selectedAccountType == null) return widget.game.gameValue;

    // Per BRD: Borrow value calculation
    // Using prefixed 'game_models' namespace
    switch (_selectedAccountType!) {
      case game_models.AccountType.primary:
        return widget.game.gameValue; // 100% of value
      case game_models.AccountType.secondary:
        return widget.game.gameValue * 0.75; // 75% of value
      case game_models.AccountType.full:
        return widget.game.gameValue * 1.5; // 150% of value (full access)
      case game_models.AccountType.psPlus:
        return widget.game.gameValue * 2.0; // 200% of value (PS Plus)
    }
  }

  Future<void> _submitBorrowRequest() async {
    // Using context before the async gap is safe
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    final user = authProvider.currentUser;

    if (user == null) {
      Fluttertoast.showToast(
        msg: isArabic ? 'يجب تسجيل الدخول أولاً' : 'Please login first',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }

    final borrowValue = _calculateBorrowValue();

    // Validate Station Limit
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

    // Validate Borrow Limit
    if (user.currentBorrows >= user.borrowLimit) {
      Fluttertoast.showToast(
        msg: isArabic
            ? 'لقد وصلت إلى حد الاستعارة المتزامنة'
            : 'You have reached your simultaneous borrow limit',
        backgroundColor: AppTheme.errorColor,
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    // Check cooldown period
    if (user.coolDownEndDate != null && user.coolDownEndDate!.isAfter(DateTime.now())) {
      final daysLeft = user.coolDownEndDate!.difference(DateTime.now()).inDays;
      Fluttertoast.showToast(
        msg: isArabic
            ? 'أنت في فترة التهدئة. متبقي: $daysLeft أيام'
            : 'You are in cooldown period. $daysLeft days remaining',
        backgroundColor: AppTheme.warningColor,
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Create borrow request
      final requestData = {
        'gameId': widget.game.accountId,
        'gameTitle': widget.game.title,
        'borrowerId': user.uid,
        'borrowerName': user.name,
        'borrowerTier': user.tier.name,
        'platform': _selectedPlatform!.name,
        'accountType': _selectedAccountType!.name,
        'borrowValue': borrowValue,
        'userRemainingLimit': user.remainingStationLimit,
        'status': _isSlotAvailable() ? 'pending' : 'queued',
        'queuePosition': _queuePosition,
        'estimatedAvailability': _estimatedAvailability?.toIso8601String(),
        'contributorId': widget.game.contributorId,
        'contributorName': widget.game.contributorName,
        'lenderTier': widget.game.lenderTier.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('borrow_requests').add(requestData);

      // Check if widget is still mounted before using context
      if (!mounted) return;

      Fluttertoast.showToast(
        msg: _isSlotAvailable()
            ? (isArabic
            ? 'تم إرسال طلب الاستعارة. في انتظار موافقة المسؤول'
            : 'Borrow request submitted. Awaiting admin approval')
            : (isArabic
            ? 'تمت إضافتك إلى قائمة الانتظار. موقعك: $_queuePosition'
            : 'Added to queue. Your position: $_queuePosition'),
        backgroundColor: AppTheme.successColor,
        toastLength: Toast.LENGTH_LONG,
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error submitting borrow request: $e');
      Fluttertoast.showToast(
        msg: isArabic
            ? 'حدث خطأ. حاول مرة أخرى'
            : 'An error occurred. Please try again',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
    final isSlotAvailable = _isSlotAvailable();

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          isArabic ? 'طلب استعارة' : 'Borrow Request',
          style: TextStyle(
            color: isDarkMode ? Colors.white : AppTheme.darkBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Info Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Padding(
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
                    if (widget.game.description != null && widget.game.description!.isNotEmpty)
                      Text(
                        widget.game.description!,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: isDarkMode
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        _buildInfoChip(
                          icon: Icons.star,
                          label: widget.game.edition ?? 'Standard',
                          color: Colors.amber,
                        ),
                        SizedBox(width: 8.w),
                        _buildInfoChip(
                          icon: Icons.public,
                          label: widget.game.region ?? 'Global',
                          color: AppTheme.infoColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20.h),

            // Platform Selection
            Text(
              isArabic ? 'اختر المنصة:' : 'Select Platform:',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: widget.game.supportedPlatforms.map((platform) {
                final isSelected = _selectedPlatform == platform;
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: ChoiceChip(
                    label: Text(platform.displayName),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedPlatform = platform;
                        _checkQueuePosition();
                      });
                    },
                    selectedColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 20.h),

            // Account Type Selection
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
              runSpacing: 8.h,
              children: widget.game.sharingOptions.map((type) {
                final isSelected = _selectedAccountType == type;
                return ChoiceChip(
                  label: Text(_getAccountTypeLabel(type, isArabic)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedAccountType = type;
                      _checkQueuePosition();
                    });
                  },
                  selectedColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : null,
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 20.h),

            // Availability Status
            Card(
              color: isSlotAvailable
                  ? AppTheme.successColor.withOpacity(0.1)
                  : AppTheme.warningColor.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
                side: BorderSide(
                  color: isSlotAvailable
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSlotAvailable
                              ? Icons.check_circle
                              : Icons.access_time,
                          color: isSlotAvailable
                              ? AppTheme.successColor
                              : AppTheme.warningColor,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          isSlotAvailable
                              ? (isArabic ? 'متاح للاستعارة' : 'Available for Borrowing')
                              : (isArabic ? 'في قائمة الانتظار' : 'Join Queue'),
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: isSlotAvailable
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                    if (!isSlotAvailable && _queuePosition != null) ...[
                      SizedBox(height: 12.h),
                      Text(
                        isArabic
                            ? 'موقعك في القائمة: $_queuePosition'
                            : 'Your queue position: $_queuePosition',
                        style: TextStyle(fontSize: 14.sp),
                      ),
                      if (_estimatedAvailability != null)
                        Text(
                          isArabic
                              ? 'التوفر المتوقع: ${_formatDate(_estimatedAvailability!)}'
                              : 'Estimated availability: ${_formatDate(_estimatedAvailability!)}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: isDarkMode
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 20.h),

            // Borrow Cost Breakdown
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'تفاصيل الاستعارة:' : 'Borrowing Details:',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _buildCostRow(
                      label: isArabic ? 'قيمة اللعبة الأساسية' : 'Base Game Value',
                      value: '${widget.game.gameValue.toStringAsFixed(0)} LE',
                    ),
                    _buildCostRow(
                      label: isArabic ? 'معامل نوع الحساب' : 'Account Type Multiplier',
                      value: _getMultiplierText(_selectedAccountType),
                    ),
                    Divider(height: 20.h),
                    _buildCostRow(
                      label: isArabic ? 'قيمة الاستعارة' : 'Borrow Value',
                      value: '${borrowValue.toStringAsFixed(0)} LE',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20.h),

            // User Station Limit Status
            if (user != null)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'حالة حسابك:' : 'Your Account Status:',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _buildStatusRow(
                        label: isArabic ? 'حد المحطة المتبقي' : 'Remaining Station Limit',
                        value: '${user.remainingStationLimit.toStringAsFixed(0)} LE',
                        hasEnough: user.remainingStationLimit >= borrowValue,
                      ),
                      _buildStatusRow(
                        label: isArabic ? 'الاستعارات الحالية' : 'Current Borrows',
                        value: '${user.currentBorrows} / ${user.borrowLimit}',
                        hasEnough: user.currentBorrows < user.borrowLimit,
                      ),
                      if (user.tier == user_model.UserTier.client && user.freeborrowings > 0)
                        _buildStatusRow(
                          label: isArabic ? 'الاستعارات المجانية' : 'Free Borrows',
                          value: '${user.freeborrowings}',
                          hasEnough: true,
                        ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 20.h),

            // Important Notice
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: AppTheme.infoColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.infoColor,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'سيتم مراجعة طلبك من قبل المسؤول. ستتلقى إشعارًا عند الموافقة.'
                          : 'Your request will be reviewed by admin. You will be notified upon approval.',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.infoColor,
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
              height: 48.h,
              child: ElevatedButton(
                onPressed: _isSubmitting || user == null
                    ? null
                    : _submitBorrowRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                )
                    : Text(
                  isSlotAvailable
                      ? (isArabic ? 'إرسال طلب الاستعارة' : 'Submit Borrow Request')
                      : (isArabic ? 'الانضمام إلى قائمة الانتظار' : 'Join Waiting Queue'),
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
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow({
    required String label,
    required String value,
    bool isTotal = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16.sp : 14.sp,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppTheme.primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required String label,
    required String value,
    required bool hasEnough,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14.sp),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: hasEnough ? AppTheme.successColor : AppTheme.errorColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                hasEnough ? Icons.check_circle : Icons.cancel,
                size: 16.sp,
                color: hasEnough ? AppTheme.successColor : AppTheme.errorColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Using prefixed 'game_models' namespace
  String _getAccountTypeLabel(game_models.AccountType type, bool isArabic) {
    switch (type) {
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

  // Using prefixed 'game_models' namespace
  String _getMultiplierText(game_models.AccountType? type) {
    if (type == null) return '1x';
    switch (type) {
      case game_models.AccountType.primary:
        return '1x (100%)';
      case game_models.AccountType.secondary:
        return '0.75x (75%)';
      case game_models.AccountType.full:
        return '1.5x (150%)';
      case game_models.AccountType.psPlus:
        return '2x (200%)';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}