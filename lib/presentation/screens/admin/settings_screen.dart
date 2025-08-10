// lib/presentation/screens/admin/settings_screen.dart - FIXED VERSION

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _hasUnsavedChanges = false;

  // Controllers with DEFAULT VALUES
  late TextEditingController _membershipFeeController;
  late TextEditingController _clientFeeController;
  late TextEditingController _vipWithdrawalFeeController;
  late TextEditingController _adminFeeController;
  late TextEditingController _pointsConversionController;
  late TextEditingController _balanceExpiryController;
  late TextEditingController _suspensionPeriodController;

  // System Controls
  bool _isBorrowWindowOpen = true;
  bool _allowNewRegistrations = true;
  bool _maintenanceMode = false;
  String _borrowWindowDay = 'thursday';

  // Default values
  static const Map<String, dynamic> DEFAULT_SETTINGS = {
    'membershipFee': 1500,
    'clientFee': 750,
    'vipWithdrawalFeePercentage': 20,
    'adminFeePercentage': 10,
    'pointsConversionRate': 25,
    'balanceExpiryDays': 90,
    'suspensionPeriodDays': 180,
    'borrowWindowDay': 'thursday',
    'isBorrowWindowOpen': true,
    'allowNewRegistrations': true,
    'maintenanceMode': false,
  };

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadSettings();
  }

  void _initializeControllers() {
    // Initialize with default values
    _membershipFeeController = TextEditingController(text: DEFAULT_SETTINGS['membershipFee'].toString());
    _clientFeeController = TextEditingController(text: DEFAULT_SETTINGS['clientFee'].toString());
    _vipWithdrawalFeeController = TextEditingController(text: DEFAULT_SETTINGS['vipWithdrawalFeePercentage'].toString());
    _adminFeeController = TextEditingController(text: DEFAULT_SETTINGS['adminFeePercentage'].toString());
    _pointsConversionController = TextEditingController(text: DEFAULT_SETTINGS['pointsConversionRate'].toString());
    _balanceExpiryController = TextEditingController(text: DEFAULT_SETTINGS['balanceExpiryDays'].toString());
    _suspensionPeriodController = TextEditingController(text: DEFAULT_SETTINGS['suspensionPeriodDays'].toString());

    // Add listeners to detect changes
    _membershipFeeController.addListener(_onSettingChanged);
    _clientFeeController.addListener(_onSettingChanged);
    _vipWithdrawalFeeController.addListener(_onSettingChanged);
    _adminFeeController.addListener(_onSettingChanged);
    _pointsConversionController.addListener(_onSettingChanged);
    _balanceExpiryController.addListener(_onSettingChanged);
    _suspensionPeriodController.addListener(_onSettingChanged);
  }

  void _onSettingChanged() {
    if (mounted) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final doc = await _firestore
          .collection('settings')
          .doc('system')
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        // Update controllers with fetched values, fallback to defaults if null
        _membershipFeeController.text = (data['membershipFee'] ?? DEFAULT_SETTINGS['membershipFee']).toString();
        _clientFeeController.text = (data['clientFee'] ?? DEFAULT_SETTINGS['clientFee']).toString();
        _vipWithdrawalFeeController.text = (data['vipWithdrawalFeePercentage'] ?? DEFAULT_SETTINGS['vipWithdrawalFeePercentage']).toString();
        _adminFeeController.text = (data['adminFeePercentage'] ?? DEFAULT_SETTINGS['adminFeePercentage']).toString();
        _pointsConversionController.text = (data['pointsConversionRate'] ?? DEFAULT_SETTINGS['pointsConversionRate']).toString();
        _balanceExpiryController.text = (data['balanceExpiryDays'] ?? DEFAULT_SETTINGS['balanceExpiryDays']).toString();
        _suspensionPeriodController.text = (data['suspensionPeriodDays'] ?? DEFAULT_SETTINGS['suspensionPeriodDays']).toString();

        setState(() {
          _isBorrowWindowOpen = data['isBorrowWindowOpen'] ?? DEFAULT_SETTINGS['isBorrowWindowOpen'];
          _allowNewRegistrations = data['allowNewRegistrations'] ?? DEFAULT_SETTINGS['allowNewRegistrations'];
          _maintenanceMode = data['maintenanceMode'] ?? DEFAULT_SETTINGS['maintenanceMode'];
          _borrowWindowDay = data['borrowWindowDay'] ?? DEFAULT_SETTINGS['borrowWindowDay'];
        });
      } else {
        // Document doesn't exist, create it with default values
        await _initializeSettings();
      }
    } catch (e) {
      print('Error loading settings: $e');
      // Keep default values on error
    } finally {
      setState(() {
        _isLoading = false;
        _hasUnsavedChanges = false;
      });
    }
  }

  Future<void> _initializeSettings() async {
    try {
      await _firestore.collection('settings').doc('system').set({
        ...DEFAULT_SETTINGS,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settings initialized with default values'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      print('Error initializing settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initializing settings'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('settings').doc('system').set({
        'membershipFee': int.parse(_membershipFeeController.text),
        'clientFee': int.parse(_clientFeeController.text),
        'vipWithdrawalFeePercentage': int.parse(_vipWithdrawalFeeController.text),
        'adminFeePercentage': int.parse(_adminFeeController.text),
        'pointsConversionRate': int.parse(_pointsConversionController.text),
        'balanceExpiryDays': int.parse(_balanceExpiryController.text),
        'suspensionPeriodDays': int.parse(_suspensionPeriodController.text),
        'borrowWindowDay': _borrowWindowDay,
        'isBorrowWindowOpen': _isBorrowWindowOpen,
        'allowNewRegistrations': _allowNewRegistrations,
        'maintenanceMode': _maintenanceMode,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _hasUnsavedChanges = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset to Defaults'),
        content: Text('Are you sure you want to reset all settings to their default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
            ),
            child: Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _membershipFeeController.text = DEFAULT_SETTINGS['membershipFee'].toString();
        _clientFeeController.text = DEFAULT_SETTINGS['clientFee'].toString();
        _vipWithdrawalFeeController.text = DEFAULT_SETTINGS['vipWithdrawalFeePercentage'].toString();
        _adminFeeController.text = DEFAULT_SETTINGS['adminFeePercentage'].toString();
        _pointsConversionController.text = DEFAULT_SETTINGS['pointsConversionRate'].toString();
        _balanceExpiryController.text = DEFAULT_SETTINGS['balanceExpiryDays'].toString();
        _suspensionPeriodController.text = DEFAULT_SETTINGS['suspensionPeriodDays'].toString();
        _borrowWindowDay = DEFAULT_SETTINGS['borrowWindowDay'];
        _isBorrowWindowOpen = DEFAULT_SETTINGS['isBorrowWindowOpen'];
        _allowNewRegistrations = DEFAULT_SETTINGS['allowNewRegistrations'];
        _maintenanceMode = DEFAULT_SETTINGS['maintenanceMode'];
        _hasUnsavedChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _membershipFeeController.dispose();
    _clientFeeController.dispose();
    _vipWithdrawalFeeController.dispose();
    _adminFeeController.dispose();
    _pointsConversionController.dispose();
    _balanceExpiryController.dispose();
    _suspensionPeriodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.locale.languageCode == 'ar';
    final isDarkMode = appProvider.isDarkMode;

    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(isArabic ? 'تغييرات غير محفوظة' : 'Unsaved Changes'),
              content: Text(
                isArabic
                    ? 'لديك تغييرات غير محفوظة. هل تريد المغادرة؟'
                    : 'You have unsaved changes. Do you want to leave?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(isArabic ? 'البقاء' : 'Stay'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                  ),
                  child: Text(isArabic ? 'مغادرة' : 'Leave'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isArabic ? 'الإعدادات' : 'Settings',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
            ),
          ),
          centerTitle: true,
          actions: [
            if (_hasUnsavedChanges)
              Container(
                margin: EdgeInsets.only(right: 8.w),
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  isArabic ? 'غير محفوظ' : 'Unsaved',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            IconButton(
              icon: Icon(Icons.restore),
              onPressed: _resetToDefaults,
              tooltip: isArabic ? 'إعادة تعيين' : 'Reset to defaults',
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // System Controls Section
                _buildSectionHeader(
                  title: isArabic ? 'التحكم في النظام' : 'System Controls',
                  icon: Icons.settings_applications,
                  color: AppTheme.primaryColor,
                ),
                SizedBox(height: 12.h),
                _buildSystemControls(isArabic, isDarkMode),

                SizedBox(height: 24.h),

                // Fee Settings Section
                _buildSectionHeader(
                  title: isArabic ? 'إعدادات الرسوم' : 'Fee Settings',
                  icon: FontAwesomeIcons.dollarSign,
                  color: Colors.green,
                ),
                SizedBox(height: 12.h),
                _buildFeeSettings(isArabic, isDarkMode),

                SizedBox(height: 24.h),

                // System Parameters Section
                _buildSectionHeader(
                  title: isArabic ? 'معايير النظام' : 'System Parameters',
                  icon: Icons.tune,
                  color: Colors.orange,
                ),
                SizedBox(height: 12.h),
                _buildSystemParameters(isArabic, isDarkMode),

                SizedBox(height: 24.h),

                // Borrow Window Day
                _buildBorrowWindowDaySelector(isArabic, isDarkMode),

                SizedBox(height: 32.h),

                // Save Button
                ElevatedButton(
                  onPressed: _hasUnsavedChanges ? _saveSettings : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: Size(double.infinity, 48.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    isArabic ? 'حفظ الإعدادات' : 'Save Settings',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, color: color, size: 20.sp),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemControls(bool isArabic, bool isDarkMode) {
    return Column(
      children: [
        _buildSwitchTile(
          title: isArabic ? 'نافذة الاستعارة' : 'Borrow Window',
          subtitle: isArabic
              ? 'السماح للأعضاء بتقديم طلبات الاستعارة'
              : 'Allow members to submit borrow requests',
          value: _isBorrowWindowOpen,
          onChanged: (value) {
            setState(() {
              _isBorrowWindowOpen = value;
              _hasUnsavedChanges = true;
            });
          },
          icon: Icons.lock_open,
          activeColor: AppTheme.successColor,
          isDarkMode: isDarkMode,
        ),
        SizedBox(height: 12.h),
        _buildSwitchTile(
          title: isArabic ? 'التسجيلات الجديدة' : 'New Registrations',
          subtitle: isArabic
              ? 'السماح بتسجيل مستخدمين جدد'
              : 'Allow new user registrations',
          value: _allowNewRegistrations,
          onChanged: (value) {
            setState(() {
              _allowNewRegistrations = value;
              _hasUnsavedChanges = true;
            });
          },
          icon: Icons.person_add,
          activeColor: AppTheme.primaryColor,
          isDarkMode: isDarkMode,
        ),
        SizedBox(height: 12.h),
        _buildSwitchTile(
          title: isArabic ? 'وضع الصيانة' : 'Maintenance Mode',
          subtitle: isArabic
              ? 'تعطيل التطبيق مؤقتاً للصيانة'
              : 'Temporarily disable app for maintenance',
          value: _maintenanceMode,
          onChanged: (value) {
            setState(() {
              _maintenanceMode = value;
              _hasUnsavedChanges = true;
            });
          },
          icon: Icons.build,
          activeColor: AppTheme.warningColor,
          isDarkMode: isDarkMode,
          showWarning: _maintenanceMode,
        ),
      ],
    );
  }

  Widget _buildFeeSettings(bool isArabic, bool isDarkMode) {
    return Column(
      children: [
        _buildNumberInput(
          controller: _membershipFeeController,
          label: isArabic ? 'رسوم العضوية' : 'Membership Fee',
          suffix: isArabic ? 'ج.م' : 'LE',
          icon: Icons.card_membership,
          isDarkMode: isDarkMode,
        ),
        SizedBox(height: 12.h),
        _buildNumberInput(
          controller: _clientFeeController,
          label: isArabic ? 'رسوم العميل' : 'Client Fee',
          suffix: isArabic ? 'ج.م' : 'LE',
          icon: Icons.person,
          isDarkMode: isDarkMode,
        ),
        SizedBox(height: 12.h),
        _buildNumberInput(
          controller: _vipWithdrawalFeeController,
          label: isArabic ? 'رسوم سحب VIP' : 'VIP Withdrawal Fee',
          suffix: '%',
          icon: FontAwesomeIcons.crown,
          isDarkMode: isDarkMode,
        ),
        SizedBox(height: 12.h),
        _buildNumberInput(
          controller: _adminFeeController,
          label: isArabic ? 'رسوم الإدارة' : 'Admin Fee',
          suffix: '%',
          icon: Icons.admin_panel_settings,
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  Widget _buildSystemParameters(bool isArabic, bool isDarkMode) {
    return Column(
      children: [
        _buildNumberInput(
          controller: _pointsConversionController,
          label: isArabic ? 'معدل تحويل النقاط' : 'Points Conversion Rate',
          suffix: isArabic ? 'نقطة = 1 ج.م' : 'points = 1 LE',
          icon: FontAwesomeIcons.coins,
          isDarkMode: isDarkMode,
        ),
        SizedBox(height: 12.h),
        _buildNumberInput(
          controller: _balanceExpiryController,
          label: isArabic ? 'فترة انتهاء الرصيد' : 'Balance Expiry Period',
          suffix: isArabic ? 'يوم' : 'days',
          icon: Icons.timer,
          isDarkMode: isDarkMode,
        ),
        SizedBox(height: 12.h),
        _buildNumberInput(
          controller: _suspensionPeriodController,
          label: isArabic ? 'فترة التعليق' : 'Suspension Period',
          suffix: isArabic ? 'يوم' : 'days',
          icon: Icons.person_off,
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
    required Color activeColor,
    required bool isDarkMode,
    bool showWarning = false,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: showWarning ? AppTheme.warningColor : Colors.transparent,
          width: showWarning ? 2 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: activeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: activeColor, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInput({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required IconData icon,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon on the far left
          Icon(icon, color: AppTheme.primaryColor, size: 20.sp),
          SizedBox(width: 16.w),

          // Label takes up the available space on the left
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Group the input field and its suffix on the right
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 80.w, // Give the input field a consistent width
                child: TextFormField(
                  controller: controller,
                  textAlign: TextAlign.right, // Align numbers to the right
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    // Remove zero padding to let the field breathe
                    contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                suffix,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowWindowDaySelector(bool isArabic, bool isDarkMode) {
    final days = {
      'sunday': isArabic ? 'الأحد' : 'Sunday',
      'monday': isArabic ? 'الإثنين' : 'Monday',
      'tuesday': isArabic ? 'الثلاثاء' : 'Tuesday',
      'wednesday': isArabic ? 'الأربعاء' : 'Wednesday',
      'thursday': isArabic ? 'الخميس' : 'Thursday',
      'friday': isArabic ? 'الجمعة' : 'Friday',
      'saturday': isArabic ? 'السبت' : 'Saturday',
    };

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 20.sp),
              SizedBox(width: 12.w),
              Text(
                isArabic ? 'يوم نافذة الاستعارة' : 'Borrow Window Day',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          DropdownButtonFormField<String>(
            value: _borrowWindowDay,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            items: days.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _borrowWindowDay = value!;
                _hasUnsavedChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }
}