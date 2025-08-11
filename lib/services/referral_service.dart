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
      print('=== processReferral DEBUG ===');
      print('Processing referral:');
      print('  - newUserId: $newUserId');
      print('  - referrerId (referral code): $referrerId');
      print('  - newUserTier: $newUserTier');
      print('  - subscriptionFee: $subscriptionFee');
      
      // First, resolve the referral code to actual user ID
      final referrerValidation = await validateReferralCode(referrerId);
      if (referrerValidation == null) {
        print('Invalid referral code: $referrerId');
        return false;
      }
      
      final actualReferrerId = referrerValidation['referrerId']!;
      print('  - resolved actual referrerId: $actualReferrerId');
      
      final batch = _firestore.batch();
      
      // Calculate 20% referral revenue (BRD requirement)
      final referralRevenue = subscriptionFee * 0.20;
      print('  - calculated referralRevenue: $referralRevenue');

      // 1. Create referral record for tracking
      final referralRef = _firestore.collection('referrals').doc();
      print('Creating referral record with ID: ${referralRef.id}');
      final referralData = {
        'id': referralRef.id,
        'referrerId': actualReferrerId,
        'referredUserId': newUserId,
        'referralDate': FieldValue.serverTimestamp(),
        'subscriptionFee': subscriptionFee,
        'referralRevenue': referralRevenue,
        'status': 'active',
        'revenueStatus': 'pending', // Will be processed after 90 days (BRD requirement)
        'payoutDate': Timestamp.fromDate(
          DateTime.now().add(Duration(days: 90))
        ),
        'tier': newUserTier,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      print('Referral data: $referralData');
      batch.set(referralRef, referralData);

      // 2. Update referrer's stats
      print('Updating referrer stats for: $actualReferrerId');
      final referrerRef = _firestore.collection('users').doc(actualReferrerId);
      final referrerUpdates = {
        'totalReferrals': FieldValue.increment(1),
        'totalReferralRevenue': FieldValue.increment(referralRevenue),
        'pendingReferralRevenue': FieldValue.increment(referralRevenue),
        'referredUsers': FieldValue.arrayUnion([newUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      print('Referrer updates: $referrerUpdates');
      batch.update(referrerRef, referrerUpdates);

      // 3. Update new user with referrer info (Note: this should store referral code, not user ID)
      print('Updating new user referrer info: $newUserId');
      final newUserRef = _firestore.collection('users').doc(newUserId);
      final newUserUpdates = {
        'isReferred': true,
        'recruiterId': referrerId, // Store the original referral code
        'updatedAt': FieldValue.serverTimestamp(),
      };
      print('New user updates: $newUserUpdates');
      batch.update(newUserRef, newUserUpdates);

      print('Committing referral batch operations...');
      await batch.commit();
      print('Referral processing completed successfully');
      print('=== END processReferral DEBUG ===');
      return true;
    } catch (e) {
      print('Error processing referral: $e');
      print('Stack trace: ${StackTrace.current}');
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