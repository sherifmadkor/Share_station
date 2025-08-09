// lib/services/selling_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'balance_service.dart';

class SellingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BalanceService _balanceService = BalanceService();
  
  // Initiate game sale
  Future<Map<String, dynamic>> sellContributedGame({
    required String userId,
    required String gameId,
    required String accountId,
    required double salePrice,
  }) async {
    try {
      final batch = _firestore.batch();
      
      // Get game details
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      
      if (!gameDoc.exists) {
        return {'success': false, 'message': 'Game not found'};
      }
      
      final gameData = gameDoc.data()!;
      
      // Verify user is the contributor
      final accounts = List<Map<String, dynamic>>.from(gameData['accounts'] ?? []);
      final userAccount = accounts.firstWhere(
        (acc) => acc['accountId'] == accountId && acc['contributorId'] == userId,
        orElse: () => {},
      );
      
      if (userAccount.isEmpty) {
        return {'success': false, 'message': 'You are not the contributor of this account'};
      }
      
      // Calculate sell value (90% of sale price)
      final sellValue = salePrice * 0.9;
      final adminFee = salePrice * 0.1;
      
      // Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data()!;
      
      // Calculate share impact based on account type
      double shareDeduction = 0;
      final accountType = userAccount['sharingOptions']?[0] ?? 'primary';
      if (accountType == 'secondary') {
        shareDeduction = 0.5;
      } else if (accountType == 'psPlus') {
        shareDeduction = 2.0;
      } else {
        shareDeduction = 1.0;
      }
      
      // Update user metrics
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'sellValue': FieldValue.increment(sellValue),
        'stationLimit': FieldValue.increment(-(userAccount['gameValue'] ?? 0)),
        'remainingStationLimit': FieldValue.increment(-(userAccount['gameValue'] ?? 0)),
        'gameShares': FieldValue.increment(-shareDeduction),
        'totalShares': FieldValue.increment(-shareDeduction),
        'lastActivityDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Remove account from game
      accounts.removeWhere((acc) => acc['accountId'] == accountId);
      
      if (accounts.isEmpty) {
        // No more accounts, remove game entirely
        batch.delete(gameDoc.reference);
      } else {
        // Update game with remaining accounts
        batch.update(gameDoc.reference, {
          'accounts': accounts,
          'totalAccounts': accounts.length,
          'availableAccounts': accounts.where((a) => a['isAvailable'] != false).length,
          'totalValue': accounts.fold(0.0, (sum, acc) => sum + (acc['gameValue'] ?? 0)),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Log sale transaction
      batch.set(_firestore.collection('sales_history').doc(), {
        'userId': userId,
        'userName': userData['name'],
        'gameId': gameId,
        'gameTitle': gameData['title'],
        'accountId': accountId,
        'accountType': accountType,
        'salePrice': salePrice,
        'sellValue': sellValue,
        'adminFee': adminFee,
        'shareDeduction': shareDeduction,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Update admin revenue
      batch.update(_firestore.collection('admin').doc('revenue'), {
        'totalSalesFees': FieldValue.increment(adminFee),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      
      // Add balance entry (expires in 90 days)
      await _balanceService.addBalanceEntry(
        userId: userId,
        type: 'sellValue',
        amount: sellValue,
        description: 'Sale of ${gameData['title']} ($accountType account)',
        expires: true,
      );
      
      return {
        'success': true,
        'message': 'Game sold successfully. ${sellValue.toStringAsFixed(0)} LE added to balance.',
        'sellValue': sellValue,
        'adminFee': adminFee,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
  
  // Get user's sellable games
  Future<List<Map<String, dynamic>>> getUserSellableGames(String userId) async {
    try {
      final gamesSnapshot = await _firestore.collection('games').get();
      List<Map<String, dynamic>> sellableGames = [];
      
      for (var doc in gamesSnapshot.docs) {
        final gameData = doc.data();
        final accounts = List<Map<String, dynamic>>.from(gameData['accounts'] ?? []);
        
        // Find user's accounts
        final userAccounts = accounts.where((acc) => 
          acc['contributorId'] == userId
        ).toList();
        
        if (userAccounts.isNotEmpty) {
          for (var account in userAccounts) {
            sellableGames.add({
              'gameId': doc.id,
              'gameTitle': gameData['title'],
              'accountId': account['accountId'],
              'accountType': account['sharingOptions']?[0] ?? 'unknown',
              'gameValue': account['gameValue'],
              'platform': gameData['platforms']?[0] ?? 'unknown',
              'estimatedSellValue': (account['gameValue'] ?? 0) * 0.9,
            });
          }
        }
      }
      
      return sellableGames;
    } catch (e) {
      print('Error getting sellable games: $e');
      return [];
    }
  }
}