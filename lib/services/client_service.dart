// lib/services/client_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'referral_service.dart';

class ClientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ReferralService _referralService = ReferralService();
  
  // Process new client membership
  Future<Map<String, dynamic>> processClientMembership({
    required String userId,
    required double membershipFee,
    String? referrerCode,
  }) async {
    try {
      if (membershipFee != 750) {
        return {
          'success': false,
          'message': 'Client membership fee must be 750 LE',
        };
      }
      
      // Calculate client benefits
      final stationLimit = 4 * 750; // 3000 LE station limit
      
      final batch = _firestore.batch();
      
      // Update user to client tier
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'tier': 'client',
        'stationLimit': stationLimit,
        'remainingStationLimit': stationLimit,
        'borrowLimit': 10, // Can borrow up to 10 games per cycle
        'freeborrowings': 5, // First 5 borrows from member games are free
        'totalBorrowsCount': 0,
        'clientMembershipDate': FieldValue.serverTimestamp(),
        'clientCycleNumber': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Log membership payment
      batch.set(_firestore.collection('payment_history').doc(), {
        'userId': userId,
        'type': 'client_membership',
        'amount': membershipFee,
        'cycleNumber': 1,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      
      // Process referral if applicable
      if (referrerCode != null && referrerCode.isNotEmpty) {
        await _referralService.processReferral(
          newUserId: userId,
          referralCode: referrerCode,
          membershipFee: membershipFee,
          userTier: 'client',
        );
      }
      
      return {
        'success': true,
        'message': 'Client membership activated',
        'stationLimit': stationLimit,
        'borrowLimit': 10,
        'freeborrowings': 5,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
  
  // Check if client needs renewal
  Future<Map<String, dynamic>> checkClientRenewal(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {'success': false, 'message': 'User not found'};
      }
      
      final userData = userDoc.data()!;
      
      if (userData['tier'] != 'client') {
        return {'success': false, 'message': 'Not a client user'};
      }
      
      final totalBorrows = userData['totalBorrowsCount'] ?? 0;
      final borrowLimit = 10;
      
      if (totalBorrows >= borrowLimit) {
        return {
          'success': true,
          'needsRenewal': true,
          'message': 'Client membership renewal required (750 LE)',
          'currentCycle': userData['clientCycleNumber'] ?? 1,
          'totalBorrowsUsed': totalBorrows,
        };
      }
      
      return {
        'success': true,
        'needsRenewal': false,
        'borrowsRemaining': borrowLimit - totalBorrows,
        'freeborrowingsRemaining': userData['freeborrowings'] ?? 0,
        'currentCycle': userData['clientCycleNumber'] ?? 1,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
  
  // Process client renewal
  Future<Map<String, dynamic>> renewClientMembership({
    required String userId,
    required double renewalFee,
  }) async {
    try {
      if (renewalFee != 750) {
        return {
          'success': false,
          'message': 'Renewal fee must be 750 LE',
        };
      }
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {'success': false, 'message': 'User not found'};
      }
      
      final userData = userDoc.data()!;
      final currentCycle = (userData['clientCycleNumber'] ?? 1) + 1;
      
      final batch = _firestore.batch();
      
      // Reset client borrowing metrics
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'totalBorrowsCount': 0, // Reset borrow count for new cycle
        'freeborrowings': 5, // Reset free borrows
        'borrowLimit': 10,
        'clientCycleNumber': currentCycle,
        'lastRenewalDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Log renewal payment
      batch.set(_firestore.collection('payment_history').doc(), {
        'userId': userId,
        'type': 'client_renewal',
        'amount': renewalFee,
        'cycleNumber': currentCycle,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      
      // Process referral earnings for the referrer
      if (userData['recruiterId'] != null) {
        await _referralService.processActivityReferralEarnings(
          userId: userId,
          transactionAmount: renewalFee,
          activityType: 'client_renewal',
          activityDescription: 'Client membership renewal',
        );
      }
      
      return {
        'success': true,
        'message': 'Client membership renewed successfully',
        'newCycle': currentCycle,
        'borrowsAvailable': 10,
        'freeborrowings': 5,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}