// This provides a UI to run the migration and fix all balance issues

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/migration_service.dart';
import '../../core/theme/app_theme.dart';

class AdminMigrationWidget extends StatefulWidget {
  const AdminMigrationWidget({Key? key}) : super(key: key);

  @override
  State<AdminMigrationWidget> createState() => _AdminMigrationWidgetState();
}

class _AdminMigrationWidgetState extends State<AdminMigrationWidget> {
  final MigrationService _migrationService = MigrationService();
  bool _isRunning = false;
  String _status = '';
  Map<String, dynamic>? _results;

  Future<void> _runMigration() async {
    setState(() {
      _isRunning = true;
      _status = 'Starting migration...';
      _results = null;
    });

    try {
      final results = await _migrationService.runCompleteMigration();
      
      setState(() {
        _results = results;
        _status = results['success'] 
            ? 'Migration completed successfully!' 
            : 'Migration failed: ${results['error']}';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build,
                color: Colors.orange,
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Text(
                'Balance System Migration',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'This will fix all balance and referral issues:\n'
            '• Initialize balance entries for all users\n'
            '• Fix referral earnings not showing in balance\n'
            '• Process pending referrals for active users\n'
            '• Fix recruiterId inconsistencies\n'
            '• Recalculate all user balances',
            style: TextStyle(fontSize: 14.sp),
          ),
          SizedBox(height: 16.h),
          
          if (_status.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: _status.contains('success') 
                    ? Colors.green.withOpacity(0.1)
                    : _status.contains('failed') || _status.contains('Error')
                        ? Colors.red.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: _status.contains('success') 
                          ? Colors.green
                          : _status.contains('failed') || _status.contains('Error')
                              ? Colors.red
                              : Colors.blue,
                    ),
                  ),
                  if (_results != null && _results!['steps'] != null) ...[
                    SizedBox(height: 8.h),
                    ...(_results!['steps'] as List).map((step) {
                      final stepData = step as Map<String, dynamic>;
                      final key = stepData.keys.first;
                      final value = stepData[key] as Map<String, dynamic>;
                      return Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Text(
                          '✓ ${key.replaceAll('_', ' ')}: ${value['message'] ?? 'Completed'}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.green.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
            SizedBox(height: 16.h),
          ],
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRunning ? null : _runMigration,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              icon: _isRunning 
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(Icons.play_arrow, color: Colors.white),
              label: Text(
                _isRunning ? 'Running Migration...' : 'Run Migration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          SizedBox(height: 8.h),
          
          Text(
            '⚠️ Run this only once to fix existing data',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.orange.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}