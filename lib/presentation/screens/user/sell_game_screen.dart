// lib/presentation/screens/user/sell_game_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/selling_service.dart';
import '../../widgets/custom_loading.dart';

class SellGameScreen extends StatefulWidget {
  const SellGameScreen({Key? key}) : super(key: key);

  @override
  State<SellGameScreen> createState() => _SellGameScreenState();
}

class _SellGameScreenState extends State<SellGameScreen> {
  final SellingService _sellingService = SellingService();
  final TextEditingController _salePriceController = TextEditingController();
  
  List<Map<String, dynamic>> _sellableGames = [];
  bool _isLoading = true;
  bool _isSelling = false;
  Map<String, dynamic>? _selectedGame;

  @override
  void initState() {
    super.initState();
    _loadSellableGames();
  }

  @override
  void dispose() {
    _salePriceController.dispose();
    super.dispose();
  }

  Future<void> _loadSellableGames() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;
    
    if (userId == null) return;

    try {
      final games = await _sellingService.getUserSellableGames(userId);
      if (mounted) {
        setState(() {
          _sellableGames = games;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(
          msg: 'Error loading games: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  Future<void> _sellGame() async {
    if (_selectedGame == null || _salePriceController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please select a game and enter sale price',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;
    
    if (userId == null) return;

    final salePrice = double.tryParse(_salePriceController.text);
    if (salePrice == null || salePrice <= 0) {
      Fluttertoast.showToast(
        msg: 'Please enter a valid sale price',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    setState(() => _isSelling = true);

    try {
      final result = await _sellingService.sellContributedGame(
        userId: userId,
        gameId: _selectedGame!['gameId'],
        accountId: _selectedGame!['accountId'],
        salePrice: salePrice,
      );

      if (mounted) {
        if (result['success']) {
          Fluttertoast.showToast(
            msg: result['message'],
            backgroundColor: AppTheme.successColor,
          );
          Navigator.pop(context);
        } else {
          Fluttertoast.showToast(
            msg: result['message'],
            backgroundColor: AppTheme.errorColor,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isArabic = appProvider.isArabic;
    final isDarkMode = appProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          isArabic ? 'بيع الألعاب' : 'Sell Games',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const CustomLoading()
          : _sellableGames.isEmpty
              ? _buildEmptyState(isArabic, isDarkMode)
              : _buildContent(isArabic, isDarkMode),
    );
  }

  Widget _buildEmptyState(bool isArabic, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.gamepad,
            size: 64.sp,
            color: Colors.grey,
          ),
          SizedBox(height: 24.h),
          Text(
            isArabic ? 'لا توجد ألعاب للبيع' : 'No games available for sale',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            isArabic 
                ? 'ساهم بألعاب لتتمكن من بيعها لاحقاً'
                : 'Contribute games to be able to sell them later',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isArabic, bool isDarkMode) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructions
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.infoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.infoColor,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'معلومات البيع' : 'Selling Information',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.infoColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        isArabic
                            ? '• ستحصل على 90% من سعر البيع\n• 10% رسوم إدارية\n• سيتم خصم المساهمة من حسابك'
                            : '• You will receive 90% of sale price\n• 10% admin fee\n• Contribution will be removed from your account',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.infoColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Game selection
          Text(
            isArabic ? 'اختر اللعبة للبيع' : 'Select Game to Sell',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),

          ..._sellableGames.map((game) => _buildGameTile(game, isArabic, isDarkMode)),

          if (_selectedGame != null) ...[
            SizedBox(height: 24.h),

            // Sale price input
            Text(
              isArabic ? 'سعر البيع (ج.م)' : 'Sale Price (LE)',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),

            TextFormField(
              controller: _salePriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: isArabic ? 'أدخل سعر البيع' : 'Enter sale price',
                prefixIcon: Icon(FontAwesomeIcons.dollarSign, size: 20.sp),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                filled: true,
                fillColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
              ),
            ),

            if (_selectedGame!['estimatedSellValue'] != null) ...[
              SizedBox(height: 8.h),
              Text(
                '${isArabic ? "القيمة المقدرة" : "Estimated value"}: ${_selectedGame!['estimatedSellValue'].toStringAsFixed(0)} LE',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey,
                ),
              ),
            ],

            SizedBox(height: 24.h),

            // Sell button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSelling ? null : _sellGame,
                icon: _isSelling
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(FontAwesomeIcons.handHoldingDollar, size: 20.sp),
                label: Text(
                  _isSelling
                      ? (isArabic ? 'جاري البيع...' : 'Selling...')
                      : (isArabic ? 'بيع اللعبة' : 'Sell Game'),
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameTile(Map<String, dynamic> game, bool isArabic, bool isDarkMode) {
    final isSelected = _selectedGame != null && 
                      _selectedGame!['gameId'] == game['gameId'] &&
                      _selectedGame!['accountId'] == game['accountId'];

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGame = isSelected ? null : game;
            _salePriceController.clear();
          });
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppTheme.primaryColor.withOpacity(0.1)
                : (isDarkMode ? AppTheme.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected 
                  ? AppTheme.primaryColor
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Selection indicator
              Container(
                width: 24.w,
                height: 24.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : Colors.grey,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 16.sp,
                        color: Colors.white,
                      )
                    : null,
              ),
              SizedBox(width: 16.w),
              
              // Game info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game['gameTitle'] ?? 'Unknown Game',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.gamepad,
                          size: 12.sp,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '${game['platform']} • ${game['accountType']}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${isArabic ? "القيمة الأصلية" : "Original Value"}: ${game['gameValue']?.toStringAsFixed(0) ?? 0} LE',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16.sp,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}