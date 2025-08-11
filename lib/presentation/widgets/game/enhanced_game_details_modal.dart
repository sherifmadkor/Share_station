import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../data/models/game_model.dart' as game_models;
import '../../../services/queue_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/user/borrow_game_screen.dart';

class EnhancedGameDetailsModal extends StatefulWidget {
  final game_models.GameAccount game;
  final Map<String, dynamic> availabilityInfo;

  const EnhancedGameDetailsModal({
    Key? key,
    required this.game,
    required this.availabilityInfo,
  }) : super(key: key);

  @override
  State<EnhancedGameDetailsModal> createState() => _EnhancedGameDetailsModalState();
}

class _EnhancedGameDetailsModalState extends State<EnhancedGameDetailsModal> {
  final QueueService _queueService = QueueService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isInQueue = false;
  int _queuePosition = 0;
  bool _isLoading = false;
  Map<String, dynamic> _selectedSlot = {};
  
  @override
  void initState() {
    super.initState();
    _checkUserQueueStatus();
  }
  
  Future<void> _checkUserQueueStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    if (user == null) return;
    
    // Check if user is in any queue for this game
    try {
      final queues = await _queueService.getUserQueueEntries(user.uid);
      
      for (var queue in queues) {
        if (queue['gameId'] == widget.game.accountId) {
          setState(() {
            _isInQueue = true;
            _queuePosition = queue['position'] ?? 0;
            _selectedSlot = {
              'accountId': queue['accountId'],
              'platform': queue['platform'],
              'accountType': queue['accountType'],
            };
          });
          break;
        }
      }
    } catch (e) {
      print('Error checking queue status: $e');
    }
  }
  
  Future<void> _joinQueue(Map<String, dynamic> slot) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    final user = authProvider.currentUser;
    
    if (user == null) {
      Fluttertoast.showToast(
        msg: isArabic ? 'يجب تسجيل الدخول' : 'Please login',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final result = await _queueService.joinQueue(
        userId: user.uid,
        userName: user.name,
        gameId: widget.game.accountId,
        gameTitle: widget.game.title,
        accountId: slot['accountId'],
        platform: slot['platform'],
        accountType: slot['accountType'],
        userTotalShares: user.totalShares,
        memberId: user.memberId,
      );
      
      if (result['success']) {
        setState(() {
          _isInQueue = true;
          _queuePosition = result['position'] ?? 0;
          _selectedSlot = slot;
        });
        
        Fluttertoast.showToast(
          msg: isArabic 
              ? 'تمت إضافتك للقائمة. موضعك: $_queuePosition'
              : 'Added to queue. Your position: $_queuePosition',
          backgroundColor: AppTheme.successColor,
        );
      } else {
        Fluttertoast.showToast(
          msg: result['message'] ?? 'Failed to join queue',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error joining queue',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _leaveQueue() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isArabic = appProvider.isArabic;
    final user = authProvider.currentUser;
    
    if (user == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final result = await _queueService.leaveQueue(
        userId: user.uid,
        gameId: widget.game.accountId,
        accountId: _selectedSlot['accountId'],
        platform: _selectedSlot['platform'],
        accountType: _selectedSlot['accountType'],
      );
      
      if (result['success']) {
        setState(() {
          _isInQueue = false;
          _queuePosition = 0;
          _selectedSlot = {};
        });
        
        Fluttertoast.showToast(
          msg: isArabic ? 'تم إزالتك من القائمة' : 'Left queue successfully',
          backgroundColor: AppTheme.successColor,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error leaving queue',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;
    
    final hasAvailableSlots = widget.availabilityInfo['availableSlots'] > 0;
    final isFullyBorrowed = widget.availabilityInfo['availableSlots'] == 0;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
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
              color: Colors.grey.withAlpha(77),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game header and image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: CachedNetworkImage(
                      imageUrl: widget.game.coverImageUrl ?? '',
                      height: 200.h,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.withAlpha(77),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.withAlpha(77),
                        child: Icon(
                          FontAwesomeIcons.gamepad,
                          size: 50.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Title
                  Text(
                    widget.game.title,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  // Availability Status Card
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 16.h),
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: isFullyBorrowed 
                          ? AppTheme.warningColor.withOpacity(0.1)
                          : AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isFullyBorrowed 
                            ? AppTheme.warningColor
                            : AppTheme.successColor,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isFullyBorrowed ? Icons.timer : Icons.check_circle,
                              color: isFullyBorrowed 
                                  ? AppTheme.warningColor
                                  : AppTheme.successColor,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              isFullyBorrowed
                                  ? (isArabic ? 'اللعبة مستعارة حالياً' : 'Currently Borrowed')
                                  : (isArabic ? 'متاح للاستعارة' : 'Available for Borrowing'),
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        
                        if (isFullyBorrowed) ...[
                          SizedBox(height: 12.h),
                          if (widget.availabilityInfo['nextReturnDate'] != null)
                            Text(
                              isArabic
                                  ? 'العودة المتوقعة: ${widget.availabilityInfo['estimatedWaitDays']} يوم'
                                  : 'Expected return: ${widget.availabilityInfo['estimatedWaitDays']} days',
                              style: TextStyle(fontSize: 14.sp),
                            ),
                          if (widget.availabilityInfo['totalInQueue'] > 0)
                            Text(
                              isArabic
                                  ? 'في القائمة: ${widget.availabilityInfo['totalInQueue']} شخص'
                                  : 'In queue: ${widget.availabilityInfo['totalInQueue']} people',
                              style: TextStyle(fontSize: 14.sp),
                            ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Queue Position Card (if user is in queue)
                  if (_isInQueue)
                    Container(
                      margin: EdgeInsets.only(bottom: 16.h),
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppTheme.infoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppTheme.infoColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.queue, color: AppTheme.infoColor),
                              SizedBox(width: 8.w),
                              Text(
                                isArabic ? 'أنت في القائمة' : 'You are in queue',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.infoColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            isArabic
                                ? 'موضعك: #$_queuePosition'
                                : 'Your position: #$_queuePosition',
                            style: TextStyle(fontSize: 14.sp),
                          ),
                          Text(
                            isArabic
                                ? 'التوقيت المقدر: ${_queuePosition * 30} يوم'
                                : 'Estimated wait: ${_queuePosition * 30} days',
                            style: TextStyle(fontSize: 14.sp),
                          ),
                          SizedBox(height: 12.h),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _leaveQueue,
                            icon: Icon(Icons.exit_to_app),
                            label: Text(
                              isArabic ? 'مغادرة القائمة' : 'Leave Queue',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Slots List
                  Text(
                    isArabic ? 'النسخ المتاحة' : 'Available Copies',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  
                  _buildSlotsListWithQueue(),
                  
                  SizedBox(height: 24.h),
                  
                  // Action Buttons
                  if (hasAvailableSlots)
                    SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BorrowGameScreen(game: widget.game),
                            ),
                          );
                        },
                        icon: Icon(FontAwesomeIcons.gamepad, color: Colors.white),
                        label: Text(
                          isArabic ? 'طلب استعارة' : 'Request Borrow',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
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
  
  Widget _buildSlotsListWithQueue() {
    final List<Widget> slotWidgets = [];
    
    if (widget.game.accounts != null && widget.game.accounts!.isNotEmpty) {
      for (var account in widget.game.accounts!) {
        final slots = account['slots'] as Map<String, dynamic>? ?? {};
        
        for (var entry in slots.entries) {
          final slotData = entry.value as Map<String, dynamic>;
          final slotKey = entry.key;
          final parts = slotKey.split('_');
          final platform = parts[0];
          final accountType = parts.length > 1 ? parts.sublist(1).join('_') : '';
          
          final isAvailable = slotData['status'] == 'available';
          final isTaken = slotData['status'] == 'taken';
          
          slotWidgets.add(
            StreamBuilder<Map<String, dynamic>>(
              stream: Stream.fromFuture(_queueService.getSlotQueueInfo(
                gameId: widget.game.accountId,
                accountId: account['accountId'] ?? '',
                platform: platform,
                accountType: accountType,
              )),
              builder: (context, snapshot) {
                final queueInfo = snapshot.data ?? {};
                final queueCount = queueInfo['queueCount'] ?? 0;
                
                return Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? AppTheme.successColor.withOpacity(0.1)
                        : isTaken
                            ? AppTheme.warningColor.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: isAvailable
                          ? AppTheme.successColor
                          : isTaken
                              ? AppTheme.warningColor
                              : Colors.grey,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.playstation,
                        size: 20.sp,
                        color: isAvailable
                            ? AppTheme.successColor
                            : isTaken
                                ? AppTheme.warningColor
                                : Colors.grey,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${platform.toUpperCase()} - $accountType',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isTaken && queueInfo['estimatedReturnDate'] != null)
                              Text(
                                'Returns in ${queueInfo['daysUntilReturn']} days',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey,
                                ),
                              ),
                            if (queueCount > 0)
                              Text(
                                '$queueCount in queue',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppTheme.warningColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isTaken && !_isInQueue)
                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _joinQueue({
                                  'accountId': account['accountId'],
                                  'platform': platform,
                                  'accountType': accountType,
                                }),
                          child: Text('Join Queue'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warningColor,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
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
      }
    }
    
    return Column(children: slotWidgets);
  }
}