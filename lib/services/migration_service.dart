// lib/services/migration_service.dart
// Run this once to fix all existing users' balance issues

import 'package:cloud_firestore/cloud_firestore.dart';
import 'balance_service.dart';
import 'referral_service.dart';

class MigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BalanceService _balanceService = BalanceService();
  final ReferralService _referralService = ReferralService();

  /// Master migration function - run this to fix everything
  Future<Map<String, dynamic>> runCompleteMigration() async {
    try {
      print('=== STARTING COMPLETE MIGRATION ===');

      Map<String, dynamic> results = {
        'success': true,
        'steps': [],
      };

      // Step 1: Fix referral codes for all users
      print('\nStep 1: Ensuring all users have referral codes...');
      final step1 = await ensureAllUsersHaveReferralCodes();
      results['steps'].add({'step1_referralCodes': step1});

      // Step 2: Fix recruiterId inconsistencies
      print('\nStep 2: Fixing recruiterId inconsistencies...');
      final step2 = await fixRecruiterIdInconsistencies();
      results['steps'].add({'step2_recruiterIds': step2});

      // Step 3: Initialize balance entries for all users
      print('\nStep 3: Initializing balance entries for all users...');
      final step3 = await _balanceService.initializeAllUsersBalanceEntries();
      results['steps'].add({'step3_balanceEntries': step3});

      // Step 4: Fix missing referral earnings in balance
      print('\nStep 4: Fixing missing referral earnings in balance...');
      final step4 = await _balanceService.fixMissingReferralEarningsInBalance();
      results['steps'].add({'step4_referralEarnings': step4});

      // Step 5: Process pending referrals for active users
      print('\nStep 5: Processing pending referrals for active users...');
      final step5 = await processPendingReferralsForActiveUsers();
      results['steps'].add({'step5_pendingReferrals': step5});

      // Step 6: Recalculate all user balances
      print('\nStep 6: Recalculating all user balances...');
      final step6 = await recalculateAllUserBalances();
      results['steps'].add({'step6_recalculation': step6});

      print('\n=== MIGRATION COMPLETE ===');
      return results;
    } catch (e) {
      print('Migration error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Ensure all users have referral codes
  Future<Map<String, dynamic>> ensureAllUsersHaveReferralCodes() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      int generated = 0;

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();

        if (userData['referralCode'] == null || userData['referralCode'].toString().isEmpty) {
          final name = userData['name'] ?? 'USER';
          final memberId = userData['memberId'] ?? userDoc.id.substring(0, 3);

          // Generate referral code
          final referralCode = _referralService.generateReferralCode(name, memberId);

          await userDoc.reference.update({
            'referralCode': referralCode,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          generated++;
          print('Generated referral code for ${userDoc.id}: $referralCode');
        }
      }

      return {
        'success': true,
        'generated': generated,
        'message': 'Generated $generated referral codes',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Fix recruiterId inconsistencies (some have UIDs, some have codes)
  Future<Map<String, dynamic>> fixRecruiterIdInconsistencies() async {
    try {
      // Build mapping of referral codes to user IDs
      final Map<String, String> codeToUserId = {};
      final Map<String, String> userIdToCode = {};

      final usersSnapshot = await _firestore.collection('users').get();

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final referralCode = userData['referralCode'];
        if (referralCode != null && referralCode.toString().isNotEmpty) {
          codeToUserId[referralCode] = userDoc.id;
          userIdToCode[userDoc.id] = referralCode;
        }
      }

      int fixed = 0;
      final batch = _firestore.batch();
      int batchCount = 0;

      // Fix users with referral codes in recruiterId
      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final recruiterId = userData['recruiterId'];

        if (recruiterId != null && recruiterId.toString().isNotEmpty) {
          // Check if it's a referral code (6 chars, uppercase)
          if (recruiterId.toString().length == 6 &&
              RegExp(r'^[A-Z0-9]{6}$').hasMatch(recruiterId.toString())) {

            final actualReferrerId = codeToUserId[recruiterId];
            if (actualReferrerId != null) {
              batch.update(userDoc.reference, {
                'recruiterId': actualReferrerId,
                'recruiterCode': recruiterId, // Keep the code for reference
                'updatedAt': FieldValue.serverTimestamp(),
              });

              fixed++;
              batchCount++;

              if (batchCount >= 400) {
                await batch.commit();
                batchCount = 0;
              }
            }
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      return {
        'success': true,
        'fixed': fixed,
        'message': 'Fixed $fixed recruiterId fields',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Process pending referrals for active users
  Future<Map<String, dynamic>> processPendingReferralsForActiveUsers() async {
    try {
      final referralsSnapshot = await _firestore
          .collection('referrals')
          .where('revenueStatus', isEqualTo: 'pending')
          .get();

      int processed = 0;
      double totalRevenue = 0;

      for (var refDoc in referralsSnapshot.docs) {
        final refData = refDoc.data();
        final referredUserId = refData['referredUserId'];
        final referrerId = refData['referrerId'];
        final revenue = (refData['referralRevenue'] ?? 0.0).toDouble();

        if (referredUserId == null || referrerId == null) continue;

        // Check if referred user is active
        final userDoc = await _firestore.collection('users').doc(referredUserId).get();
        if (userDoc.exists && userDoc.data()!['status'] == 'active') {
          // Process the referral reward
          await _referralService.processReferralRewardAfterApproval(referredUserId);
          processed++;
          totalRevenue += revenue;
        }
      }

      return {
        'success': true,
        'processed': processed,
        'totalRevenue': totalRevenue,
        'message': 'Processed $processed referrals worth $totalRevenue LE',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Recalculate all user balances
  Future<Map<String, dynamic>> recalculateAllUserBalances() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      int recalculated = 0;

      for (var userDoc in usersSnapshot.docs) {
        final totalBalance = await _balanceService.calculateUserTotalBalance(userDoc.id);

        // Update the calculated total (for caching/display purposes)
        await userDoc.reference.update({
          'calculatedTotalBalance': totalBalance,
          'lastBalanceCalculation': FieldValue.serverTimestamp(),
        });

        recalculated++;
      }

      return {
        'success': true,
        'recalculated': recalculated,
        'message': 'Recalculated balance for $recalculated users',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Diagnostic function to check a specific user
  Future<void> diagnoseUser(String userId) async {
    try {
      print('=== DIAGNOSING USER: $userId ===');

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('User not found!');
        return;
      }

      final userData = userDoc.data()!;

      print('\n1. BASIC INFO:');
      print('  Name: ${userData['name']}');
      print('  Email: ${userData['email']}');
      print('  Member ID: ${userData['memberId']}');
      print('  Referral Code: ${userData['referralCode']}');
      print('  Status: ${userData['status']}');
      print('  Tier: ${userData['tier']}');

      print('\n2. REFERRAL INFO:');
      print('  recruiterId: ${userData['recruiterId']}');
      print('  recruiterCode: ${userData['recruiterCode']}');
      print('  totalReferrals: ${userData['totalReferrals']}');
      print('  referralEarnings: ${userData['referralEarnings']}');
      print('  pendingReferralRevenue: ${userData['pendingReferralRevenue']}');
      print('  paidReferralRevenue: ${userData['paidReferralRevenue']}');

      print('\n3. BALANCE COMPONENTS:');
      print('  borrowValue: ${userData['borrowValue']}');
      print('  sellValue: ${userData['sellValue']}');
      print('  refunds: ${userData['refunds']}');
      print('  referralEarnings: ${userData['referralEarnings']}');
      print('  cashIn: ${userData['cashIn']}');
      print('  usedBalance: ${userData['usedBalance']}');
      print('  expiredBalance: ${userData['expiredBalance']}');

      print('\n4. BALANCE ENTRIES:');
      final balanceEntries = userData['balanceEntries'];
      if (balanceEntries == null) {
        print('  NO BALANCE ENTRIES ARRAY!');
      } else {
        final entries = List<Map<String, dynamic>>.from(balanceEntries);
        print('  Total entries: ${entries.length}');
        for (var entry in entries) {
          print('    - Type: ${entry['type']}, Amount: ${entry['amount']}, Expired: ${entry['isExpired']}');
        }
      }

      print('\n5. CALCULATED BALANCE:');
      final totalBalance = await _balanceService.calculateUserTotalBalance(userId);
      print('  Total Balance: $totalBalance LE');

      // Check referral records
      print('\n6. REFERRAL RECORDS:');
      final referralDocs = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: userId)
          .get();

      print('  Found ${referralDocs.docs.length} users referred by this user');
      for (var refDoc in referralDocs.docs) {
        final refData = refDoc.data();
        print('    - Referred: ${refData['referredUserId']}');
        print('      Revenue: ${refData['referralRevenue']} LE');
        print('      Status: ${refData['revenueStatus']}');
      }

      print('\n=== END DIAGNOSIS ===');
    } catch (e) {
      print('Diagnosis error: $e');
    }
  }
}

// Usage example - Add this to an admin screen or run as a one-time script
class MigrationRunner {
  static Future<void> runMigration() async {
    final migrationService = MigrationService();

    print('Starting migration...');
    final results = await migrationService.runCompleteMigration();

    if (results['success']) {
      print('Migration completed successfully!');
      print('Results: ${results['steps']}');
    } else {
      print('Migration failed: ${results['error']}');
    }
  }

  static Future<void> diagnoseSpecificUser(String userId) async {
    final migrationService = MigrationService();
    await migrationService.diagnoseUser(userId);
  }
}