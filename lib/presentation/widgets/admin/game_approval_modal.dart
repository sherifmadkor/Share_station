import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_model.dart' hide Platform;
import '../../../data/models/user_model.dart' as user_model;

// Create Platform enum alias to avoid conflicts
typedef GamePlatform = user_model.Platform;

class GameApprovalModal extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> contributionData;
  final VoidCallback onApproved;

  const GameApprovalModal({
    Key? key,
    required this.requestId,
    required this.contributionData,
    required this.onApproved,
  }) : super(key: key);

  @override
  State<GameApprovalModal> createState() => _GameApprovalModalState();
}

class _GameApprovalModalState extends State<GameApprovalModal> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form fields
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _valueController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Selected options
  GamePlatform? _selectedPlatform;
  AccountType? _selectedAccountType;
  String _selectedRegion = 'Global';
  String _selectedEdition = 'Standard';
  bool _isProcessing = false;

  // Platform options
  final List<GamePlatform> _platforms = [
    GamePlatform.ps4,
    GamePlatform.ps5,
  ];

  // Account type options
  final List<AccountType> _accountTypes = [
    AccountType.primary,
    AccountType.secondary,
    AccountType.full,
    AccountType.psPlus,
  ];

  // Region options
  final List<String> _regions = [
    'Global',
    'US',
    'Europe',
    'Asia',
    'Middle East',
  ];

  // Edition options
  final List<String> _editions = [
    'Standard',
    'Deluxe',
    'Gold',
    'Ultimate',
    'Collector\'s',
  ];

  @override
  void initState() {
    super.initState();
    _initializeFormData();
  }

  void _initializeFormData() {
    // Pre-fill form with contribution data
    _titleController.text = widget.contributionData['gameTitle'] ?? '';
    _valueController.text = widget.contributionData['gameValue']?.toString() ?? '0';
    _emailController.text = widget.contributionData['email'] ?? '';
    _passwordController.text = widget.contributionData['password'] ?? '';
    _descriptionController.text = widget.contributionData['description'] ?? '';

    // Set platform from contribution data
    final platformString = widget.contributionData['platform']?.toString().toLowerCase();
    if (platformString != null) {
      try {
        _selectedPlatform = GamePlatform.values.firstWhere(
              (p) => p.name.toLowerCase() == platformString,
          orElse: () => GamePlatform.ps5,
        );
      } catch (e) {
        _selectedPlatform = GamePlatform.ps5;
      }
    } else {
      _selectedPlatform = GamePlatform.ps5;
    }

    // Set account type from contribution data
    final accountTypeString = widget.contributionData['accountType']?.toString().toLowerCase();
    if (accountTypeString != null) {
      try {
        _selectedAccountType = AccountType.values.firstWhere(
              (a) => a.name.toLowerCase() == accountTypeString,
          orElse: () => AccountType.primary,
        );
      } catch (e) {
        _selectedAccountType = AccountType.primary;
      }
    } else {
      _selectedAccountType = AccountType.primary;
    }

    _selectedRegion = widget.contributionData['region'] ?? 'Global';
    _selectedEdition = widget.contributionData['edition'] ?? 'Standard';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _valueController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _approveGameContribution() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlatform == null || _selectedAccountType == null) {
      _showErrorMessage('Please select platform and account type');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Create slots based on platform and account type
      Map<String, dynamic> slots = {};
      final slotKey = '${_selectedPlatform!.name}_${_selectedAccountType!.name}';
      slots[slotKey] = {
        'platform': _selectedPlatform!.name,
        'accountType': _selectedAccountType!.name,
        'status': 'available',
        'borrowerId': null,
        'borrowDate': null,
        'expectedReturnDate': null,
        'reservationDate': null,
        'reservedById': null,
      };

      // Prepare game document
      final gameDoc = {
        'title': _titleController.text.trim(),
        'includedTitles': [_titleController.text.trim()],
        'coverImageUrl': widget.contributionData['coverImageUrl'],
        'description': _descriptionController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'edition': _selectedEdition,
        'region': _selectedRegion,
        'contributorId': widget.contributionData['contributorId'],
        'contributorName': widget.contributionData['contributorName'],
        'lenderTier': 'member', // Default to member tier
        'dateAdded': FieldValue.serverTimestamp(),
        'isActive': true,
        'supportedPlatforms': [_selectedPlatform!.name],
        'sharingOptions': [_selectedAccountType!.name],
        'slots': slots,
        'gameValue': double.tryParse(_valueController.text) ?? 0,
        'totalCost': double.tryParse(_valueController.text) ?? 0,
        'totalRevenues': 0,
        'borrowRevenue': 0,
        'sellRevenue': 0,
        'fundShareRevenue': 0,
        'totalBorrows': 0,
        'currentBorrows': 0,
        'averageBorrowDuration': 0,
        'borrowHistory': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add game to Firestore
      await _firestore.collection('games').add(gameDoc);

      // Update contribution request status
      await _firestore
          .collection('contribution_requests')
          .doc(widget.requestId)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin', // Should get from auth provider
      });

      // Update contributor's statistics
      final contributorId = widget.contributionData['contributorId'];
      if (contributorId != null) {
        final gameValue = double.tryParse(_valueController.text) ?? 0;
        await _firestore.collection('users').doc(contributorId).update({
          'gameShares': FieldValue.increment(1),
          'totalShares': FieldValue.increment(1),
          'stationLimit': FieldValue.increment(gameValue),
          'remainingStationLimit': FieldValue.increment(gameValue),
          'balance': FieldValue.increment(gameValue * 0.7), // 70% to balance
          'lastActivityDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Show success message
      _showSuccessMessage('Game approved successfully!');

      // Call callback and close modal
      widget.onApproved();
    } catch (e) {
      print('Error approving game: $e');
      _showErrorMessage('Failed to approve game: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSuccessMessage(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppTheme.successColor,
      textColor: Colors.white,
    );
  }

  void _showErrorMessage(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppTheme.errorColor,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16.r),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    FontAwesomeIcons.gamepad,
                    color: Colors.white,
                    size: 24.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      isArabic ? 'الموافقة على اللعبة' : 'Approve Game',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Game Title
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'عنوان اللعبة' : 'Game Title',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          prefixIcon: Icon(Icons.videogame_asset),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return isArabic
                                ? 'الرجاء إدخال عنوان اللعبة'
                                : 'Please enter game title';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),

                      // Game Value
                      TextFormField(
                        controller: _valueController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'قيمة اللعبة (LE)' : 'Game Value (LE)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return isArabic
                                ? 'الرجاء إدخال قيمة اللعبة'
                                : 'Please enter game value';
                          }
                          if (double.tryParse(value) == null) {
                            return isArabic
                                ? 'الرجاء إدخال رقم صحيح'
                                : 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),

                      // Platform Selection
                      Text(
                        isArabic ? 'المنصة' : 'Platform',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<GamePlatform>(
                            value: _selectedPlatform,
                            isExpanded: true,
                            hint: Text(isArabic ? 'اختر المنصة' : 'Select Platform'),
                            items: _platforms.map((platform) {
                              return DropdownMenuItem(
                                value: platform,
                                child: Text(platform.displayName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedPlatform = value;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Account Type Selection
                      Text(
                        isArabic ? 'نوع الحساب' : 'Account Type',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AccountType>(
                            value: _selectedAccountType,
                            isExpanded: true,
                            hint: Text(isArabic ? 'اختر نوع الحساب' : 'Select Account Type'),
                            items: _accountTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type.displayName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedAccountType = value;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Region Selection
                      Text(
                        isArabic ? 'المنطقة' : 'Region',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRegion,
                            isExpanded: true,
                            items: _regions.map((region) {
                              return DropdownMenuItem(
                                value: region,
                                child: Text(region),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedRegion = value!;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Edition Selection
                      Text(
                        isArabic ? 'الإصدار' : 'Edition',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedEdition,
                            isExpanded: true,
                            items: _editions.map((edition) {
                              return DropdownMenuItem(
                                value: edition,
                                child: Text(edition),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedEdition = value!;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'البريد الإلكتروني للحساب' : 'Account Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'كلمة المرور' : 'Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'الوصف' : 'Description',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkSurface : Colors.grey[50],
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16.r),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : _approveGameContribution,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: _isProcessing
                          ? SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                          : Text(
                        isArabic ? 'موافقة' : 'Approve',
                        style: TextStyle(color: Colors.white),
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
}