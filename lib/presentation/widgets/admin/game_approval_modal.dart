import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/user_model.dart';

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

  // Form controllers
  final _gameValueController = TextEditingController();
  final _borrowPriceController = TextEditingController();
  final _notesController = TextEditingController();
  final _expiryDaysController = TextEditingController();

  // Game properties
  String _selectedEdition = 'Standard';
  String _selectedRegion = 'Global';
  LenderTier _selectedLenderTier = LenderTier.member;

  // Slot availability
  bool _ps4PrimaryEnabled = false;
  bool _ps5PrimaryEnabled = false;
  bool _secondaryEnabled = false;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeFromContribution();
  }

  void _initializeFromContribution() {
    // Pre-fill from contribution request
    final data = widget.contributionData;

    // Set edition and region from contribution
    _selectedEdition = data['edition'] ?? 'Standard';
    _selectedRegion = data['region'] ?? 'Global';

    // Determine which slots to enable based on account type
    final accountType = data['accountType'];
    final platform = data['platform'];

    if (accountType == 'psPlus' || accountType == 'full') {
      // PS Plus and Full accounts have all slots
      _ps4PrimaryEnabled = true;
      _ps5PrimaryEnabled = true;
      _secondaryEnabled = true;
    } else if (accountType == 'primary') {
      // Primary account - enable only the relevant platform
      if (platform == 'ps4') {
        _ps4PrimaryEnabled = true;
      } else if (platform == 'ps5') {
        _ps5PrimaryEnabled = true;
      }
    } else if (accountType == 'secondary') {
      // Secondary account
      _secondaryEnabled = true;
    }

    // Set default game value based on account type (can be overridden by admin)
    double defaultValue = 100;
    if (accountType == 'secondary') defaultValue = 75;
    if (accountType == 'full') defaultValue = 150;
    if (accountType == 'psPlus') defaultValue = 200;

    _gameValueController.text = defaultValue.toStringAsFixed(0);
    _borrowPriceController.text = defaultValue.toStringAsFixed(0);
  }

  double _calculateStationLimit() {
    final gameValue = double.tryParse(_gameValueController.text) ?? 0;
    final accountType = widget.contributionData['accountType'];

    // Station Limit calculation per BRD
    switch (accountType) {
      case 'primary':
        return gameValue; // 100% of admin-set value
      case 'secondary':
        return gameValue * 0.75; // 75% of admin-set value
      case 'full':
        return gameValue * 1.5; // 150% of admin-set value
      case 'psPlus':
        return gameValue * 2.0; // 200% of admin-set value
      default:
        return gameValue;
    }
  }

  Future<void> _approveGameContribution() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;

    // Validate inputs
    if (_gameValueController.text.isEmpty || _borrowPriceController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: isArabic
            ? 'يرجى إدخال قيمة اللعبة وسعر الاستعارة'
            : 'Please enter game value and borrow price',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final data = widget.contributionData;
      final gameValue = double.parse(_gameValueController.text);
      final borrowPrice = double.parse(_borrowPriceController.text);
      final stationLimitIncrease = _calculateStationLimit();

      // Create game slots based on enabled options
      final Map<String, dynamic> slots = {};

      if (_ps4PrimaryEnabled) {
        slots['ps4_primary'] = {
          'platform': 'ps4',
          'accountType': 'primary',
          'status': 'available',
          'email': data['accountEmail'],
          'password': data['accountPassword'],
        };
      }

      if (_ps5PrimaryEnabled) {
        slots['ps5_primary'] = {
          'platform': 'ps5',
          'accountType': 'primary',
          'status': 'available',
          'email': data['accountEmail'],
          'password': data['accountPassword'],
        };
      }

      if (_secondaryEnabled) {
        slots['secondary'] = {
          'platform': data['platform'] ?? 'ps4',
          'accountType': 'secondary',
          'status': 'available',
          'email': data['accountEmail'],
          'password': data['accountPassword'],
        };
      }

      // Check if game already exists
      final existingGames = await _firestore
          .collection('games')
          .where('title', isEqualTo: data['gameTitle'])
          .limit(1)
          .get();

      String gameId;

      if (existingGames.docs.isNotEmpty) {
        // Update existing game with new slots
        gameId = existingGames.docs.first.id;

        await _firestore.collection('games').doc(gameId).update({
          'slots': FieldValue.arrayUnion([slots]),
          'contributors': FieldValue.arrayUnion([{
            'userId': data['contributorId'],
            'userName': data['contributorName'],
            'contributedAt': DateTime.now().toIso8601String(),
            'sharePercentage': 0, // Will be recalculated
          }]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new game
        final gameDoc = {
          'title': data['gameTitle'],
          'description': data['description'] ?? '',
          'gameValue': gameValue,
          'borrowPrice': borrowPrice,
          'edition': _selectedEdition,
          'region': _selectedRegion,
          'lenderTier': _selectedLenderTier.name,
          'slots': slots,
          'supportedPlatforms': _getSupportedPlatforms(),
          'sharingOptions': _getSharingOptions(),
          'contributors': [{
            'userId': data['contributorId'],
            'userName': data['contributorName'],
            'contributedAt': DateTime.now().toIso8601String(),
            'sharePercentage': 100,
          }],
          'isActive': true,
          'totalCost': 0,
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

        final docRef = await _firestore.collection('games').add(gameDoc);
        gameId = docRef.id;
      }

      // Update user's station limit
      await _firestore.collection('users').doc(data['contributorId']).update({
        'stationLimit': FieldValue.increment(stationLimitIncrease),
        'remainingStationLimit': FieldValue.increment(stationLimitIncrease),
        'gameShares': FieldValue.increment(1),
        'totalShares': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Check for VIP promotion
      final userDoc = await _firestore.collection('users').doc(data['contributorId']).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['totalShares'] >= 15 && userData['fundShares'] >= 5 && userData['tier'] == 'member') {
        await _firestore.collection('users').doc(data['contributorId']).update({
          'tier': 'vip',
        });
      }

      // Update contribution request status
      await _firestore.collection('contribution_requests').doc(widget.requestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin', // Get from auth provider
        'gameId': gameId,
        'gameValue': gameValue,
        'borrowPrice': borrowPrice,
        'stationLimitIncrease': stationLimitIncrease,
        'adminNotes': _notesController.text,
      });

      Fluttertoast.showToast(
        msg: isArabic
            ? 'تمت الموافقة على مساهمة اللعبة'
            : 'Game contribution approved successfully',
        backgroundColor: AppTheme.successColor,
      );

      widget.onApproved();
    } catch (e) {
      print('Error approving game: $e');
      Fluttertoast.showToast(
        msg: isArabic
            ? 'حدث خطأ في الموافقة'
            : 'Error approving contribution',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  List<String> _getSupportedPlatforms() {
    final platforms = <String>[];
    if (_ps4PrimaryEnabled || _secondaryEnabled) platforms.add('ps4');
    if (_ps5PrimaryEnabled || _secondaryEnabled) platforms.add('ps5');
    return platforms;
  }

  List<String> _getSharingOptions() {
    final options = <String>[];
    if (_ps4PrimaryEnabled || _ps5PrimaryEnabled) options.add('primary');
    if (_secondaryEnabled) options.add('secondary');
    if (widget.contributionData['accountType'] == 'full') options.add('full');
    if (widget.contributionData['accountType'] == 'psPlus') options.add('psPlus');
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    final data = widget.contributionData;
    final stationLimit = _calculateStationLimit();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Container(
        width: 400.w,
        constraints: BoxConstraints(maxHeight: 600.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
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
                      isArabic ? 'موافقة على مساهمة اللعبة' : 'Approve Game Contribution',
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
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Game Title
                    Text(
                      data['gameTitle'] ?? 'Unknown Game',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 8.h),

                    // Contributor Info
                    Row(
                      children: [
                        Icon(Icons.person, size: 16.sp, color: AppTheme.primaryColor),
                        SizedBox(width: 4.w),
                        Text(
                          '${data['contributorName']} • ${data['accountType']?.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: isDarkMode
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20.h),

                    // Value Settings
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _gameValueController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: isArabic ? 'قيمة اللعبة' : 'Game Value',
                              suffixText: 'LE',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: TextField(
                            controller: _borrowPriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: isArabic ? 'سعر الاستعارة' : 'Borrow Price',
                              suffixText: 'LE',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12.h),

                    // Station Limit Display
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
                        children: [
                          Icon(Icons.info_outline, size: 20.sp, color: AppTheme.infoColor),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'زيادة حد المحطة: ${stationLimit.toStringAsFixed(0)} LE'
                                  : 'Station Limit Increase: ${stationLimit.toStringAsFixed(0)} LE',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppTheme.infoColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Edition & Region
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedEdition,
                            decoration: InputDecoration(
                              labelText: isArabic ? 'الإصدار' : 'Edition',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            items: ['Standard', 'Deluxe', 'Ultimate', 'Gold', 'Complete', 'GOTY']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedEdition = value);
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedRegion,
                            decoration: InputDecoration(
                              labelText: isArabic ? 'المنطقة' : 'Region',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            items: ['US', 'EU', 'UK', 'Asia', 'Japan', 'Global']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedRegion = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20.h),

                    // Lender Tier
                    Text(
                      isArabic ? 'فئة المُقرض:' : 'Lender Tier:',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      children: LenderTier.values.map((tier) {
                        final isSelected = _selectedLenderTier == tier;
                        return ChoiceChip(
                          label: Text(tier.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedLenderTier = tier);
                          },
                          selectedColor: _getTierColor(tier),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                          ),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 20.h),

                    // Available Slots
                    Text(
                      isArabic ? 'الفتحات المتاحة:' : 'Available Slots:',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),

                    // Only show relevant slots based on contribution type
                    if (data['accountType'] == 'psPlus' || data['accountType'] == 'full' || data['platform'] == 'ps4' && data['accountType'] == 'primary')
                      CheckboxListTile(
                        title: Text('PS4 Primary'),
                        value: _ps4PrimaryEnabled,
                        onChanged: (value) {
                          setState(() => _ps4PrimaryEnabled = value ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),

                    if (data['accountType'] == 'psPlus' || data['accountType'] == 'full' || data['platform'] == 'ps5' && data['accountType'] == 'primary')
                      CheckboxListTile(
                        title: Text('PS5 Primary'),
                        value: _ps5PrimaryEnabled,
                        onChanged: (value) {
                          setState(() => _ps5PrimaryEnabled = value ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),

                    if (data['accountType'] == 'psPlus' || data['accountType'] == 'full' || data['accountType'] == 'secondary')
                      CheckboxListTile(
                        title: Text('Secondary'),
                        value: _secondaryEnabled,
                        onChanged: (value) {
                          setState(() => _secondaryEnabled = value ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),

                    SizedBox(height: 20.h),

                    // Admin Notes
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'ملاحظات المسؤول' : 'Admin Notes',
                        hintText: isArabic ? 'اختياري' : 'Optional',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDarkMode
                        ? AppTheme.darkSurface
                        : Colors.grey[300]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : () => Navigator.pop(context),
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
                      onPressed: _isProcessing ? null : _approveGameContribution,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: _isProcessing
                          ? SizedBox(
                        height: 20.h,
                        width: 20.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Text(
                        isArabic ? 'موافقة' : 'Approve',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

  Color _getTierColor(LenderTier tier) {
    switch (tier) {
      case LenderTier.gamesVault:
        return Colors.green;
      case LenderTier.member:
        return AppTheme.primaryColor;
      case LenderTier.nonMember:
        return Colors.orange;
      case LenderTier.admin:
        return Colors.red;
    }
  }

  @override
  void dispose() {
    _gameValueController.dispose();
    _borrowPriceController.dispose();
    _notesController.dispose();
    _expiryDaysController.dispose();
    super.dispose();
  }
}