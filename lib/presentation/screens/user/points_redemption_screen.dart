// lib/presentation/screens/user/points_redemption_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/points_service.dart';

class PointsRedemptionScreen extends StatefulWidget {
  const PointsRedemptionScreen({Key? key}) : super(key: key);

  @override
  State<PointsRedemptionScreen> createState() => _PointsRedemptionScreenState();
}

class _PointsRedemptionScreenState extends State<PointsRedemptionScreen> {
  final PointsService _pointsService = PointsService();
  
  bool _isLoading = false;
  bool _isRedeeming = false;
  List<Map<String, dynamic>> _pointsHistory = [];
  
  @override
  void initState() {
    super.initState();
    _loadPointsHistory();
  }

  Future<void> _loadPointsHistory() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final history = await _pointsService.getUserPointsHistory(user.uid);
      if (mounted) {
        setState(() {
          _pointsHistory = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('Error loading points history: $e');
    }
  }

  Future<void> _redeemPoints(int points) async {
    final authProvider = context.read<AuthProvider>();
    final appProvider = context.read<AppProvider>();
    final isArabic = appProvider.isArabic;
    final user = authProvider.currentUser;

    if (user == null) return;

    // Show confirmation dialog
    final confirmed = await _showRedemptionConfirmDialog(points, isArabic);
    if (!confirmed) return;

    setState(() => _isRedeeming = true);

    try {
      final result = await _pointsService.redeemPoints(
        userId: user.uid,
        pointsToRedeem: points,
      );

      if (mounted) {
        if (result['success']) {
          Fluttertoast.showToast(
            msg: result['message'],
            backgroundColor: AppTheme.successColor,
            toastLength: Toast.LENGTH_LONG,
          );
          
          // Refresh points history
          await _loadPointsHistory();
        } else {
          Fluttertoast.showToast(
            msg: result['message'],
            backgroundColor: AppTheme.errorColor,
            toastLength: Toast.LENGTH_LONG,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: isArabic ? 'خطأ في استبدال النقاط' : 'Error redeeming points',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRedeeming = false);
      }
    }
  }

  Future<bool> _showRedemptionConfirmDialog(int points, bool isArabic) async {
    final leValue = points / 25;
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isArabic ? 'تأكيد الاستبدال' : 'Confirm Redemption',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic 
                ? 'هل أنت متأكد من استبدال $points نقطة مقابل ${leValue.toStringAsFixed(0)} جنيه؟'
                : 'Are you sure you want to redeem $points points for ${leValue.toStringAsFixed(0)} LE?',
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.infoColor, size: 16.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      isArabic
                        ? 'سيتم إضافة المبلغ إلى رصيد المحطة الخاص بك'
                        : 'The amount will be added to your Station Limit balance',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.infoColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              isArabic ? 'إلغاء' : 'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text(
              isArabic ? 'تأكيد' : 'Confirm',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'استبدال النقاط' : 'Points Redemption'),
          backgroundColor: AppTheme.primaryColor,
        ),
        body: Center(
          child: Text(
            isArabic ? 'يجب تسجيل الدخول أولاً' : 'Please login first',
            style: TextStyle(fontSize: 16.sp),
          ),
        ),
      );
    }

    final userPoints = user.points;
    final redemptionOptions = _pointsService.getRedemptionOptions();

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          isArabic ? 'استبدال النقاط' : 'Points Redemption',
          style: TextStyle(
            color: isDarkMode ? Colors.white : AppTheme.darkBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : AppTheme.darkBackground,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadPointsHistory();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Points Balance Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      offset: Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      isArabic ? 'رصيد النقاط' : 'Points Balance',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '$userPoints',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      isArabic ? 'نقطة' : 'Points',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        isArabic 
                          ? 'القيمة: ${(userPoints / 25).toStringAsFixed(1)} جنيه'
                          : 'Value: ${(userPoints / 25).toStringAsFixed(1)} LE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // Redemption Options
              Text(
                isArabic ? 'خيارات الاستبدال' : 'Redemption Options',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                isArabic 
                  ? 'كل 25 نقطة = 1 جنيه مصري'
                  : 'Every 25 points = 1 Egyptian Pound',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              SizedBox(height: 16.h),

              if (userPoints < 25)
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.warningColor),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          isArabic
                            ? 'تحتاج إلى ${25 - userPoints} نقطة إضافية للاستبدال'
                            : 'You need ${25 - userPoints} more points to redeem',
                          style: TextStyle(
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.h,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: redemptionOptions.length,
                  itemBuilder: (context, index) {
                    final option = redemptionOptions[index];
                    final points = option['points'] as int;
                    final leValue = option['leValue'] as int;
                    final canRedeem = userPoints >= points;

                    return GestureDetector(
                      onTap: canRedeem && !_isRedeeming ? () => _redeemPoints(points) : null,
                      child: Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: canRedeem 
                            ? (isDarkMode ? AppTheme.darkSurface : Colors.white)
                            : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: canRedeem 
                              ? AppTheme.primaryColor.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.3),
                          ),
                          boxShadow: canRedeem ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              offset: Offset(0, 2),
                              blurRadius: 8,
                            ),
                          ] : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$points',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: canRedeem ? AppTheme.primaryColor : Colors.grey,
                              ),
                            ),
                            Text(
                              isArabic ? 'نقطة' : 'Points',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: canRedeem ? Colors.black54 : Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Icon(
                              Icons.arrow_downward,
                              color: canRedeem ? AppTheme.primaryColor : Colors.grey,
                              size: 16.sp,
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '$leValue LE',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: canRedeem ? AppTheme.successColor : Colors.grey,
                              ),
                            ),
                            if (!canRedeem)
                              Padding(
                                padding: EdgeInsets.only(top: 4.h),
                                child: Text(
                                  isArabic ? 'غير متاح' : 'Not Available',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              SizedBox(height: 24.h),

              // Points History
              Text(
                isArabic ? 'تاريخ النقاط' : 'Points History',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16.h),

              if (_isLoading)
                Center(child: CircularProgressIndicator())
              else if (_pointsHistory.isEmpty)
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 48.sp,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        isArabic ? 'لا يوجد تاريخ نقاط' : 'No points history',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _pointsHistory.length,
                  itemBuilder: (context, index) {
                    final entry = _pointsHistory[index];
                    final points = entry['points'] as int;
                    final type = entry['type'] as String;
                    final description = entry['description'] as String;
                    final timestamp = entry['timestamp'];
                    
                    DateTime? date;
                    if (timestamp != null) {
                      date = timestamp.toDate();
                    }

                    return Card(
                      margin: EdgeInsets.only(bottom: 8.h),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: points > 0 ? AppTheme.successColor : AppTheme.errorColor,
                          child: Icon(
                            points > 0 ? Icons.add : Icons.remove,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                        ),
                        title: Text(
                          description,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: date != null
                          ? Text(
                              '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey,
                              ),
                            )
                          : null,
                        trailing: Text(
                          '${points > 0 ? '+' : ''}$points',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: points > 0 ? AppTheme.successColor : AppTheme.errorColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}