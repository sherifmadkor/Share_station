// lib/services/score_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ScoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Calculate all user scores (run daily via cloud function or admin trigger)
  Future<Map<String, dynamic>> calculateUserScores() async {
    try {
      // Get all active borrowers
      final usersSnapshot = await _firestore
        .collection('users')
        .where('status', isEqualTo: 'active')
        .where('totalBorrowsCount', isGreaterThan: 0)
        .get();
      
      // Group by tier for ranking
      final Map<String, List<Map<String, dynamic>>> tierGroups = {
        'member': [],
        'vip': [],
        'client': [],
        'user': [],
      };
      
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final tier = data['tier'] ?? 'member';
        
        if (tierGroups.containsKey(tier)) {
          tierGroups[tier]!.add(data);
        }
      }
      
      final batch = _firestore.batch();
      int totalUpdated = 0;
      
      // Calculate scores for each tier group
      for (var tier in tierGroups.keys) {
        final users = tierGroups[tier]!;
        if (users.isEmpty) continue;
        
        // C Score - Contribution ranking (higher is better)
        users.sort((a, b) => 
          (b['totalShares'] ?? 0).compareTo(a['totalShares'] ?? 0)
        );
        for (int i = 0; i < users.length; i++) {
          users[i]['cScore'] = i + 1;
        }
        
        // F Score - Fund ranking (higher is better)
        users.sort((a, b) => 
          (b['fundShares'] ?? 0).compareTo(a['fundShares'] ?? 0)
        );
        for (int i = 0; i < users.length; i++) {
          users[i]['fScore'] = i + 1;
        }
        
        // H Score - Hold period ranking (lower is better)
        users.sort((a, b) => 
          (a['averageHoldPeriod'] ?? 999).compareTo(b['averageHoldPeriod'] ?? 999)
        );
        for (int i = 0; i < users.length; i++) {
          users[i]['hScore'] = i + 1;
        }
        
        // E Score - Exchange ranking (higher is better)
        users.sort((a, b) => 
          (b['netExchange'] ?? 0).compareTo(a['netExchange'] ?? 0)
        );
        for (int i = 0; i < users.length; i++) {
          users[i]['eScore'] = i + 1;
        }
        
        // Calculate overall score and update
        for (var user in users) {
          // Weighted score: C*0.2 + F*0.35 + H*0.1 + E*0.35
          final overallScore = 
            (user['cScore'] * 0.2) + 
            (user['fScore'] * 0.35) + 
            (user['hScore'] * 0.1) + 
            (user['eScore'] * 0.35);
          
          batch.update(_firestore.collection('users').doc(user['id']), {
            'cScore': user['cScore'],
            'fScore': user['fScore'],
            'hScore': user['hScore'],
            'eScore': user['eScore'],
            'overallScore': overallScore,
            'scoresUpdatedAt': FieldValue.serverTimestamp(),
          });
          
          totalUpdated++;
        }
      }
      
      await batch.commit();
      
      return {
        'success': true,
        'message': 'Scores calculated successfully',
        'usersUpdated': totalUpdated,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
  
  // Get leaderboard for a specific tier
  Future<List<Map<String, dynamic>>> getLeaderboard({
    required String tier,
    required String scoreType,
    int limit = 10,
  }) async {
    try {
      String orderByField;
      bool descending = false;
      
      switch (scoreType) {
        case 'contribution':
          orderByField = 'totalShares';
          descending = true;
          break;
        case 'fund':
          orderByField = 'fundShares';
          descending = true;
          break;
        case 'holdPeriod':
          orderByField = 'averageHoldPeriod';
          descending = false; // Lower is better
          break;
        case 'exchange':
          orderByField = 'netExchange';
          descending = true;
          break;
        case 'overall':
          orderByField = 'overallScore';
          descending = false; // Lower score is better (ranking)
          break;
        default:
          orderByField = 'overallScore';
          descending = false;
      }
      
      final query = await _firestore
        .collection('users')
        .where('tier', isEqualTo: tier)
        .where('status', isEqualTo: 'active')
        .where('totalBorrowsCount', isGreaterThan: 0)
        .orderBy(orderByField, descending: descending)
        .limit(limit)
        .get();
      
      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'memberId': data['memberId'],
          'value': data[orderByField],
          'cScore': data['cScore'],
          'fScore': data['fScore'],
          'hScore': data['hScore'],
          'eScore': data['eScore'],
          'overallScore': data['overallScore'],
        };
      }).toList();
    } catch (e) {
      print('Error getting leaderboard: $e');
      return [];
    }
  }
}