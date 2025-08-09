// lib/presentation/providers/game_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/game_model.dart' as game_models; // Import with prefix to avoid conflicts
import '../../data/models/user_model.dart';
import '../../services/borrow_service.dart';

class GameProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BorrowService _borrowService = BorrowService();

  List<game_models.GameAccount> _games = [];
  List<Map<String, dynamic>> _userBorrowings = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<game_models.GameAccount> get games => _games;
  List<Map<String, dynamic>> get userBorrowings => _userBorrowings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get available games (games with at least one available slot)
  List<game_models.GameAccount> get availableGames {
    return _games.where((game) => game.availableSlotsCount > 0).toList();
  }

  // Get games by lender tier
  List<game_models.GameAccount> getGamesByLenderTier(game_models.LenderTier tier) {
    return _games.where((game) => game.lenderTier == tier).toList();
  }

  // Get member games
  List<game_models.GameAccount> get memberGames {
    return getGamesByLenderTier(game_models.LenderTier.member);
  }

  // Get vault games
  List<game_models.GameAccount> get vaultGames {
    return getGamesByLenderTier(game_models.LenderTier.gamesVault);
  }

  // Get games by platform
  List<game_models.GameAccount> getGamesByPlatform(game_models.Platform platform) {
    return _games.where((game) => game.supportedPlatforms.contains(platform)).toList();
  }

  // Search games by title
  List<game_models.GameAccount> searchGames(String query) {
    if (query.isEmpty) return _games;

    final lowerQuery = query.toLowerCase();
    return _games.where((game) {
      // Search in main title
      if (game.title.toLowerCase().contains(lowerQuery)) return true;
      // Search in included titles
      for (var title in game.includedTitles) {
        if (title.toLowerCase().contains(lowerQuery)) return true;
      }
      return false;
    }).toList();
  }

  // Load all games from Firestore
  Future<void> loadGames() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final querySnapshot = await _firestore
          .collection('games')
          .get();

      _games = querySnapshot.docs
          .map((doc) => game_models.GameAccount.fromFirestore(doc))
          .toList();

      // Sort by date added (newest first)
      _games.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));

      _errorMessage = null;
    } catch (e) {
      print('Error loading games: $e');
      _errorMessage = 'Failed to load games: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load user's current borrowings
  Future<void> loadUserBorrowings(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userBorrowings = await _borrowService.getUserActiveBorrows(userId);

      // Sort by borrow date (newest first)
      _userBorrowings.sort((a, b) {
        final dateA = a['approvalDate'] as Timestamp?;
        final dateB = b['approvalDate'] as Timestamp?;
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });
    } catch (e) {
      print('Error loading user borrowings: $e');
      _userBorrowings = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Submit borrow request for a game
  Future<Map<String, dynamic>> submitBorrowRequest({
    required String userId,
    required String userName,
    required String gameId,
    required game_models.GameAccount game,
    required game_models.Platform platform,
    required game_models.AccountType accountType,
  }) async {
    try {
      // Find an available account with the requested slot
      String? availableAccountId;

      if (game.accounts != null && game.accounts!.isNotEmpty) {
        // New structure with multiple accounts
        for (var account in game.accounts!) {
          final slotKey = '${platform.value}_${accountType.value}';
          if (account['slots'] != null && account['slots'][slotKey] != null) {
            final slotData = account['slots'][slotKey];
            if (slotData['status'] == 'available') {
              availableAccountId = account['accountId'];
              break;
            }
          }
        }
      } else {
        // Old structure - check main slots
        final slotKey = '${platform.value}_${accountType.value}';
        if (game.slots[slotKey]?.status == game_models.SlotStatus.available) {
          availableAccountId = game.accountId;
        }
      }

      if (availableAccountId == null) {
        return {
          'success': false,
          'message': 'No available slot found for this platform and account type',
        };
      }

      return await _borrowService.submitBorrowRequest(
        userId: userId,
        userName: userName,
        gameId: gameId,
        gameTitle: game.title,
        accountId: availableAccountId,
        platform: platform,
        accountType: accountType,
        borrowValue: game.gameValue, memberId: '', // Changed from gameValue to borrowValue
      );
    } catch (e) {
      print('Error submitting borrow request: $e');
      return {
        'success': false,
        'message': 'Failed to submit borrow request: $e',
      };
    }
  }

  // Add a new game (Admin only) - FIXED VERSION
  Future<Map<String, dynamic>> addGame({
    required String title,
    required List<String> includedTitles,
    required String contributorId,
    required String contributorName,
    required game_models.LenderTier lenderTier,
    required List<game_models.Platform> supportedPlatforms,
    required List<game_models.AccountType> sharingOptions,
    required double gameValue,
    String? coverImageUrl,
    String? description,
    String? email,
    String? password,
    String? edition,
    String? region,
  }) async {
    try {
      // Create slots based on platforms and sharing options
      Map<String, dynamic> slots = {};
      for (var platform in supportedPlatforms) {
        for (var accountType in sharingOptions) {
          final slotKey = '${platform.value}_${accountType.value}';
          slots[slotKey] = {
            'platform': platform.value,
            'accountType': accountType.value,
            'status': game_models.SlotStatus.available.value,
            'borrowerId': null,
            'borrowDate': null,
            'expectedReturnDate': null,
            'reservationDate': null,
            'reservedById': null,
          };
        }
      }

      // Create account object for new structure
      final accountData = {
        'accountId': DateTime.now().millisecondsSinceEpoch.toString(),
        'contributorId': contributorId,
        'contributorName': contributorName,
        'platforms': supportedPlatforms.map((p) => p.value).toList(),
        'sharingOptions': sharingOptions.map((a) => a.value).toList(),
        'credentials': {
          'email': email ?? '',
          'password': password ?? '',
        },
        'edition': edition ?? 'standard',
        'region': region ?? 'US',
        'status': 'available',
        'slots': slots,
        'gameValue': gameValue,
        'dateAdded': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      // Check if game already exists
      final gameQuery = await _firestore
          .collection('games')
          .where('title', isEqualTo: title)
          .limit(1)
          .get();

      if (gameQuery.docs.isEmpty) {
        // Create new game document with accounts array
        await _firestore.collection('games').add({
          'title': title,
          'includedTitles': includedTitles,
          'coverImageUrl': coverImageUrl,
          'description': description,
          'lenderTier': lenderTier.value,
          'accounts': [accountData], // Array of accounts
          'totalValue': gameValue,
          'totalAccounts': 1,
          'availableAccounts': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Add account to existing game
        await gameQuery.docs.first.reference.update({
          'accounts': FieldValue.arrayUnion([accountData]),
          'totalValue': FieldValue.increment(gameValue),
          'totalAccounts': FieldValue.increment(1),
          'availableAccounts': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update contributor's game shares
      await _firestore.collection('users').doc(contributorId).update({
        'gameShares': FieldValue.increment(1),
        'totalShares': FieldValue.increment(1),
        'stationLimit': FieldValue.increment(gameValue),
        'remainingStationLimit': FieldValue.increment(gameValue),
        'lastActivityDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reload games
      await loadGames();

      return {
        'success': true,
        'message': 'Game added successfully!',
      };

    } catch (e) {
      print('Error adding game: $e');
      return {
        'success': false,
        'message': 'Failed to add game: $e',
      };
    }
  }

  // Update game details (Admin only)
  Future<Map<String, dynamic>> updateGame({
    required String gameId,
    String? title,
    List<String>? includedTitles,
    String? coverImageUrl,
    String? description,
    double? gameValue,
    bool? isActive,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updates['title'] = title;
      if (includedTitles != null) updates['includedTitles'] = includedTitles;
      if (coverImageUrl != null) updates['coverImageUrl'] = coverImageUrl;
      if (description != null) updates['description'] = description;
      if (gameValue != null) updates['gameValue'] = gameValue;
      if (isActive != null) updates['isActive'] = isActive;

      await _firestore.collection('games').doc(gameId).update(updates);

      // Reload games
      await loadGames();

      return {
        'success': true,
        'message': 'Game updated successfully!',
      };
    } catch (e) {
      print('Error updating game: $e');
      return {
        'success': false,
        'message': 'Failed to update game: $e',
      };
    }
  }

  // Delete game (Admin only)
  Future<Map<String, dynamic>> deleteGame(String gameId) async {
    try {
      // Get game data first
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      if (!gameDoc.exists) {
        return {
          'success': false,
          'message': 'Game not found',
        };
      }

      final gameData = gameDoc.data()!;

      // Check if there are active borrows
      bool hasActiveBorrows = false;
      if (gameData['accounts'] != null) {
        for (var account in gameData['accounts']) {
          if (account['slots'] != null) {
            for (var slot in account['slots'].values) {
              if (slot['status'] == 'taken') {
                hasActiveBorrows = true;
                break;
              }
            }
          }
        }
      }

      if (hasActiveBorrows) {
        return {
          'success': false,
          'message': 'Cannot delete game with active borrows',
        };
      }

      // Delete the game
      await _firestore.collection('games').doc(gameId).delete();

      // Reload games
      await loadGames();

      return {
        'success': true,
        'message': 'Game deleted successfully!',
      };
    } catch (e) {
      print('Error deleting game: $e');
      return {
        'success': false,
        'message': 'Failed to delete game: $e',
      };
    }
  }

  // Get game statistics
  Map<String, dynamic> getGameStatistics() {
    int totalGames = _games.length;
    int availableGames = _games.where((g) => g.hasAvailableSlots).length;
    int memberGames = _games.where((g) => g.lenderTier == game_models.LenderTier.member).length;
    int vaultGames = _games.where((g) => g.lenderTier == game_models.LenderTier.gamesVault).length;

    int totalSlots = 0;
    int availableSlots = 0;
    int takenSlots = 0;

    for (var game in _games) {
      totalSlots += game.slots.length;
      availableSlots += game.slots.values.where((s) => s.status == game_models.SlotStatus.available).length;
      takenSlots += game.slots.values.where((s) => s.status == game_models.SlotStatus.taken).length;
    }

    return {
      'totalGames': totalGames,
      'availableGames': availableGames,
      'memberGames': memberGames,
      'vaultGames': vaultGames,
      'totalSlots': totalSlots,
      'availableSlots': availableSlots,
      'takenSlots': takenSlots,
      'utilizationRate': totalSlots > 0 ? (takenSlots / totalSlots * 100).toStringAsFixed(1) : '0',
    };
  }

  // Clear provider data
  void clear() {
    _games = [];
    _userBorrowings = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}