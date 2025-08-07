import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/user_model.dart' hide Platform;

class GameDetailsModal extends StatefulWidget {
  final GameAccount game;

  const GameDetailsModal({
    Key? key,
    required this.game,
  }) : super(key: key);

  @override
  State<GameDetailsModal> createState() => _GameDetailsModalState();
}

class _GameDetailsModalState extends State<GameDetailsModal> {
  Platform? _selectedPlatform;
  AccountType? _selectedAccountType;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Pre-select first available platform
    if (widget.game.supportedPlatforms.isNotEmpty) {
      _selectedPlatform = widget.game.supportedPlatforms.first;
    }
    // Pre-select first available account type
    if (widget.game.sharingOptions.isNotEmpty) {
      _selectedAccountType = widget.game.sharingOptions.first;
    }
  }

  double get borrowValue {
    if (_selectedAccountType == null) return widget.game.gameValue;
    return widget.game.gameValue * _selectedAccountType!.borrowMultiplier;
  }

  bool get canBorrow {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final user = authProvider.currentUser;

    // Check if borrow window is open
    if (!appProvider.isBorrowWindowCurrentlyOpen() && !authProvider.isAdmin) {
      return false;
    }

    // Check if user has enough station limit
    if (user != null && user.remainingStationLimit < borrowValue) {
      return false;
    }

    // Check if user has available borrow slots
    if (user != null && user.currentBorrows >= user.borrowLimit) {
      return false;
    }

    // Check if selected slot is available
    if (_selectedPlatform != null && _selectedAccountType != null) {
      final slotKey = '${_selectedPlatform!.name}_${_selectedAccountType!.name}';
      final slot = widget.game.slots[slotKey];
      return slot?.status == SlotStatus.available;
    }

    return false;
  }

  Future<void> _handleBorrowRequest() async {
    if (!canBorrow) return;

    setState(() => _isProcessing = true);

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    try {
      // Simulate borrow request
      await Future.delayed(Duration(seconds: 2));

      // Show success message
      Fluttertoast.showToast(
        msg: isArabic
            ? 'تم طلب الاستعارة بنجاح!'
            : 'Borrow request successful!',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.successColor,
        textColor: Colors.white,
      );

      // Close modal
      Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(
        msg: isArabic
            ? 'حدث خطأ. حاول مرة أخرى.'
            : 'An error occurred. Please try again.',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.errorColor,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final user = authProvider.currentUser;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkBackground : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game Cover & Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover Image
                      Container(
                        width: 120.w,
                        height: 160.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          color: Colors.grey.shade200,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: widget.game.coverImageUrl != null
                              ? CachedNetworkImage(
                            imageUrl: widget.game.coverImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                FontAwesomeIcons.gamepad,
                                size: 40.sp,
                                color: Colors.grey,
                              ),
                            ),
                          )
                              : Center(
                            child: Icon(
                              FontAwesomeIcons.gamepad,
                              size: 40.sp,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      // Game Info
                      Expanded(
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
                            // Category Badge
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(widget.game.lenderTier),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                _getCategoryLabel(widget.game.lenderTier, isArabic),
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            // Contributor
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
                              ],
                            ),
                            SizedBox(height: 8.h),
                            // Value
                            Text(
                              '${widget.game.gameValue.toStringAsFixed(0)} LE',
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  // Platform Selection
                  Text(
                    isArabic ? 'اختر المنصة' : 'Select Platform',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Wrap(
                    spacing: 8.w,
                    children: widget.game.supportedPlatforms.map((platform) {
                      final isSelected = _selectedPlatform == platform;
                      return ChoiceChip(
                        label: Text(platform.displayName),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedPlatform = platform;
                          });
                        },
                        selectedColor: platform == Platform.ps5
                            ? Colors.blue
                            : Colors.indigo,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 20.h),

                  // Account Type Selection
                  Text(
                    isArabic ? 'نوع الحساب' : 'Account Type',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Column(
                    children: widget.game.sharingOptions.map((type) {
                      final isSelected = _selectedAccountType == type;
                      final slotKey = '${_selectedPlatform?.name ?? 'ps5'}_${type.name}';
                      final slot = widget.game.slots[slotKey];
                      final isAvailable = slot?.status == SlotStatus.available;

                      return Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        child: RadioListTile<AccountType>(
                          title: Text(type.displayName),
                          subtitle: Row(
                            children: [
                              Text(
                                '${(widget.game.gameValue * type.borrowMultiplier).toStringAsFixed(0)} LE',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isAvailable
                                      ? AppTheme.successColor.withOpacity(0.1)
                                      : AppTheme.errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  isAvailable
                                      ? (isArabic ? 'متاح' : 'Available')
                                      : (isArabic ? 'غير متاح' : 'Unavailable'),
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: isAvailable
                                        ? AppTheme.successColor
                                        : AppTheme.errorColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          value: type,
                          groupValue: _selectedAccountType,
                          onChanged: isAvailable
                              ? (value) {
                            setState(() {
                              _selectedAccountType = value;
                            });
                          }
                              : null,
                          activeColor: AppTheme.primaryColor,
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 20.h),

                  // Game Statistics
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppTheme.darkSurface
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'إحصائيات اللعبة' : 'Game Statistics',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        _buildStatRow(
                          label: isArabic ? 'إجمالي الاستعارات' : 'Total Borrows',
                          value: '${widget.game.totalBorrows}',
                          icon: FontAwesomeIcons.chartLine,
                        ),
                        _buildStatRow(
                          label: isArabic ? 'الاستعارات الحالية' : 'Current Borrows',
                          value: '${widget.game.currentBorrows}',
                          icon: FontAwesomeIcons.userGroup,
                        ),
                        _buildStatRow(
                          label: isArabic ? 'متوسط مدة الاستعارة' : 'Avg. Borrow Duration',
                          value: '${widget.game.averageBorrowDuration.toStringAsFixed(0)} ${isArabic ? 'يوم' : 'days'}',
                          icon: FontAwesomeIcons.clock,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // User's Borrow Eligibility
                  if (user != null)
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: canBorrow
                            ? AppTheme.successColor.withOpacity(0.1)
                            : AppTheme.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: canBorrow
                              ? AppTheme.successColor
                              : AppTheme.warningColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                canBorrow ? Icons.check_circle : Icons.info,
                                color: canBorrow
                                    ? AppTheme.successColor
                                    : AppTheme.warningColor,
                                size: 20.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                isArabic
                                    ? 'حالة الأهلية'
                                    : 'Eligibility Status',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          // Station Limit Check
                          _buildEligibilityRow(
                            label: isArabic ? 'حد المحطة' : 'Station Limit',
                            value: '${user.remainingStationLimit.toStringAsFixed(0)} / ${borrowValue.toStringAsFixed(0)} LE',
                            passed: user.remainingStationLimit >= borrowValue,
                          ),
                          // Borrow Limit Check
                          _buildEligibilityRow(
                            label: isArabic ? 'حد الاستعارة' : 'Borrow Limit',
                            value: '${user.currentBorrows} / ${user.borrowLimit}',
                            passed: user.currentBorrows < user.borrowLimit,
                          ),
                          // Borrow Window Check
                          _buildEligibilityRow(
                            label: isArabic ? 'نافذة الاستعارة' : 'Borrow Window',
                            value: appProvider.isBorrowWindowCurrentlyOpen()
                                ? (isArabic ? 'مفتوحة' : 'Open')
                                : (isArabic ? 'مغلقة' : 'Closed'),
                            passed: appProvider.isBorrowWindowCurrentlyOpen() || authProvider.isAdmin,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkSurface : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        side: BorderSide(color: AppTheme.primaryColor),
                      ),
                      child: Text(
                        isArabic ? 'إلغاء' : 'Cancel',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // Borrow Button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: canBorrow && !_isProcessing
                          ? _handleBorrowRequest
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: canBorrow ? 4 : 0,
                      ),
                      child: _isProcessing
                          ? SizedBox(
                        height: 20.h,
                        width: 20.w,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        isArabic ? 'طلب الاستعارة' : 'Request Borrow',
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
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isDarkMode = Provider.of<AppProvider>(context, listen: false).isDarkMode;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16.sp,
            color: AppTheme.primaryColor,
          ),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              color: isDarkMode
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityRow({
    required String label,
    required String value,
    required bool passed,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check : Icons.close,
            size: 16.sp,
            color: passed ? AppTheme.successColor : AppTheme.errorColor,
          ),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(fontSize: 14.sp),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: passed ? AppTheme.successColor : AppTheme.errorColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(LenderTier tier) {
    switch (tier) {
      case LenderTier.gamesVault:
        return AppTheme.vipColor;
      case LenderTier.member:
        return AppTheme.memberColor;
      case LenderTier.admin:
        return AppTheme.adminColor;
      default:
        return AppTheme.userColor;
    }
  }

  String _getCategoryLabel(LenderTier tier, bool isArabic) {
    switch (tier) {
      case LenderTier.gamesVault:
        return isArabic ? 'خزينة الألعاب' : 'Games Vault';
      case LenderTier.member:
        return isArabic ? 'ألعاب الأعضاء' : "Members' Games";
      case LenderTier.admin:
        return isArabic ? 'ألعاب الإدارة' : "Admin Games";
      default:
        return isArabic ? 'ألعاب المستخدمين' : "User Games";
    }
  }
}