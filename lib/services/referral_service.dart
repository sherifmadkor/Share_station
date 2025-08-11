// lib/services/referral_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'balance_service.dart';

class ReferralService {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BalanceService _balanceService = BalanceService();

  /// Generate unique referral code based on name and member ID (BRD requirement)
  String generateReferralCode(String name, String memberId) {
    // Clean name (remove spaces, special chars, take first 3 letters)
    final cleanName = name
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .toUpperCase()
        .padRight(3, 'X')
        .substring(0, 3);
    
    // Use member ID for uniqueness
    final memberIdPart = memberId.length >= 3 
        ? memberId.substring(memberId.length - 3)
        : memberId.padLeft(3, '0');
    
    return '$cleanName$memberIdPart';
  }

  /// Validate referral code according to BRD requirements
  Future<Map<String, dynamic>?> validateReferralCode(String referralCode) async {
    try {
      if (referralCode.trim().isEmpty) return null;

      final querySnapshot = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: referralCode.toUpperCase())
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      final referrerDoc = querySnapshot.docs.first;
      final referrerData = referrerDoc.data();

      return {
        'referrerId': referrerDoc.id,
        'referrerName': referrerData['name'],
        'referrerMemberId': referrerData['memberId'],
        'referrerTier': referrerData['tier'],
      };
    } catch (e) {
      print('Error validating referral code: $e');
      return null;
    }
  }

  /// Process referral when new user registers with referral code (BRD requirement)
  Future<bool> processReferral({
    required String newUserId,
    required String referrerId,
    required String newUserTier,
    required double subscriptionFee,
  }) async {
    try {
      // Resolve referral code to actual user ID
      final referrerValidation = await validateReferralCode(referrerId);
      if (referrerValidation == null) return false;
      
      final actualReferrerId = referrerValidation['referrerId']!;
      final referralRevenue = subscriptionFee * 0.20; // 20% per BRD
      
      final batch = _firestore.batch();
      
      // Create referral record with PENDING status
      final referralRef = _firestore.collection('referrals').doc();
      batch.set(referralRef, {
        'referrerId': actualReferrerId,
        'referredUserId': newUserId,
        'referralCode': referrerId,
        'referralDate': FieldValue.serverTimestamp(),
        'tier': newUserTier,
        'subscriptionFee': subscriptionFee,
        'referralRevenue': referralRevenue,
        'revenueStatus': 'pending', // Will be paid after admin approval
        'status': 'pending', // Waiting for admin approval
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update referrer's PENDING stats only
      batch.update(_firestore.collection('users').doc(actualReferrerId), {
        'totalReferrals': FieldValue.increment(1),
        'pendingReferralRevenue': FieldValue.increment(referralRevenue),
        'referredUsers': FieldValue.arrayUnion([newUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update new user with referral info
      batch.update(_firestore.collection('users').doc(newUserId), {
        'isReferred': true,
        'recruiterId': referrerId, // Store the original referral code
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      
      // DO NOT add balance entry here - wait for admin approval
      
      return true;
    } catch (e) {
      print('Error processing referral: $e');
      return false;
    }
  }

  /// Process referral rewards after admin approves the referred user
  Future<bool> processReferralRewardAfterApproval(String referredUserId) async {
    try {
      print('Processing referral reward after admin approval for user: $referredUserId');
      
      // Find the referral record for this user
      final referralQuery = await _firestore
          .collection('referrals')
          .where('referredUserId', isEqualTo: referredUserId)
          .where('revenueStatus', isEqualTo: 'pending')
          .limit(1)
          .get();
      
      if (referralQuery.docs.isEmpty) {
        print('No pending referral found for user: $referredUserId');
        return false;
      }
      
      final referralDoc = referralQuery.docs.first;
      final referralData = referralDoc.data();
      final referrerId = referralData['referrerId'] as String;
      final referralRevenue = (referralData['referralRevenue'] ?? 0.0).toDouble();
      
      final batch = _firestore.batch();
      
      // Update referral record status
      batch.update(referralDoc.reference, {
        'revenueStatus': 'approved',
        'status': 'active',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Move from pending to paid revenue for referrer
      batch.update(_firestore.collection('users').doc(referrerId), {
        'pendingReferralRevenue': FieldValue.increment(-referralRevenue),
        'paidReferralRevenue': FieldValue.increment(referralRevenue),
        'referralEarnings': FieldValue.increment(referralRevenue), // Add to total earnings
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      
      // NOW add the balance entry after admin approval
      await _balanceService.addBalanceEntry(
        userId: referrerId,
        type: 'referralEarnings',
        amount: referralRevenue,
        description: 'Referral commission - member approved',
        expires: true,
        expiryDays: 90,
      );
      
      print('Successfully processed referral reward: ${referralRevenue} LE for referrer: $referrerId');
      
      // Log to referral history
      await _firestore.collection('referral_history').add({
        'referrerId': referrerId,
        'referredUserId': referredUserId,
        'referralEarnings': referralRevenue,
        'type': 'registration_referral',
        'status': 'paid',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('Error processing referral reward after approval: $e');
      return false;
    }
  }

  /// Process referral revenue after 90-day period (BRD requirement)
  Future<bool> processReferralRevenue(String referralId) async {
    try {
      final batch = _firestore.batch();

      // Get referral data
      final referralDoc = await _firestore
          .collection('referrals')
          .doc(referralId)
          .get();

      if (!referralDoc.exists) return false;

      final referralData = referralDoc.data()!;
      final referrerId = referralData['referrerId'];
      final revenue = referralData['referralRevenue'];
      final referredUserId = referralData['referredUserId'];

      // Add referral commission to referrer's balance using BalanceService (BRD compliant)
      await _balanceService.addBalanceEntry(
        userId: referrerId,
        type: 'referralEarnings',
        amount: revenue,
        description: 'Referral commission from user $referredUserId',
        expires: true,
        expiryDays: 90,
      );

      // Update referrer's balance tracking
      final referrerRef = _firestore.collection('users').doc(referrerId);
      batch.update(referrerRef, {
        'pendingReferralRevenue': FieldValue.increment(-revenue),
        'paidReferralRevenue': FieldValue.increment(revenue),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update referral status
      final referralRef = _firestore.collection('referrals').doc(referralId);
      batch.update(referralRef, {
        'revenueStatus': 'paid',
        'actualPayoutDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error processing referral revenue: $e');
      return false;
    }
  }

  /// Process referral revenue from borrow fees (within 90-day window per BRD)
  Future<bool> processReferralBorrowRevenue({
    required String referredUserId,
    required double borrowFee,
  }) async {
    try {
      final referredUserDoc = await _firestore
          .collection('users')
          .doc(referredUserId)
          .get();

      if (!referredUserDoc.exists) return false;

      final referredUserData = referredUserDoc.data()!;
      final recruiterCode = referredUserData['recruiterId']; // This is the referral code

      if (recruiterCode == null) return false;

      // Find the referrer using their referral code
      final referrerQuery = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: recruiterCode)
          .limit(1)
          .get();

      if (referrerQuery.docs.isEmpty) return false;

      final referrerId = referrerQuery.docs.first.id; // Actual referrer user ID

      // Check if referral is within 90-day revenue window (BRD requirement)
      final referralDocs = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: referrerId)
          .where('referredUserId', isEqualTo: referredUserId)
          .where('status', isEqualTo: 'active')
          .get();

      if (referralDocs.docs.isEmpty) return false;

      final referralData = referralDocs.docs.first.data();
      final referralDate = (referralData['referralDate'] as Timestamp).toDate();
      final daysSinceReferral = DateTime.now().difference(referralDate).inDays;

      if (daysSinceReferral > 90) return false; // Outside 90-day window

      final batch = _firestore.batch();
      final borrowReferralRevenue = borrowFee * 0.20; // 20% per BRD

      // Add borrow commission to referrer's balance using BalanceService (BRD compliant)
      await _balanceService.addBalanceEntry(
        userId: referrerId,
        type: 'referralEarnings',
        amount: borrowReferralRevenue,
        description: 'Borrow commission from referred user (${borrowFee} LE fee)',
        expires: true,
        expiryDays: 90,
      );

      // Update referrer's balance tracking
      final referrerRef = _firestore.collection('users').doc(referrerId);
      batch.update(referrerRef, {
        'totalReferralRevenue': FieldValue.increment(borrowReferralRevenue),
        'paidReferralRevenue': FieldValue.increment(borrowReferralRevenue),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update referral record
      final referralRef = _firestore
          .collection('referrals')
          .doc(referralDocs.docs.first.id);
      batch.update(referralRef, {
        'borrowCommissions': FieldValue.arrayUnion([
          {
            'amount': borrowReferralRevenue,
            'borrowFee': borrowFee,
            'date': FieldValue.serverTimestamp(),
          }
        ]),
        'totalBorrowCommissions': FieldValue.increment(borrowReferralRevenue),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error processing referral borrow revenue: $e');
      return false;
    }
  }

  /// Get user's referral statistics (BRD compliant)
  Future<Map<String, dynamic>> getReferralStats(String userId) async {
    try {
      print('=== getReferralStats DEBUG ===');
      print('getReferralStats called for userId: $userId');
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('User document does not exist for userId: $userId');
        return {
          'totalReferrals': 0,
          'totalRevenue': 0.0,
          'pendingRevenue': 0.0,
          'paidRevenue': 0.0,
          'referralCode': '',
          'referralHistory': [],
        };
      }

      final userData = userDoc.data()!;
      print('User data found:');
      print('  - name: ${userData['name']}');
      print('  - memberId: ${userData['memberId']}');
      print('  - existingCode: ${userData['referralCode']}');
      print('  - totalReferrals field: ${userData['totalReferrals']}');
      print('  - totalReferralRevenue field: ${userData['totalReferralRevenue']}');
      print('  - pendingReferralRevenue field: ${userData['pendingReferralRevenue']}');
      print('  - paidReferralRevenue field: ${userData['paidReferralRevenue']}');
      
      // Generate referral code if it doesn't exist
      String referralCode = userData['referralCode'] ?? '';
      if (referralCode.isEmpty) {
        final name = userData['name'] ?? '';
        final memberId = userData['memberId'] ?? '';
        print('Generating referral code for name: $name, memberId: $memberId');
        if (name.isNotEmpty && memberId.isNotEmpty) {
          referralCode = generateReferralCode(name, memberId);
          print('Generated referral code: $referralCode');
          // Update user document with generated referral code
          await _firestore.collection('users').doc(userId).update({
            'referralCode': referralCode,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('Updated user document with referral code');
        } else {
          print('Cannot generate referral code: name or memberId is empty');
        }
      } else {
        print('Using existing referral code: $referralCode');
      }
      
      // Get detailed referral data
      print('Querying referrals collection with referrerId: $userId');
      final referralDocs = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: userId)
          .get();

      print('Found ${referralDocs.docs.length} referral documents');
      final referralHistory = <Map<String, dynamic>>[];
      
      // Fetch member names for each referral
      for (final doc in referralDocs.docs) {
        final data = doc.data();
        final referredUserId = data['referredUserId'] as String?;
        
        print('  - Referral doc: ${doc.id}');
        print('    - referredUserId: $referredUserId');
        print('    - referralRevenue: ${data['referralRevenue']}');
        print('    - revenueStatus: ${data['revenueStatus']}');
        print('    - tier: ${data['tier']}');
        
        String memberName = 'Unknown Member';
        String memberStatus = 'pending';
        String actualRevenueStatus = data['revenueStatus'] ?? 'pending';
        
        if (referredUserId != null) {
          try {
            final memberDoc = await _firestore.collection('users').doc(referredUserId).get();
            if (memberDoc.exists) {
              final memberData = memberDoc.data()!;
              memberName = memberData['name'] ?? 'Unknown Member';
              memberStatus = memberData['status'] ?? 'pending';
              
              // If member is active but revenue status is still pending, update it
              if (memberStatus == 'active' && actualRevenueStatus == 'pending') {
                actualRevenueStatus = 'paid'; // Should be paid when member is active
                print('    - Member is active, revenue should be paid');
              }
            }
          } catch (e) {
            print('    - Error fetching member info: $e');
          }
        }
        
        referralHistory.add({
          'id': doc.id,
          'referredUserId': referredUserId,
          'memberName': memberName,
          'memberStatus': memberStatus,
          'referralDate': data['referralDate'],
          'revenue': data['referralRevenue'],
          'status': actualRevenueStatus, // Use the corrected status
          'originalRevenueStatus': data['revenueStatus'], // Keep original for reference
          'actualReferralStatus': 'approved', // The referral itself is always approved if it exists
          'tier': data['tier'],
          'borrowCommissions': data['borrowCommissions'] ?? [],
        });
      }

      // Recalculate pending and paid revenue based on actual member status
      double correctPendingRevenue = 0.0;
      double correctPaidRevenue = 0.0;
      double totalRevenue = 0.0;
      
      for (final referral in referralHistory) {
        final revenue = (referral['revenue'] ?? 0.0).toDouble();
        totalRevenue += revenue;
        
        if (referral['status'] == 'paid') {
          correctPaidRevenue += revenue;
        } else {
          correctPendingRevenue += revenue;
        }
      }
      
      print('Recalculated revenue:');
      print('  - totalRevenue: $totalRevenue');
      print('  - correctPendingRevenue: $correctPendingRevenue');
      print('  - correctPaidRevenue: $correctPaidRevenue');
      
      final result = {
        'totalReferrals': userData['totalReferrals'] ?? 0,
        'totalRevenue': totalRevenue,
        'pendingRevenue': correctPendingRevenue,
        'paidRevenue': correctPaidRevenue,
        'referralCode': referralCode,
        'referralHistory': referralHistory,
      };
      print('Final result: $result');
      print('=== END getReferralStats DEBUG ===');
      return result;
    } catch (e) {
      print('Error getting referral stats: $e');
      print('Stack trace: ${StackTrace.current}');
      return {
        'totalReferrals': 0,
        'totalRevenue': 0.0,
        'pendingRevenue': 0.0,
        'paidRevenue': 0.0,
        'referralCode': '',
        'referralHistory': [],
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
      final recruiterCode = userData['recruiterId']; // This is the referral code
      
      if (recruiterCode == null) return null;

      // Find the referrer using their referral code
      final referrerQuery = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: recruiterCode)
          .limit(1)
          .get();

      if (referrerQuery.docs.isEmpty) return null;

      final referrerDoc = referrerQuery.docs.first;
      final referrerData = referrerDoc.data();
      return {
        'id': referrerDoc.id,
        'name': referrerData['name'],
        'memberId': referrerData['memberId'],
        'tier': referrerData['tier'],
        'referralCode': recruiterCode,
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

  /// Initialize referral code for existing user (BRD requirement)
  Future<bool> initializeReferralCode(String userId, String name, String memberId) async {
    try {
      final referralCode = generateReferralCode(name, memberId);
      
      await _firestore.collection('users').doc(userId).update({
        'referralCode': referralCode,
        'totalReferrals': 0,
        'totalReferralRevenue': 0.0,
        'pendingReferralRevenue': 0.0,
        'paidReferralRevenue': 0.0,
        'referredUsers': [],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error initializing referral code: $e');
      return false;
    }
  }

  /// Process expired referral revenues (scheduled function per BRD)
  Future<void> processExpiredReferralRevenues() async {
    try {
      final pendingReferrals = await _firestore
          .collection('referrals')
          .where('revenueStatus', isEqualTo: 'pending')
          .where('payoutDate', isLessThanOrEqualTo: Timestamp.now())
          .get();

      for (final doc in pendingReferrals.docs) {
        await processReferralRevenue(doc.id);
      }
    } catch (e) {
      print('Error processing expired referral revenues: $e');
    }
  }

  /// Admin function to get comprehensive referral analytics (BRD requirement)
  Future<Map<String, dynamic>> getAdminReferralStats() async {
    try {
      final referralDocs = await _firestore.collection('referrals').get();
      
      double totalReferralRevenue = 0.0;
      double pendingReferralRevenue = 0.0;
      double paidReferralRevenue = 0.0;
      int totalReferrals = referralDocs.docs.length;
      
      final referralsByMonth = <String, int>{};
      final revenueByMonth = <String, double>{};

      for (final doc in referralDocs.docs) {
        final data = doc.data();
        final revenue = data['referralRevenue'] ?? 0.0;
        final status = data['revenueStatus'] ?? 'pending';
        
        totalReferralRevenue += revenue;
        if (status == 'pending') {
          pendingReferralRevenue += revenue;
        } else {
          paidReferralRevenue += revenue;
        }

        // Group by month for analytics
        final referralDate = (data['referralDate'] as Timestamp?)?.toDate();
        if (referralDate != null) {
          final monthKey = '${referralDate.year}-${referralDate.month.toString().padLeft(2, '0')}';
          referralsByMonth[monthKey] = (referralsByMonth[monthKey] ?? 0) + 1;
          revenueByMonth[monthKey] = (revenueByMonth[monthKey] ?? 0.0) + revenue;
        }
      }

      return {
        'totalReferrals': totalReferrals,
        'totalReferralRevenue': totalReferralRevenue,
        'pendingReferralRevenue': pendingReferralRevenue,
        'paidReferralRevenue': paidReferralRevenue,
        'referralsByMonth': referralsByMonth,
        'revenueByMonth': revenueByMonth,
        'adminRevenueShare': paidReferralRevenue, // 20% goes to admin balance per BRD
      };
    } catch (e) {
      print('Error getting admin referral stats: $e');
      return {};
    }
  }

  /// Update admin balance with referral revenue share (BRD requirement)
  Future<void> updateAdminReferralRevenue(double amount) async {
    try {
      // Get all admins and split referral revenue evenly
      final adminDocs = await _firestore
          .collection('users')
          .where('tier', isEqualTo: 'admin')
          .get();

      if (adminDocs.docs.isEmpty) return;

      final adminShare = amount / adminDocs.docs.length;
      final batch = _firestore.batch();

      for (final adminDoc in adminDocs.docs) {
        final adminRef = _firestore.collection('users').doc(adminDoc.id);
        batch.update(adminRef, {
          'adminNetIncome': FieldValue.increment(adminShare),
          'referralRevenue': FieldValue.increment(adminShare),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error updating admin referral revenue: $e');
    }
  }

  /// Process activity-based referral earnings (for borrows, contributions, etc.)
  Future<bool> processActivityReferralEarnings({
    required String userId,
    required double activityFee,
    required String activityType,
  }) async {
    return await processReferralBorrowRevenue(
      referredUserId: userId,
      borrowFee: activityFee,
    );
  }

  /// Get user's referral code, generate if doesn't exist
  Future<String> getUserReferralCode(String userId) async {
    try {
      print('getUserReferralCode called with userId: $userId');
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('User document not found');
        return '';
      }

      final userData = userDoc.data()!;
      String referralCode = userData['referralCode'] ?? '';
      print('Existing referral code: $referralCode');
      
      if (referralCode.isEmpty) {
        final name = userData['name'] ?? '';
        final memberId = userData['memberId'] ?? '';
        print('Generating code for name: $name, memberId: $memberId');
        if (name.isNotEmpty && memberId.isNotEmpty) {
          referralCode = generateReferralCode(name, memberId);
          print('Generated referral code: $referralCode');
          // Update user document with generated referral code
          await _firestore.collection('users').doc(userId).update({
            'referralCode': referralCode,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('Saved referral code to database');
        }
      }
      
      print('Returning referral code: $referralCode');
      return referralCode;
    } catch (e) {
      print('Error getting user referral code: $e');
      return '';
    }
  }

  String _generateBalanceEntryId() {
    return _firestore.collection('balance_entries').doc().id;
  }

  /// Update referral revenue status based on member status
  Future<bool> updateReferralRevenueStatus() async {
    try {
      print('=== UPDATING REFERRAL REVENUE STATUS ===');
      
      // Get all referral records with pending revenue status
      final pendingReferrals = await _firestore
          .collection('referrals')
          .where('revenueStatus', isEqualTo: 'pending')
          .get();
      
      print('Found ${pendingReferrals.docs.length} referrals with pending revenue');
      
      int updatedCount = 0;
      final batch = _firestore.batch();
      final List<Map<String, dynamic>> referralsToAddBalance = [];
      
      for (final referralDoc in pendingReferrals.docs) {
        final referralData = referralDoc.data();
        final referredUserId = referralData['referredUserId'] as String?;
        final referrerId = referralData['referrerId'] as String?;
        final referralRevenue = (referralData['referralRevenue'] ?? 0.0).toDouble();
        
        if (referredUserId == null || referrerId == null) continue;
        
        // Check if the referred member is now active
        final memberDoc = await _firestore.collection('users').doc(referredUserId).get();
        if (memberDoc.exists) {
          final memberData = memberDoc.data()!;
          final memberStatus = memberData['status'] ?? 'pending';
          
          if (memberStatus == 'active') {
            print('  - Updating referral ${referralDoc.id}: member $referredUserId is active');
            print('  - Referrer: $referrerId, Revenue: $referralRevenue LE');
            
            // Update referral record
            batch.update(referralDoc.reference, {
              'revenueStatus': 'paid',
              'actualPayoutDate': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            
            // Update referrer's balance tracking (remove from pending, add to paid)
            batch.update(_firestore.collection('users').doc(referrerId), {
              'pendingReferralRevenue': FieldValue.increment(-referralRevenue),
              'paidReferralRevenue': FieldValue.increment(referralRevenue),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            
            print('  - Updated referral record and balance tracking');
            
            // Store referral info for balance entry creation after batch
            referralsToAddBalance.add({
              'referrerId': referrerId,
              'revenue': referralRevenue,
              'referredUserId': referredUserId,
            });
            
            updatedCount++;
          }
        }
      }
      
      if (updatedCount > 0) {
        await batch.commit();
        print('Updated $updatedCount referral revenue statuses');
        
        // Now add balance entries using BalanceService (after batch is committed)
        print('Adding balance entries for ${referralsToAddBalance.length} referrals');
        for (final referralInfo in referralsToAddBalance) {
          try {
            final result = await _balanceService.addBalanceEntry(
              userId: referralInfo['referrerId'],
              type: 'referralEarnings',
              amount: referralInfo['revenue'],
              description: 'Referral commission from approved member',
              expires: true,
              expiryDays: 90,
            );
            print('  - Added balance entry for ${referralInfo['referrerId']}: ${result['success']}');
          } catch (e) {
            print('  - Error adding balance entry for ${referralInfo['referrerId']}: $e');
          }
        }
        print('Completed balance entry additions');
      } else {
        print('No referral revenue statuses needed updating');
      }
      
      print('=== END UPDATING REFERRAL REVENUE STATUS ===');
      return true;
    } catch (e) {
      print('Error updating referral revenue status: $e');
      return false;
    }
  }

  /// Diagnostic function to analyze referral issues for a specific user
  Future<void> diagnoseReferralIssue(String referrerId) async {
    try {
      print('=== REFERRAL DIAGNOSIS FOR USER: $referrerId ===');
      
      // 1. Check user's referral stats
      final userDoc = await _firestore.collection('users').doc(referrerId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        print('User Referral Stats:');
        print('  - referralCode: ${userData['referralCode']}');
        print('  - totalReferrals: ${userData['totalReferrals']}');
        print('  - totalReferralRevenue: ${userData['totalReferralRevenue']}');
        print('  - pendingReferralRevenue: ${userData['pendingReferralRevenue']}');
        print('  - paidReferralRevenue: ${userData['paidReferralRevenue']}');
        print('  - referralEarnings: ${userData['referralEarnings']}');
        print('  - balanceEntries count: ${(userData['balanceEntries'] ?? []).length}');
        
        // Check for referral balance entries
        final balanceEntries = List<Map<String, dynamic>>.from(userData['balanceEntries'] ?? []);
        final referralEntries = balanceEntries.where((e) => e['type'] == 'referralEarnings').toList();
        print('  - Referral balance entries: ${referralEntries.length}');
        for (var entry in referralEntries) {
          print('    - Amount: ${entry['amount']}, Expired: ${entry['isExpired']}');
        }
      }
      
      // 2. Check referral records
      print('\nReferral Records:');
      final referralDocs = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: referrerId)
          .get();
      
      print('Found ${referralDocs.docs.length} referral records');
      for (var doc in referralDocs.docs) {
        final data = doc.data();
        print('  Referral ${doc.id}:');
        print('    - referredUserId: ${data['referredUserId']}');
        print('    - revenueStatus: ${data['revenueStatus']}');
        print('    - status: ${data['status']}');
        print('    - referralRevenue: ${data['referralRevenue']}');
        print('    - subscriptionFee: ${data['subscriptionFee']}');
        
        // Check the referred user's status
        final referredUserDoc = await _firestore
            .collection('users')
            .doc(data['referredUserId'])
            .get();
        if (referredUserDoc.exists) {
          final referredData = referredUserDoc.data()!;
          print('    - Referred user status: ${referredData['status']}');
          print('    - Referred user tier: ${referredData['tier']}');
        }
      }
      
      print('=== END DIAGNOSIS ===');
    } catch (e) {
      print('Error in diagnosis: $e');
    }
  }

  /// Comprehensive diagnosis of all referral system inconsistencies
  Future<void> comprehensiveDiagnosis() async {
    try {
      print('=== COMPREHENSIVE REFERRAL SYSTEM DIAGNOSIS ===');
      
      // 1. Check all users for referral data inconsistencies
      final usersSnapshot = await _firestore.collection('users').get();
      
      print('\n1. USERS WITH REFERRAL DATA:');
      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final recruiterId = userData['recruiterId'];
        
        if (recruiterId != null && recruiterId.toString().isNotEmpty) {
          print('\nUser: ${userDoc.id} (${userData['name']})');
          print('  - recruiterId value: "$recruiterId"');
          print('  - recruiterId type: ${recruiterId.runtimeType}');
          print('  - Is Firebase UID format: ${recruiterId.toString().length > 20}');
          print('  - Is referral code format: ${RegExp(r'^[A-Z]{3}\d{3}$').hasMatch(recruiterId.toString())}');
          print('  - referralCode: ${userData['referralCode']}');
          print('  - referralEarnings: ${userData['referralEarnings'] ?? 0}');
          print('  - Balance entries with referralEarnings: ${(userData['balanceEntries'] ?? []).where((e) => e['type'] == 'referralEarnings').length}');
        }
      }
      
      // 2. Check all referral records
      print('\n2. REFERRAL RECORDS:');
      final referralsSnapshot = await _firestore.collection('referrals').get();
      
      for (var refDoc in referralsSnapshot.docs) {
        final refData = refDoc.data();
        print('\nReferral: ${refDoc.id}');
        print('  - referrerId: ${refData['referrerId']}');
        print('  - Is Firebase UID: ${refData['referrerId'].toString().length > 20}');
        print('  - referredUserId: ${refData['referredUserId']}');
        print('  - referralRevenue: ${refData['referralRevenue']}');
        print('  - revenueStatus: ${refData['revenueStatus']}');
        print('  - status: ${refData['status']}');
        
        // Check if referrer exists
        if (refData['referrerId'].toString().length > 20) {
          final referrerExists = (await _firestore.collection('users').doc(refData['referrerId']).get()).exists;
          print('  - Referrer exists in users: $referrerExists');
        } else {
          // It's a referral code, find the user
          final userQuery = await _firestore
              .collection('users')
              .where('referralCode', isEqualTo: refData['referrerId'])
              .get();
          print('  - Users with this referral code: ${userQuery.docs.length}');
          if (userQuery.docs.isNotEmpty) {
            print('  - Actual referrer UID: ${userQuery.docs.first.id}');
          }
        }
      }
      
      print('\n=== END DIAGNOSIS ===');
    } catch (e) {
      print('Diagnosis error: $e');
    }
  }

  /// Complete referral system fix - handles all inconsistencies
  Future<Map<String, dynamic>> completeReferralSystemFix() async {
    try {
      print('=== STARTING COMPLETE REFERRAL SYSTEM FIX ===');
      
      int fixedUsers = 0;
      int fixedReferrals = 0;
      int createdBalanceEntries = 0;
      double totalBalanceAdded = 0;
      
      // Step 1: Create a mapping of referral codes to user IDs
      print('\nStep 1: Building referral code mapping...');
      final Map<String, String> referralCodeToUserId = {};
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final referralCode = userData['referralCode'];
        if (referralCode != null && referralCode.toString().isNotEmpty) {
          referralCodeToUserId[referralCode] = userDoc.id;
          print('  Mapped: $referralCode -> ${userDoc.id}');
        }
      }
      
      // Step 2: Fix all users with referral code in recruiterId field
      print('\nStep 2: Fixing user documents...');
      final batch1 = _firestore.batch();
      int batchCount = 0;
      
      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final recruiterId = userData['recruiterId'];
        
        if (recruiterId != null && recruiterId.toString().isNotEmpty) {
          // Check if it's a referral code (not a Firebase UID)
          if (RegExp(r'^[A-Z]{3}\d{3}$').hasMatch(recruiterId.toString())) {
            print('  Found user with referral code in recruiterId: ${userDoc.id}');
            
            // Find the actual referrer UID
            final actualReferrerId = referralCodeToUserId[recruiterId];
            
            if (actualReferrerId != null) {
              print('    Converting $recruiterId -> $actualReferrerId');
              
              // Update to store BOTH for backward compatibility
              batch1.update(userDoc.reference, {
                'recruiterId': actualReferrerId, // Store actual Firebase UID
                'recruiterCode': recruiterId, // Keep the original code
                'fixedAt': FieldValue.serverTimestamp(),
              });
              
              fixedUsers++;
              batchCount++;
              
              if (batchCount >= 400) {
                await batch1.commit();
                batchCount = 0;
              }
            }
          }
        }
      }
      
      if (batchCount > 0) {
        await batch1.commit();
      }
      
      // Step 3: Fix all referral records
      print('\nStep 3: Fixing referral records...');
      final referralsSnapshot = await _firestore.collection('referrals').get();
      final batch2 = _firestore.batch();
      batchCount = 0;
      
      for (var refDoc in referralsSnapshot.docs) {
        final refData = refDoc.data();
        final referrerId = refData['referrerId'];
        
        // Check if it's a referral code
        if (referrerId != null && RegExp(r'^[A-Z]{3}\d{3}$').hasMatch(referrerId.toString())) {
          final actualReferrerId = referralCodeToUserId[referrerId];
          
          if (actualReferrerId != null) {
            print('  Fixing referral record: ${refDoc.id}');
            print('    Converting referrerId: $referrerId -> $actualReferrerId');
            
            batch2.update(refDoc.reference, {
              'referrerId': actualReferrerId,
              'originalReferralCode': referrerId,
              'fixedAt': FieldValue.serverTimestamp(),
            });
            
            fixedReferrals++;
            batchCount++;
            
            if (batchCount >= 400) {
              await batch2.commit();
              batchCount = 0;
            }
          }
        }
      }
      
      if (batchCount > 0) {
        await batch2.commit();
      }
      
      // Step 4: Process all approved referrals that don't have balance entries
      print('\nStep 4: Creating missing balance entries...');
      
      // Re-fetch referrals after fixes
      final fixedReferralsSnapshot = await _firestore.collection('referrals').get();
      
      for (var refDoc in fixedReferralsSnapshot.docs) {
        final refData = refDoc.data();
        final referrerId = refData['referrerId'];
        final referredUserId = refData['referredUserId'];
        final revenueStatus = refData['revenueStatus'];
        final referralRevenue = (refData['referralRevenue'] ?? 0.0).toDouble();
        
        if (referrerId == null || referredUserId == null) continue;
        
        // Check if referred user is active
        final referredUserDoc = await _firestore.collection('users').doc(referredUserId).get();
        if (!referredUserDoc.exists) continue;
        
        final referredUserData = referredUserDoc.data()!;
        final userStatus = referredUserData['status'];
        
        // If user is active but revenue not yet paid
        if (userStatus == 'active' && revenueStatus != 'paid' && referralRevenue > 0) {
          print('  Processing referral for active user: $referredUserId');
          print('    Referrer: $referrerId, Revenue: $referralRevenue LE');
          
          // Get referrer document
          final referrerDoc = await _firestore.collection('users').doc(referrerId).get();
          if (!referrerDoc.exists) {
            print('    ERROR: Referrer not found!');
            continue;
          }
          
          // Check if balance entry already exists
          final referrerData = referrerDoc.data()!;
          final balanceEntries = List<Map<String, dynamic>>.from(
            referrerData['balanceEntries'] ?? []
          );
          
          bool hasEntry = balanceEntries.any((entry) => 
            entry['type'] == 'referralEarnings' &&
            (entry['description']?.contains('approved') == true ||
             entry['description']?.contains(referredUserId) == true)
          );
          
          if (!hasEntry) {
            print('    Creating balance entry...');
            
            // Create the balance entry using BalanceService
            await _balanceService.addBalanceEntry(
              userId: referrerId,
              type: 'referralEarnings',
              amount: referralRevenue,
              description: 'Referral commission - member approved (fixed)',
              expires: true,
              expiryDays: 90,
            );
            
            // Update referral record
            await refDoc.reference.update({
              'revenueStatus': 'paid',
              'status': 'active',
              'paidAt': FieldValue.serverTimestamp(),
              'fixedAt': FieldValue.serverTimestamp(),
            });
            
            // Update referrer's revenue tracking
            await _firestore.collection('users').doc(referrerId).update({
              'pendingReferralRevenue': FieldValue.increment(-referralRevenue),
              'paidReferralRevenue': FieldValue.increment(referralRevenue),
              'referralEarnings': FieldValue.increment(referralRevenue),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            
            createdBalanceEntries++;
            totalBalanceAdded += referralRevenue;
            print('    SUCCESS: Balance entry created!');
          } else {
            print('    Balance entry already exists');
            
            // Just update the referral status
            await refDoc.reference.update({
              'revenueStatus': 'paid',
              'status': 'active',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
      
      print('\n=== FIX COMPLETE ===');
      print('Results:');
      print('  - Fixed users: $fixedUsers');
      print('  - Fixed referral records: $fixedReferrals');
      print('  - Created balance entries: $createdBalanceEntries');
      print('  - Total balance added: $totalBalanceAdded LE');
      
      return {
        'success': true,
        'fixedUsers': fixedUsers,
        'fixedReferrals': fixedReferrals,
        'createdBalanceEntries': createdBalanceEntries,
        'totalBalanceAdded': totalBalanceAdded,
        'message': 'Fixed $fixedUsers users, $fixedReferrals referrals, created $createdBalanceEntries balance entries totaling ${totalBalanceAdded.toStringAsFixed(2)} LE',
      };
    } catch (e) {
      print('Error in complete fix: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Fix missing referral balance entries for approved users
  Future<Map<String, dynamic>> fixMissingReferralBalances() async {
    try {
      print('=== FIXING MISSING REFERRAL BALANCES ===');
      int fixedCount = 0;
      double totalFixed = 0;
      
      // Get all referral records
      final referralDocs = await _firestore
          .collection('referrals')
          .get();
      
      for (var referralDoc in referralDocs.docs) {
        final referralData = referralDoc.data();
        final referrerId = referralData['referrerId'] as String?;
        final referredUserId = referralData['referredUserId'] as String?;
        final revenueStatus = referralData['revenueStatus'] as String?;
        final referralRevenue = (referralData['referralRevenue'] ?? 0.0).toDouble();
        
        if (referrerId == null || referredUserId == null) continue;
        
        // Check if referred user is active/approved
        final referredUserDoc = await _firestore
            .collection('users')
            .doc(referredUserId)
            .get();
        
        if (!referredUserDoc.exists) continue;
        
        final referredUserData = referredUserDoc.data()!;
        final userStatus = referredUserData['status'] ?? 'pending';
        
        // If user is active but referral revenue is still pending
        if (userStatus == 'active' && revenueStatus == 'pending') {
          print('Found pending referral for active user:');
          print('  - Referral ID: ${referralDoc.id}');
          print('  - Referrer: $referrerId');
          print('  - Referred User: $referredUserId');
          print('  - Revenue: $referralRevenue LE');
          
          // Check if balance entry already exists
          final referrerDoc = await _firestore.collection('users').doc(referrerId).get();
          if (referrerDoc.exists) {
            final referrerData = referrerDoc.data()!;
            final balanceEntries = List<Map<String, dynamic>>.from(
              referrerData['balanceEntries'] ?? []
            );
            
            // Check if this referral already has a balance entry
            bool hasEntry = balanceEntries.any((entry) => 
              entry['description']?.contains(referredUserId) == true &&
              entry['type'] == 'referralEarnings'
            );
            
            if (!hasEntry) {
              print('  - Creating missing balance entry...');
              
              // Create the balance entry
              await _balanceService.addBalanceEntry(
                userId: referrerId,
                type: 'referralEarnings',
                amount: referralRevenue,
                description: 'Referral commission (fixed) - $referredUserId',
                expires: true,
                expiryDays: 90,
              );
              
              // Update referral record
              await referralDoc.reference.update({
                'revenueStatus': 'paid',
                'status': 'active',
                'fixedAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              
              // Update user's revenue tracking
              await _firestore.collection('users').doc(referrerId).update({
                'pendingReferralRevenue': FieldValue.increment(-referralRevenue),
                'paidReferralRevenue': FieldValue.increment(referralRevenue),
                'referralEarnings': FieldValue.increment(referralRevenue),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              
              fixedCount++;
              totalFixed += referralRevenue;
              print('  - Fixed successfully!');
            } else {
              print('  - Balance entry already exists, updating status only');
              
              // Just update the referral status
              await referralDoc.reference.update({
                'revenueStatus': 'paid',
                'status': 'active',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }
      
      print('=== FIX COMPLETE ===');
      print('Fixed $fixedCount referrals, total amount: $totalFixed LE');
      
      return {
        'success': true,
        'fixedCount': fixedCount,
        'totalAmount': totalFixed,
        'message': 'Fixed $fixedCount missing referral balances totaling $totalFixed LE',
      };
    } catch (e) {
      print('Error fixing referral balances: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Fix existing referral records that may have wrong referrerId
  Future<bool> fixExistingReferralRecords() async {
    try {
      print('=== FIXING EXISTING REFERRAL RECORDS ===');
      
      // Get all referral records
      final referralsQuery = await _firestore.collection('referrals').get();
      print('Found ${referralsQuery.docs.length} referral records to check');
      
      int fixedCount = 0;
      final batch = _firestore.batch();
      
      for (final referralDoc in referralsQuery.docs) {
        final referralData = referralDoc.data();
        final referrerId = referralData['referrerId'] as String?;
        final referredUserId = referralData['referredUserId'] as String?;
        
        if (referrerId == null || referredUserId == null) continue;
        
        // Check if referrerId looks like a referral code (6 characters, alphanumeric)
        if (referrerId.length == 6 && RegExp(r'^[A-Z0-9]{6}$').hasMatch(referrerId)) {
          print('Found referral record with referral code as referrerId: $referrerId');
          
          // Find the actual user with this referral code
          final userQuery = await _firestore
              .collection('users')
              .where('referralCode', isEqualTo: referrerId)
              .limit(1)
              .get();
          
          if (userQuery.docs.isNotEmpty) {
            final actualReferrerId = userQuery.docs.first.id;
            print('  - Fixing: referral code $referrerId -> actual user ID $actualReferrerId');
            
            batch.update(referralDoc.reference, {
              'referrerId': actualReferrerId,
              'originalReferralCode': referrerId, // Keep the original for reference
              'fixedAt': FieldValue.serverTimestamp(),
            });
            
            fixedCount++;
            
            // Also update the referrer's stats if needed
            final referrerData = userQuery.docs.first.data();
            final currentTotalReferrals = (referrerData['totalReferrals'] ?? 0) as int;
            final referralRevenue = referralData['referralRevenue'] ?? 0.0;
            
            // Check if this referral is already counted
            final referralDate = referralData['referralDate'] as Timestamp?;
            print('  - Updating referrer stats for user $actualReferrerId');
            
            batch.update(_firestore.collection('users').doc(actualReferrerId), {
              'totalReferrals': FieldValue.increment(1),
              'totalReferralRevenue': FieldValue.increment(referralRevenue),
              'pendingReferralRevenue': FieldValue.increment(referralRevenue),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
      
      if (fixedCount > 0) {
        await batch.commit();
        print('Fixed $fixedCount referral records');
      } else {
        print('No referral records needed fixing');
      }
      
      print('=== END FIXING EXISTING REFERRAL RECORDS ===');
      return true;
    } catch (e) {
      print('Error fixing existing referral records: $e');
      return false;
    }
  }
}