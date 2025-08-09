// lib/services/metrics_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class MetricsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Update lending metrics when game is borrowed
  Future<void> updateLendingMetrics({
    required String lenderId,
    required double lendingValue,
    required bool isPaidLending,
  }) async {
    try {
      final updates = {
        'netLending': FieldValue.increment(
          isPaidLending ? lendingValue : -lendingValue
        ),
        'netExchange': FieldValue.increment(lendingValue),
        'totalLendings': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (isPaidLending) {
        updates['paidLendings'] = FieldValue.increment(1);
      } else {
        updates['freeLendings'] = FieldValue.increment(1);
      }
      
      await _firestore.collection('users').doc(lenderId).update(updates);
    } catch (e) {
      print('Error updating lending metrics: $e');
    }
  }
  
  // Update borrowing metrics
  Future<void> updateBorrowingMetrics({
    required String borrowerId,
    required double borrowValue,
    required bool isPaidBorrowing,
    required DateTime borrowDate,
  }) async {
    try {
      final updates = {
        'netBorrowings': FieldValue.increment(
          isPaidBorrowing ? borrowValue : -borrowValue
        ),
        'netExchange': FieldValue.increment(-borrowValue),
        'lastBorrowDate': Timestamp.fromDate(borrowDate),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (isPaidBorrowing) {
        updates['paidBorrows'] = FieldValue.increment(1);
      } else {
        updates['freeBorrows'] = FieldValue.increment(1);
      }
      
      await _firestore.collection('users').doc(borrowerId).update(updates);
    } catch (e) {
      print('Error updating borrowing metrics: $e');
    }
  }
  
  // Calculate and update average hold period when game is returned
  Future<void> updateAverageHoldPeriod({
    required String userId,
    required int daysHeld,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      
      final currentAverage = (userData['averageHoldPeriod'] ?? 0).toDouble();
      final totalBorrows = (userData['totalBorrowsCount'] ?? 1).toDouble();
      
      // Calculate new average
      final newAverage = totalBorrows == 1 
        ? daysHeld.toDouble()
        : ((currentAverage * (totalBorrows - 1)) + daysHeld) / totalBorrows;
      
      await _firestore.collection('users').doc(userId).update({
        'averageHoldPeriod': newAverage,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating average hold period: $e');
    }
  }
  
  // Determine if transaction is paid or free
  bool isFreeBorrow({
    required String borrowerTier,
    required String lenderTier,
    required int freeborrowingsRemaining,
  }) {
    // Members borrow free from member games
    if (borrowerTier == 'member' && lenderTier == 'member') {
      return true;
    }
    
    // Clients get first 5 free from member games
    if (borrowerTier == 'client' && 
        lenderTier == 'member' && 
        freeborrowingsRemaining > 0) {
      return true;
    }
    
    // VIP members borrow free from member games
    if (borrowerTier == 'vip' && lenderTier == 'member') {
      return true;
    }
    
    // All other cases are paid
    return false;
  }
  
  // Update metrics when borrow is approved (call from borrow_service)
  Future<void> processBorrowMetrics({
    required String borrowerId,
    required String? lenderId,
    required String borrowerTier,
    required String lenderTier,
    required double borrowValue,
    required int freeborrowingsRemaining,
  }) async {
    try {
      final isFree = isFreeBorrow(
        borrowerTier: borrowerTier,
        lenderTier: lenderTier,
        freeborrowingsRemaining: freeborrowingsRemaining,
      );
      
      // Update borrower metrics
      await updateBorrowingMetrics(
        borrowerId: borrowerId,
        borrowValue: borrowValue,
        isPaidBorrowing: !isFree,
        borrowDate: DateTime.now(),
      );
      
      // Update lender metrics if different from borrower
      if (lenderId != null && lenderId != borrowerId) {
        await updateLendingMetrics(
          lenderId: lenderId,
          lendingValue: borrowValue,
          isPaidLending: !isFree,
        );
      }
    } catch (e) {
      print('Error processing borrow metrics: $e');
    }
  }
}