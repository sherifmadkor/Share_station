// lib/services/referral_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'balance_service.dart';
import '../data/models/user_model.dart';

class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BalanceService _balanceService = BalanceService();

  // Validate referral code (check if member ID exists)
  Future<Map<String, dynamic>> validateReferralCode(String referralCode) async {
    try {
      if (referralCode.trim().isEmpty) {
        return {
          'valid': false,
          'message': 'Referral code cannot be empty',
        };
      }

      // Find referrer by their member ID (3-digit code)
      final referrerSnapshot = await _firestore
          .collection('users')
          .where('memberId', isEqualTo: referralCode.trim())
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (referrerSnapshot.docs.isEmpty) {
        return {
          'valid': false,
          'message': 'Invalid referral code. Please check and try again.',
        };
      }

      final referrerDoc = referrerSnapshot.docs.first;
      final referrerData = referrerDoc.data();

      return {
        'valid': true,
        'referrerId': referrerDoc.id,
        'referrerName': referrerData['name'] ?? 'Unknown',
        'referrerTier': referrerData['tier'] ?? 'member',
        'message': 'Valid referral code from ${referrerData['name']}',
      };
    } catch (e) {
      print('Error validating referral code: $e');
      return {
        'valid': false,
        'message': 'Error validating referral code. Please try again.',
      };
    }
  }

  // Process referral during registration
  Future<Map<String, dynamic>> processReferral({
    required String newUserId,
    required String? referralCode,
    required double membershipFee,
    required String userTier,
  }) async {
    try {
      if (referralCode == null || referralCode.trim().isEmpty) {
        return {
          'success': true,
          'message': 'No referral code provided',
          'referralProcessed': false,
        };
      }

      // Validate referral code first
      final validation = await validateReferralCode(referralCode);
      if (!validation['valid']) {
        return {
          'success': false,
          'message': validation['message'],
          'referralProcessed': false,
        };
      }

      final referrerId = validation['referrerId'];
      final referrerName = validation['referrerName'];

      // Calculate referral earnings (20% of membership fee)
      final referralEarnings = membershipFee * 0.2;

      final batch = _firestore.batch();

      // Update referrer's data
      final referrerRef = _firestore.collection('users').doc(referrerId);
      batch.update(referrerRef, {
        'referredUsers': FieldValue.arrayUnion([newUserId]),
        'referralEarnings': FieldValue.increment(referralEarnings),
        'totalReferrals': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update new user with referrer info
      final newUserRef = _firestore.collection('users').doc(newUserId);
      batch.update(newUserRef, {
        'recruiterId': referrerId,
        'recruiterName': referrerName,
        'referralCode': referralCode.trim(),
      });

      // Create referral history entry
      batch.set(_firestore.collection('referral_history').doc(), {
        'referrerId': referrerId,
        'referrerName': referrerName,
        'newUserId': newUserId,
        'referralCode': referralCode.trim(),
        'membershipFee': membershipFee,
        'referralEarnings': referralEarnings,
        'newUserTier': userTier,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'registration_referral',
      });

      await batch.commit();

      // Add balance entry for referrer using balance service
      await _balanceService.addBalanceEntry(
        userId: referrerId,
        type: 'referralEarnings',
        amount: referralEarnings,
        description: 'Referral bonus from new $userTier member',
        expires: true, // Expires in 90 days
        expiryDays: 90,
      );

      return {
        'success': true,
        'message': 'Referral processed successfully',
        'referralProcessed': true,
        'referrerId': referrerId,
        'referrerName': referrerName,
        'earningsAwarded': referralEarnings,
      };
    } catch (e) {
      print('Error processing referral: $e');
      return {
        'success': false,
        'message': 'Failed to process referral: $e',
        'referralProcessed': false,
      };
    }
  }

  // Process referral earnings from user activities (contributions, borrows)
  Future<Map<String, dynamic>> processActivityReferralEarnings({
    required String userId,
    required double transactionAmount,
    required String activityType,
    required String activityDescription,
  }) async {
    try {
      // Get user's referrer information
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return {
          'success': false,
          'message': 'User not found',
          'earningsProcessed': false,
        };
      }

      final userData = userDoc.data()!;
      final referrerId = userData['recruiterId'];

      // If user has no referrer, skip
      if (referrerId == null) {
        return {
          'success': true,
          'message': 'User has no referrer',
          'earningsProcessed': false,
        };
      }

      // Check if referrer still exists and is active
      final referrerDoc = await _firestore.collection('users').doc(referrerId).get();
      if (!referrerDoc.exists || referrerDoc.data()?['status'] != 'active') {
        return {
          'success': true,
          'message': 'Referrer is inactive or not found',
          'earningsProcessed': false,
        };
      }

      // Calculate 20% referral earnings
      final earnings = transactionAmount * 0.2;
      
      if (earnings <= 0) {
        return {
          'success': true,
          'message': 'No earnings to process',
          'earningsProcessed': false,
        };
      }

      final batch = _firestore.batch();

      // Update referrer's earnings
      final referrerRef = _firestore.collection('users').doc(referrerId);
      batch.update(referrerRef, {
        'referralEarnings': FieldValue.increment(earnings),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create activity referral history
      batch.set(_firestore.collection('referral_history').doc(), {
        'referrerId': referrerId,
        'referrerName': referrerDoc.data()?['name'] ?? 'Unknown',
        'userId': userId,
        'userName': userData['name'] ?? 'Unknown',
        'activityType': activityType,
        'activityDescription': activityDescription,
        'transactionAmount': transactionAmount,
        'referralEarnings': earnings,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'activity_referral',
      });

      await batch.commit();

      // Add balance entry for referrer
      await _balanceService.addBalanceEntry(
        userId: referrerId,
        type: 'referralEarnings',
        amount: earnings,
        description: 'Referral earnings from $activityType: $activityDescription',
        expires: true,
        expiryDays: 90,
      );

      return {
        'success': true,
        'message': 'Activity referral earnings processed',
        'earningsProcessed': true,
        'referrerId': referrerId,
        'earningsAwarded': earnings,
      };
    } catch (e) {
      print('Error processing activity referral earnings: $e');
      return {
        'success': false,
        'message': 'Failed to process activity referral earnings: $e',
        'earningsProcessed': false,
      };
    }
  }

  // Get referral statistics for a user
  Future<Map<String, dynamic>> getUserReferralStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return {
          'success': false,
          'message': 'User not found',
        };
      }

      final userData = userDoc.data()!;
      final referredUsers = userData['referredUsers'] as List? ?? [];
      final totalReferralEarnings = (userData['referralEarnings'] ?? 0.0).toDouble();
      final totalReferrals = (userData['totalReferrals'] ?? 0).toInt();

      // Get recent referral activity
      final recentReferrals = await _firestore
          .collection('referral_history')
          .where('referrerId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final referralHistory = recentReferrals.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      return {
        'success': true,
        'totalReferrals': totalReferrals,
        'totalEarnings': totalReferralEarnings,
        'referredUserIds': referredUsers,
        'recentActivity': referralHistory,
        'userMemberId': userData['memberId'],
      };
    } catch (e) {
      print('Error getting referral stats: $e');
      return {
        'success': false,
        'message': 'Failed to get referral statistics: $e',
      };
    }
  }

  // Get referral statistics for admin dashboard
  Future<Map<String, dynamic>> getAdminReferralStats() async {
    try {
      // Get all users with referral data
      final usersSnapshot = await _firestore
          .collection('users')
          .where('totalReferrals', isGreaterThan: 0)
          .get();

      int totalReferrals = 0;
      double totalReferralEarnings = 0;
      final topReferrers = <Map<String, dynamic>>[];

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final userReferrals = ((data['totalReferrals'] ?? 0) as num).toInt();
        final userEarnings = ((data['referralEarnings'] ?? 0.0) as num).toDouble();
        
        totalReferrals += userReferrals;
        totalReferralEarnings += userEarnings;

        topReferrers.add({
          'userId': doc.id,
          'userName': data['name'] ?? 'Unknown',
          'memberId': data['memberId'],
          'totalReferrals': userReferrals,
          'totalEarnings': userEarnings,
        });
      }

      // Sort by total referrals
      topReferrers.sort((a, b) => (b['totalReferrals'] as int).compareTo(a['totalReferrals'] as int));

      // Get recent referral activity
      final recentActivity = await _firestore
          .collection('referral_history')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final recentReferrals = recentActivity.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      return {
        'success': true,
        'totalReferrals': totalReferrals,
        'totalReferralEarnings': totalReferralEarnings,
        'activeReferrers': usersSnapshot.docs.length,
        'topReferrers': topReferrers.take(10).toList(),
        'recentActivity': recentReferrals,
      };
    } catch (e) {
      print('Error getting admin referral stats: $e');
      return {
        'success': false,
        'message': 'Failed to get admin referral statistics: $e',
      };
    }
  }

  // Check if a user was referred by someone
  Future<bool> isUserReferred(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      return userData['recruiterId'] != null;
    } catch (e) {
      print('Error checking if user was referred: $e');
      return false;
    }
  }

  // Get referrer information for a user
  Future<Map<String, dynamic>?> getUserReferrer(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;
      
      final userData = userDoc.data()!;
      final recruiterId = userData['recruiterId'];
      
      if (recruiterId == null) return null;

      final referrerDoc = await _firestore.collection('users').doc(recruiterId).get();
      if (!referrerDoc.exists) return null;

      final referrerData = referrerDoc.data()!;
      return {
        'id': recruiterId,
        'name': referrerData['name'],
        'memberId': referrerData['memberId'],
        'tier': referrerData['tier'],
      };
    } catch (e) {
      print('Error getting user referrer: $e');
      return null;
    }
  }

  // Generate referral report for a specific period
  Future<Map<String, dynamic>> generateReferralReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final referralHistory = await _firestore
          .collection('referral_history')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: true)
          .get();

      double totalEarnings = 0;
      int registrationReferrals = 0;
      int activityReferrals = 0;
      final referrerStats = <String, Map<String, dynamic>>{};

      for (var doc in referralHistory.docs) {
        final data = doc.data();
        final earnings = (data['referralEarnings'] ?? 0.0).toDouble();
        final type = data['type'] ?? 'unknown';
        final referrerId = data['referrerId'] as String;
        final referrerName = data['referrerName'] ?? 'Unknown';

        totalEarnings += earnings;

        if (type == 'registration_referral') {
          registrationReferrals++;
        } else if (type == 'activity_referral') {
          activityReferrals++;
        }

        // Track per-referrer stats
        if (!referrerStats.containsKey(referrerId)) {
          referrerStats[referrerId] = {
            'referrerName': referrerName,
            'totalEarnings': 0.0,
            'referralCount': 0,
          };
        }
        
        referrerStats[referrerId]!['totalEarnings'] = 
          (referrerStats[referrerId]!['totalEarnings'] as double) + earnings;
        referrerStats[referrerId]!['referralCount'] = 
          (referrerStats[referrerId]!['referralCount'] as int) + 1;
      }

      return {
        'success': true,
        'period': {
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        },
        'summary': {
          'totalEarnings': totalEarnings,
          'totalReferrals': referralHistory.docs.length,
          'registrationReferrals': registrationReferrals,
          'activityReferrals': activityReferrals,
        },
        'referrerStats': referrerStats.entries.map((entry) => {
          'referrerId': entry.key,
          ...entry.value,
        }).toList(),
        'detailedHistory': referralHistory.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList(),
      };
    } catch (e) {
      print('Error generating referral report: $e');
      return {
        'success': false,
        'message': 'Failed to generate referral report: $e',
      };
    }
  }
}