import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/game_model.dart' hide Platform;
import '../../data/models/user_model.dart';
import 'auth_provider.dart';

class GameProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<GameAccount> _games = [];
  List<GameAccount> _userBorrowings = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<GameAccount> get games => _games;
  List<GameAccount> get userBorrowings => _userBorrowings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get available games
  List<GameAccount> get availableGames {
    return _games.where((game) => game.availableSlotsCount > 0).toList();
  }

  // Get games by category
  List<GameAccount> getGamesByCategory(LenderTier tier) {
    return _games.where((game) => game.lenderTier == tier).toList();
  }

  // Get games by platform
  List<GameAccount> getGamesByPlatform(Platform platform) {
    return _games.where((game) => game.supportedPlatforms.contains(platform)).toList();
  }

  // Load all games
  Future<void> loadGames() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final querySnapshot = await _firestore
          .collection('games')
          .where('isActive', isEqualTo: true)
          .get();

      _games = querySnapshot.docs
          .map((doc) => GameAccount.fromFirestore(doc))
          .toList();

      // Sort by date added (newest first)
      _games.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));

    } catch (e) {
      print('Error loading games: $e');
      _errorMessage = 'Failed to load games';
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
      // Query games where user has active borrowings
      final querySnapshot = await _firestore
          .collection('borrows')
          .where('borrowerId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      // Get game IDs from borrowings
      final gameIds = querySnapshot.docs
          .map((doc) => doc.data()['gameId'] as String)
          .toSet()
          .toList();

      if (gameIds.isNotEmpty) {
        // Load the actual game data
        final gamesSnapshot = await _firestore
            .collection('games')
            .where(FieldPath.documentId, whereIn: gameIds)
            .get();

        _userBorrowings = gamesSnapshot.docs
            .map((doc) => GameAccount.fromFirestore(doc))
            .toList();
      } else {
        _userBorrowings = [];
      }

    } catch (e) {
      print('Error loading user borrowings: $e');
      _errorMessage = 'Failed to load borrowings';
      _userBorrowings = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Request to borrow a game
  Future<Map<String, dynamic>> borrowGame({
    required String userId,
    required String gameId,
    required Platform platform,
    required AccountType accountType,
    required double borrowValue,
  }) async {
    try {
      // Create borrow request document
      final borrowDoc = {
        'borrowerId': userId,
        'gameId': gameId,
        'platform': platform.name,
        'accountType': accountType.name,
        'borrowValue': borrowValue,
        'borrowDate': FieldValue.serverTimestamp(),
        'status': 'active',
        'expectedReturnDate': DateTime.now().add(Duration(days: 30)).toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add to borrows collection
      await _firestore.collection('borrows').add(borrowDoc);

      // Update game slot status
      final slotKey = '${platform.name}_${accountType.name}';
      await _firestore.collection('games').doc(gameId).update({
        'slots.$slotKey.status': 'taken',
        'slots.$slotKey.borrowerId': userId,
        'slots.$slotKey.borrowDate': FieldValue.serverTimestamp(),
        'currentBorrows': FieldValue.increment(1),
        'totalBorrows': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user's borrow count and station limit
      await _firestore.collection('users').doc(userId).update({
        'currentBorrows': FieldValue.increment(1),
        'remainingStationLimit': FieldValue.increment(-borrowValue),
        'lastActivityDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reload games to reflect changes
      await loadGames();

      return {
        'success': true,
        'message': 'Game borrowed successfully!',
      };

    } catch (e) {
      print('Error borrowing game: $e');
      return {
        'success': false,
        'message': 'Failed to borrow game: $e',
      };
    }
  }

  // Return a borrowed game
  Future<Map<String, dynamic>> returnGame({
    required String userId,
    required String gameId,
    required String borrowId,
    required Platform platform,
    required AccountType accountType,
    required double borrowValue,
  }) async {
    try {
      // Update borrow document
      await _firestore.collection('borrows').doc(borrowId).update({
        'status': 'completed',
        'returnDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update game slot status
      final slotKey = '${platform.name}_${accountType.name}';
      await _firestore.collection('games').doc(gameId).update({
        'slots.$slotKey.status': 'available',
        'slots.$slotKey.borrowerId': null,
        'slots.$slotKey.borrowDate': null,
        'currentBorrows': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user's borrow count and station limit
      await _firestore.collection('users').doc(userId).update({
        'currentBorrows': FieldValue.increment(-1),
        'remainingStationLimit': FieldValue.increment(borrowValue),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reload games and borrowings
      await loadGames();
      await loadUserBorrowings(userId);

      return {
        'success': true,
        'message': 'Game returned successfully!',
      };

    } catch (e) {
      print('Error returning game: $e');
      return {
        'success': false,
        'message': 'Failed to return game: $e',
      };
    }
  }

  // Add a new game (Admin only)
  Future<Map<String, dynamic>> addGame({
    required String title,
    required List<String> includedTitles,
    required String contributorId,
    required String contributorName,
    required LenderTier lenderTier,
    required List<Platform> supportedPlatforms,
    required List<AccountType> sharingOptions,
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
          final slotKey = '${platform.name}_${accountType.name}';
          slots[slotKey] = {
            'platform': platform.name,
            'accountType': accountType.name,
            'status': 'available',
            'borrowerId': null,
            'borrowDate': null,
            'expectedReturnDate': null,
            'reservationDate': null,
            'reservedById': null,
          };
        }
      }

      // Create game document
      final gameDoc = {
        'title': title,
        'includedTitles': includedTitles,
        'coverImageUrl': coverImageUrl,
        'description': description,
        'email': email ?? '',
        'password': password ?? '',
        'edition': edition,
        'region': region,
        'contributorId': contributorId,
        'contributorName': contributorName,
        'lenderTier': lenderTier.name,
        'dateAdded': FieldValue.serverTimestamp(),
        'isActive': true,
        'supportedPlatforms': supportedPlatforms.map((p) => p.name).toList(),
        'sharingOptions': sharingOptions.map((a) => a.name).toList(),
        'slots': slots,
        'gameValue': gameValue,
        'totalCost': gameValue,
        'totalRevenues': 0,
        'borrowRevenue': 0,
        'sellRevenue': 0,
        'fundShareRevenue': 0,
        'totalBorrows': 0,
        'currentBorrows': 0,
        'averageBorrowDuration': 0,
        'borrowHistory': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add to Firestore
      await _firestore.collection('games').add(gameDoc);

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

  // Search games
  List<GameAccount> searchGames(String query) {
    if (query.isEmpty) return _games;

    final lowercaseQuery = query.toLowerCase();
    return _games.where((game) {
      return game.title.toLowerCase().contains(lowercaseQuery) ||
          game.includedTitles.any((title) =>
              title.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  // Get game by ID
  GameAccount? getGameById(String gameId) {
    try {
      return _games.firstWhere((game) => game.accountId == gameId);
    } catch (e) {
      return null;
    }
  }

  // Listen to real-time game updates
  void listenToGames() {
    _firestore
        .collection('games')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      _games = snapshot.docs
          .map((doc) => GameAccount.fromFirestore(doc))
          .toList();

      // Sort by date added (newest first)
      _games.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));

      notifyListeners();
    }, onError: (error) {
      print('Error listening to games: $error');
      _errorMessage = 'Failed to load games';
      notifyListeners();
    });
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