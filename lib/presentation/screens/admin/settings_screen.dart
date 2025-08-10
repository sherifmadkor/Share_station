// lib/presentation/screens/admin/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

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

  // Settings Controllers
  final TextEditingController _membershipFeeController = TextEditingController();
  final TextEditingController _clientFeeController = TextEditingController();
  final TextEditingController _vipWithdrawalFeeController = TextEditingController();
  final TextEditingController _adminFeeController = TextEditingController();
  final TextEditingController _pointsConversionController = TextEditingController();
  final TextEditingController _balanceExpiryController = TextEditingController();
  final TextEditingController _suspensionPeriodController = TextEditingController();

  bool _isLoading = false;
  bool _hasUnsavedChanges = false;

  // System Settings
  Map<String, dynamic> _systemSettings = {
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
    _loadSettings();
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

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final settingsDoc = await _firestore
          .collection('settings')
          .doc('system')
          .get();

      if (settingsDoc.exists) {
        _systemSettings = settingsDoc.data()!;
      }

      // Update controllers
      _membershipFeeController.text = _systemSettings['membershipFee'].toString();
      _clientFeeController.text = _systemSettings['clientFee'].toString();
      _vipWithdrawalFeeController.text = _systemSettings['vipWithdrawalFeePercentage'].toString();
      _adminFeeController.text = _systemSettings['adminFeePercentage'].toString();
      _pointsConversionController.text = _systemSettings['pointsConversionRate'].toString();
      _balanceExpiryController.text = _systemSettings['balanceExpiryDays'].toString();
      _suspensionPeriodController.text = _systemSettings['suspensionPeriodDays'].toString();

    } catch (e) {
      print('Error loading settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    final appProvider = context.read<AppProvider>();
    final isArabic = appProvider.isArabic;

    setState(() => _isLoading = true);

    try {
      // Update settings with new values
      _systemSettings['membershipFee'] = int.tryParse(_membershipFeeController.text) ?? 1500;
      _systemSettings['clientFee'] = int.tryParse(_clientFeeController.text) ?? 750;
      _systemSettings['vipWithdrawalFeePercentage'] = int.tryParse(_vipWithdrawalFeeController.text) ?? 20;
      _systemSettings['adminFeePercentage'] = int.tryParse(_adminFeeController.text) ?? 10;
      _systemSettings['pointsConversionRate'] = int.tryParse(_pointsConversionController.text) ?? 25;
      _systemSettings['balanceExpiryDays'] = int.tryParse(_balanceExpiryController.text) ?? 90;
      _systemSettings['suspensionPeriodDays'] = int.tryParse(_suspensionPeriodController.text) ?? 180;
      _systemSettings['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('settings')
          .doc('system')
          .set(_systemSettings, SetOptions(merge: true));

      setState(() => _hasUnsavedChanges = false);

      Fluttertoast.showToast(
        msg: isArabic ? 'تم حفظ الإعدادات بنجاح' : 'Settings saved successfully',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: isArabic ? 'خطأ في حفظ الإعدادات' : 'Error saving settings',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges) {
          final shouldPop = await _showUnsavedChangesDialog(isArabic);
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
        appBar: AppBar(
          title: Text(
            isArabic ? 'الإعدادات' : 'Settings',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          actions: [
            if (_hasUnsavedChanges)
              TextButton.icon(
                onPressed: _saveSettings,
                icon: Icon(Icons.save, color: Colors.white),
                label: Text(
                  isArabic ? 'حفظ' : 'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System Controls
              _buildSectionTitle(
                title: isArabic ? 'التحكم في النظام' : 'System Controls',
                icon: Icons.settings_applications,
              ),
              SizedBox(height: 12.h),

              _buildSwitchTile(
                title: isArabic ? 'نافذة الاستعارة' : 'Borrow Window',
                subtitle: isArabic
                    ? 'السماح بطلبات الاستعارة الجديدة'
                    : 'Allow new borrow requests',
                value: _systemSettings['isBorrowWindowOpen'] ?? true,
                onChanged: (value) {
                  setState(() {
                    _systemSettings['isBorrowWindowOpen'] = value;
                    _hasUnsavedChanges = true;
                  });
                },
                icon: Icons.schedule,
                isDarkMode: isDarkMode,
              ),

              _buildSwitchTile(
                title: isArabic ? 'التسجيلات الجديدة' : 'New Registrations',
                subtitle: isArabic
                    ? 'السماح بالتسجيلات الجديدة'
                    : 'Allow new user registrations',
                value: _systemSettings['allowNewRegistrations'] ?? true,
                onChanged: (value) {
                  setState(() {
                    _systemSettings['allowNewRegistrations'] = value;
                    _hasUnsavedChanges = true;
                  });
                },
                icon: Icons.person_add,
                isDarkMode: isDarkMode,
              ),

              _buildSwitchTile(
                title: isArabic ? 'وضع الصيانة' : 'Maintenance Mode',
                subtitle: isArabic
                    ? 'تعطيل التطبيق للصيانة'
                    : 'Disable app for maintenance',
                value: _systemSettings['maintenanceMode'] ?? false,
                onChanged: (value) {
                  setState(() {
                    _systemSettings['maintenanceMode'] = value;
                    _hasUnsavedChanges = true;
                  });
                },
                icon: Icons.build,
                isDarkMode: isDarkMode,
                warningMode: true,
              ),

              SizedBox(height: 24.h),

              // Fee Settings
              _buildSectionTitle(
                title: isArabic ? 'إعدادات الرسوم' : 'Fee Settings',
                icon: FontAwesomeIcons.moneyBill,
              ),
              SizedBox(height: 12.h),

              _buildNumberInput(
                controller: _membershipFeeController,
                label: isArabic ? 'رسوم العضوية' : 'Membership Fee',
                suffix: 'LE',
                icon: Icons.card_membership,
                isDarkMode: isDarkMode,
                onChanged: () => setState(() => _hasUnsavedChanges = true),
              ),

              _buildNumberInput(
                controller: _clientFeeController,
                label: isArabic ? 'رسوم العميل' : 'Client Fee',
                suffix: 'LE',
                icon: Icons.person_outline,
                isDarkMode: isDarkMode,
                onChanged: () => setState(() => _hasUnsavedChanges = true),
              ),

              _buildNumberInput(
                controller: _vipWithdrawalFeeController,
                label: isArabic ? 'رسوم سحب VIP' : 'VIP Withdrawal Fee',
                suffix: '%',
                icon: FontAwesomeIcons.crown,
                isDarkMode: isDarkMode,
                onChanged: () => setState(() => _hasUnsavedChanges = true),
              ),

              _buildNumberInput(
                controller: _adminFeeController,
                label: isArabic ? 'رسوم الإدارة' : 'Admin Fee',
                suffix: '%',
                icon: Icons.admin_panel_settings,
                isDarkMode: isDarkMode,
                onChanged: () => setState(() => _hasUnsavedChanges = true),
              ),

              SizedBox(height: 24.h),

              // System Parameters
              _buildSectionTitle(
                title: isArabic ? 'معاملات النظام' : 'System Parameters',
                icon: Icons.tune,
              ),
              SizedBox(height: 12.h),

              _buildNumberInput(
                controller: _pointsConversionController,
                label: isArabic ? 'معدل تحويل النقاط' : 'Points Conversion Rate',
                suffix: isArabic ? 'نقطة = 1 LE' : 'points = 1 LE',
                icon: FontAwesomeIcons.coins,
                isDarkMode: isDarkMode,
                onChanged: () => setState(() => _hasUnsavedChanges = true),
              ),

              _buildNumberInput(
                controller: _balanceExpiryController,
                label: isArabic ? 'مدة انتهاء الرصيد' : 'Balance Expiry Period',
                suffix: isArabic ? 'يوم' : 'days',
                icon: Icons.timer,
                isDarkMode: isDarkMode,
                onChanged: () => setState(() => _hasUnsavedChanges = true),
              ),

              _buildNumberInput(
                controller: _suspensionPeriodController,
                label: isArabic ? 'فترة التعليق' : 'Suspension Period',
                suffix: isArabic ? 'يوم' : 'days',
                icon: Icons.person_off,
                isDarkMode: isDarkMode,
                onChanged: () => setState(() => _hasUnsavedChanges = true),
              ),

              SizedBox(height: 24.h),

              // Borrow Window Day
              _buildSectionTitle(
                title: isArabic ? 'يوم نافذة الاستعارة' : 'Borrow Window Day',
                icon: Icons.calendar_today,
              ),
              SizedBox(height: 12.h),

              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic
                          ? 'اختر اليوم الذي يُسمح فيه بالاستعارة'
                          : 'Select the day when borrowing is allowed',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDarkMode ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      value: _systemSettings['borrowWindowDay'] ?? 'thursday',
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? AppTheme.darkBackground
                            : Colors.grey[50],
                      ),
                      items: [
                        'monday', 'tuesday', 'wednesday', 'thursday',
                        'friday', 'saturday', 'sunday'
                      ].map((day) {
                        return DropdownMenuItem(
                          value: day,
                          child: Text(_getDayName(day, isArabic)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _systemSettings['borrowWindowDay'] = value;
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32.h),

              // Save Button
              if (_hasUnsavedChanges)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: Icon(Icons.save),
                    label: Text(
                      isArabic ? 'حفظ التغييرات' : 'Save Changes',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20.sp, color: AppTheme.primaryColor),
        SizedBox(width: 8.w),
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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
    required bool isDarkMode,
    bool warningMode = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: warningMode && value
            ? Border.all(color: AppTheme.errorColor, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: (warningMode && value
                  ? AppTheme.errorColor
                  : AppTheme.primaryColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              icon,
              color: warningMode && value
                  ? AppTheme.errorColor
                  : AppTheme.primaryColor,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
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
            activeColor: warningMode ? AppTheme.errorColor : AppTheme.primaryColor,
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
    required VoidCallback onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20.sp),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          filled: true,
                          fillColor: isDarkMode
                              ? AppTheme.darkBackground
                              : Colors.grey[50],
                        ),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      suffix,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(String day, bool isArabic) {
    final days = {
      'monday': isArabic ? 'الإثنين' : 'Monday',
      'tuesday': isArabic ? 'الثلاثاء' : 'Tuesday',
      'wednesday': isArabic ? 'الأربعاء' : 'Wednesday',
      'thursday': isArabic ? 'الخميس' : 'Thursday',
      'friday': isArabic ? 'الجمعة' : 'Friday',
      'saturday': isArabic ? 'السبت' : 'Saturday',
      'sunday': isArabic ? 'الأحد' : 'Sunday',
    };
    return days[day] ?? day;
  }

  Future<bool?> _showUnsavedChangesDialog(bool isArabic) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isArabic ? 'تغييرات غير محفوظة' : 'Unsaved Changes',
        ),
        content: Text(
          isArabic
              ? 'لديك تغييرات غير محفوظة. هل تريد حفظها أولاً؟'
              : 'You have unsaved changes. Do you want to save them first?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isArabic ? 'تجاهل' : 'Discard',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveSettings();
              Navigator.pop(context, true);
            },
            child: Text(isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }
}