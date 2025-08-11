// lib/presentation/screens/user/account_information_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class AccountInformationScreen extends StatefulWidget {
  const AccountInformationScreen({Key? key}) : super(key: key);

  @override
  State<AccountInformationScreen> createState() => _AccountInformationScreenState();
}

class _AccountInformationScreenState extends State<AccountInformationScreen> {
  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          isArabic ? 'معلومات الحساب' : 'Account Information',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: user == null
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                Map<String, dynamic> userData = {};
                if (snapshot.hasData && snapshot.data!.exists) {
                  userData = snapshot.data!.data() as Map<String, dynamic>;
                }

                return SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information Card
                      _buildInfoCard(
                        title: isArabic ? 'المعلومات الأساسية' : 'Basic Information',
                        icon: Icons.person,
                        children: [
                          _buildInfoRow(
                            label: isArabic ? 'الاسم' : 'Name',
                            value: user.name ?? 'N/A',
                          ),
                          _buildInfoRow(
                            label: isArabic ? 'البريد الإلكتروني' : 'Email',
                            value: user.email ?? 'N/A',
                          ),
                          _buildInfoRow(
                            label: isArabic ? 'رقم العضوية' : 'Member ID',
                            value: userData['memberId'] ?? 'N/A',
                          ),
                          _buildInfoRow(
                            label: isArabic ? 'المستوى' : 'Tier',
                            value: userData['tier'] ?? 'member',
                          ),
                        ],
                      ),

                      SizedBox(height: 16.h),

                      // Account Status Card
                      _buildInfoCard(
                        title: isArabic ? 'حالة الحساب' : 'Account Status',
                        icon: Icons.shield,
                        children: [
                          _buildInfoRow(
                            label: isArabic ? 'الحالة' : 'Status',
                            value: userData['status'] ?? 'active',
                          ),
                          _buildInfoRow(
                            label: isArabic ? 'تاريخ الانضمام' : 'Join Date',
                            value: userData['joinDate'] != null
                                ? _formatDate((userData['joinDate'] as Timestamp).toDate())
                                : 'N/A',
                          ),
                          _buildInfoRow(
                            label: isArabic ? 'آخر تسجيل دخول' : 'Last Login',
                            value: userData['lastLoginDate'] != null
                                ? _formatDate((userData['lastLoginDate'] as Timestamp).toDate())
                                : 'N/A',
                          ),
                        ],
                      ),

                      SizedBox(height: 16.h),

                      // Platform Preferences Card
                      _buildInfoCard(
                        title: isArabic ? 'تفضيلات المنصة' : 'Platform Preferences',
                        icon: FontAwesomeIcons.gamepad,
                        children: [
                          _buildInfoRow(
                            label: isArabic ? 'المنصة المفضلة' : 'Preferred Platform',
                            value: userData['preferredPlatform'] ?? 'both',
                          ),
                          _buildInfoRow(
                            label: isArabic ? 'رقم الهاتف' : 'Phone Number',
                            value: userData['phoneNumber'] ?? 'Not provided',
                          ),
                        ],
                      ),

                      SizedBox(height: 24.h),

                      // Action Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 56.h,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isArabic ? 'قريباً' : 'Coming Soon'),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          icon: Icon(Icons.edit, color: Colors.white),
                          label: Text(
                            isArabic ? 'تحديث المعلومات' : 'Update Information',
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

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDarkMode = Provider.of<AppProvider>(context).isDarkMode;

    return Container(
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
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 24.sp),
              SizedBox(width: 12.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}