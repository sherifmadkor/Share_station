import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../data/models/user_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralCodeController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;
  bool _isLoading = false;

  UserTier _selectedTier = UserTier.member;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  double get _subscriptionFee {
    switch (_selectedTier) {
      case UserTier.member:
        return 1500.0;
      case UserTier.client:
        return 750.0;
      case UserTier.user:
        return 0.0;
      default:
        return 0.0;
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      Fluttertoast.showToast(
        msg: 'Please agree to the terms and conditions',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final result = await authProvider.registerUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        tier: _selectedTier,
        subscriptionFee: _subscriptionFee,
        referrerId: _referralCodeController.text.trim().isEmpty
            ? null
            : _referralCodeController.text.trim(),
      );

      if (result['success']) {
        Fluttertoast.showToast(
          msg: result['message'],
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: AppTheme.successColor,
          textColor: Colors.white,
        );

        if (result['needsApproval'] == true) {
          // Navigate back to login for pending approval
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        } else {
          // User tier - can login immediately
          Navigator.pushReplacementNamed(context, AppRoutes.userDashboard);
        }
      } else {
        Fluttertoast.showToast(
          msg: result['message'] ?? 'Registration failed',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: AppTheme.errorColor,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'An error occurred. Please try again.',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.errorColor,
        textColor: Colors.white,
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            isArabic ? Icons.arrow_forward : Icons.arrow_back,
            color: AppTheme.primaryColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Language Toggle
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: IconButton(
              icon: Icon(
                Icons.language,
                color: AppTheme.primaryColor,
              ),
              onPressed: () => appProvider.toggleLanguage(),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [AppTheme.darkBackground, AppTheme.darkSurface]
                : [AppTheme.primaryColor.withOpacity(0.05), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Center(
                  child: Column(
                    children: [
                      Text(
                        isArabic ? 'إنشاء حساب جديد' : 'Create Account',
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        isArabic
                            ? 'انضم إلى مجتمع Share Station'
                            : 'Join the Share Station community',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: isDarkMode
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 32.h),

                // Membership Type Selection
                Text(
                  isArabic ? 'نوع العضوية' : 'Membership Type',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                  ),
                ),
                SizedBox(height: 12.h),

                // Tier Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildTierCard(
                        tier: UserTier.member,
                        title: isArabic ? 'عضو' : 'Member',
                        price: '1500 LE',
                        isArabic: isArabic,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildTierCard(
                        tier: UserTier.client,
                        title: isArabic ? 'عميل' : 'Client',
                        price: '750 LE',
                        isArabic: isArabic,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildTierCard(
                        tier: UserTier.user,
                        title: isArabic ? 'مستخدم' : 'User',
                        price: isArabic ? 'ادفع للاستخدام' : 'Pay per use',
                        isArabic: isArabic,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),

                // Registration Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'الاسم الكامل' : 'Full Name',
                          prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryColor),
                          hintText: isArabic ? 'أدخل اسمك الكامل' : 'Enter your full name',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return isArabic ? 'الاسم مطلوب' : 'Name is required';
                          }
                          if (value.length < 3) {
                            return isArabic
                                ? 'الاسم يجب أن يكون 3 أحرف على الأقل'
                                : 'Name must be at least 3 characters';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16.h),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'البريد الإلكتروني' : 'Email',
                          prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryColor),
                          hintText: isArabic ? 'أدخل بريدك الإلكتروني' : 'Enter your email',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return isArabic ? 'البريد الإلكتروني مطلوب' : 'Email is required';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return isArabic ? 'بريد إلكتروني غير صالح' : 'Invalid email';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16.h),

                      // Phone Field
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'رقم الهاتف' : 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primaryColor),
                          hintText: isArabic ? 'أدخل رقم هاتفك' : 'Enter your phone number',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return isArabic ? 'رقم الهاتف مطلوب' : 'Phone number is required';
                          }
                          if (value.length < 10) {
                            return isArabic
                                ? 'رقم هاتف غير صالح'
                                : 'Invalid phone number';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16.h),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'كلمة المرور' : 'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                              color: AppTheme.primaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          hintText: isArabic ? 'أدخل كلمة المرور' : 'Enter your password',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return isArabic ? 'كلمة المرور مطلوبة' : 'Password is required';
                          }
                          if (value.length < 6) {
                            return isArabic
                                ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
                                : 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16.h),

                      // Confirm Password Field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_isConfirmPasswordVisible,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                              color: AppTheme.primaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                          hintText: isArabic ? 'أعد إدخال كلمة المرور' : 'Re-enter your password',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return isArabic
                                ? 'تأكيد كلمة المرور مطلوب'
                                : 'Password confirmation is required';
                          }
                          if (value != _passwordController.text) {
                            return isArabic
                                ? 'كلمات المرور غير متطابقة'
                                : 'Passwords do not match';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16.h),

                      // Referral Code (Optional)
                      TextFormField(
                        controller: _referralCodeController,
                        decoration: InputDecoration(
                          labelText: isArabic
                              ? 'كود الإحالة (اختياري)'
                              : 'Referral Code (Optional)',
                          prefixIcon: Icon(Icons.card_giftcard, color: AppTheme.primaryColor),
                          hintText: isArabic
                              ? 'أدخل كود الإحالة إن وجد'
                              : 'Enter referral code if you have one',
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // Terms and Conditions
                      Row(
                        children: [
                          SizedBox(
                            width: 24.w,
                            height: 24.h,
                            child: Checkbox(
                              value: _agreeToTerms,
                              onChanged: (value) {
                                setState(() {
                                  _agreeToTerms = value ?? false;
                                });
                              },
                              activeColor: AppTheme.primaryColor,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'أوافق على الشروط والأحكام'
                                  : 'I agree to the Terms and Conditions',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: isDarkMode
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 32.h),

                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        height: 56.h,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            elevation: _isLoading ? 0 : 4,
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.w,
                          )
                              : Text(
                            isArabic ? 'إنشاء حساب' : 'Create Account',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isArabic ? 'لديك حساب بالفعل؟' : 'Already have an account?',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: isDarkMode
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              isArabic ? 'تسجيل الدخول' : 'Login',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard({
    required UserTier tier,
    required String title,
    required String price,
    required bool isArabic,
  }) {
    final isSelected = _selectedTier == tier;
    final isDarkMode = Provider.of<AppProvider>(context, listen: false).isDarkMode;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTier = tier;
        });
      },
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : isDarkMode
              ? AppTheme.darkSurface
              : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            Icon(
              tier == UserTier.member
                  ? FontAwesomeIcons.crown
                  : tier == UserTier.client
                  ? FontAwesomeIcons.userTie
                  : FontAwesomeIcons.user,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
              size: 24.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppTheme.primaryColor
                    : isDarkMode
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              price,
              style: TextStyle(
                fontSize: 12.sp,
                color: isDarkMode
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}