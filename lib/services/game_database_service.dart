// lib/services/game_database_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/api_config.dart';

class GameDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fallback game database for when API is not available
  static final List<Map<String, dynamic>> _fallbackGames = [
    // Popular PS5 Games
    {'name': 'Spider-Man 2', 'platforms': ['PS5'], 'rating': 4.8, 'released': '2023-10-20'},
    {'name': 'God of War Ragnarök', 'platforms': ['PS4', 'PS5'], 'rating': 4.9, 'released': '2022-11-09'},
    {'name': 'Horizon Forbidden West', 'platforms': ['PS4', 'PS5'], 'rating': 4.7, 'released': '2022-02-18'},
    {'name': 'The Last of Us Part I', 'platforms': ['PS5'], 'rating': 4.8, 'released': '2022-09-02'},
    {'name': 'Demon\'s Souls', 'platforms': ['PS5'], 'rating': 4.6, 'released': '2020-11-12'},
    {'name': 'Ratchet & Clank: Rift Apart', 'platforms': ['PS5'], 'rating': 4.7, 'released': '2021-06-11'},
    {'name': 'Returnal', 'platforms': ['PS5'], 'rating': 4.5, 'released': '2021-04-30'},
    {'name': 'Ghost of Tsushima Director\'s Cut', 'platforms': ['PS4', 'PS5'], 'rating': 4.8, 'released': '2021-08-20'},

    // Popular PS4 Games
    {'name': 'The Last of Us Part II', 'platforms': ['PS4'], 'rating': 4.5, 'released': '2020-06-19'},
    {'name': 'Red Dead Redemption 2', 'platforms': ['PS4'], 'rating': 4.9, 'released': '2018-10-26'},
    {'name': 'The Witcher 3: Wild Hunt', 'platforms': ['PS4'], 'rating': 4.9, 'released': '2015-05-19'},
    {'name': 'Bloodborne', 'platforms': ['PS4'], 'rating': 4.7, 'released': '2015-03-24'},
    {'name': 'Persona 5 Royal', 'platforms': ['PS4'], 'rating': 4.8, 'released': '2020-03-31'},
    {'name': 'Uncharted 4: A Thief\'s End', 'platforms': ['PS4'], 'rating': 4.8, 'released': '2016-05-10'},
    {'name': 'Marvel\'s Spider-Man', 'platforms': ['PS4'], 'rating': 4.7, 'released': '2018-09-07'},

    // Sports Games
    {'name': 'EA Sports FC 24', 'platforms': ['PS4', 'PS5'], 'rating': 4.2, 'released': '2023-09-29'},
    {'name': 'FIFA 23', 'platforms': ['PS4', 'PS5'], 'rating': 4.1, 'released': '2022-09-30'},
    {'name': 'NBA 2K24', 'platforms': ['PS4', 'PS5'], 'rating': 4.0, 'released': '2023-09-08'},
    {'name': 'Gran Turismo 7', 'platforms': ['PS4', 'PS5'], 'rating': 4.3, 'released': '2022-03-04'},
    {'name': 'WWE 2K23', 'platforms': ['PS4', 'PS5'], 'rating': 4.1, 'released': '2023-03-17'},

    // Action Games
    {'name': 'Call of Duty: Modern Warfare III', 'platforms': ['PS4', 'PS5'], 'rating': 3.9, 'released': '2023-11-10'},
    {'name': 'Hogwarts Legacy', 'platforms': ['PS4', 'PS5'], 'rating': 4.5, 'released': '2023-02-10'},
    {'name': 'Elden Ring', 'platforms': ['PS4', 'PS5'], 'rating': 4.8, 'released': '2022-02-25'},
    {'name': 'Sekiro: Shadows Die Twice', 'platforms': ['PS4'], 'rating': 4.7, 'released': '2019-03-22'},
    {'name': 'Dark Souls III', 'platforms': ['PS4'], 'rating': 4.6, 'released': '2016-04-12'},
    {'name': 'Cyberpunk 2077', 'platforms': ['PS4', 'PS5'], 'rating': 4.0, 'released': '2020-12-10'},
    {'name': 'Assassin\'s Creed Mirage', 'platforms': ['PS4', 'PS5'], 'rating': 4.2, 'released': '2023-10-05'},

    // RPG Games
    {'name': 'Final Fantasy XVI', 'platforms': ['PS5'], 'rating': 4.6, 'released': '2023-06-22'},
    {'name': 'Final Fantasy VII Remake', 'platforms': ['PS4', 'PS5'], 'rating': 4.7, 'released': '2020-04-10'},
    {'name': 'Baldur\'s Gate 3', 'platforms': ['PS5'], 'rating': 4.9, 'released': '2023-09-06'},
    {'name': 'Tales of Arise', 'platforms': ['PS4', 'PS5'], 'rating': 4.5, 'released': '2021-09-10'},
    {'name': 'Monster Hunter: World', 'platforms': ['PS4'], 'rating': 4.6, 'released': '2018-01-26'},

    // Racing Games
    {'name': 'Need for Speed Unbound', 'platforms': ['PS5'], 'rating': 4.1, 'released': '2022-12-02'},
    {'name': 'F1 23', 'platforms': ['PS4', 'PS5'], 'rating': 4.3, 'released': '2023-06-16'},
    {'name': 'Dirt 5', 'platforms': ['PS4', 'PS5'], 'rating': 4.0, 'released': '2020-11-06'},

    // Fighting Games
    {'name': 'Street Fighter 6', 'platforms': ['PS4', 'PS5'], 'rating': 4.7, 'released': '2023-06-02'},
    {'name': 'Mortal Kombat 1', 'platforms': ['PS5'], 'rating': 4.4, 'released': '2023-09-19'},
    {'name': 'Tekken 8', 'platforms': ['PS5'], 'rating': 4.6, 'released': '2024-01-26'},
    {'name': 'Injustice 2', 'platforms': ['PS4'], 'rating': 4.5, 'released': '2017-05-11'},

    // Adventure Games
    {'name': 'Kena: Bridge of Spirits', 'platforms': ['PS4', 'PS5'], 'rating': 4.4, 'released': '2021-09-21'},
    {'name': 'Stray', 'platforms': ['PS4', 'PS5'], 'rating': 4.5, 'released': '2022-07-19'},
    {'name': 'It Takes Two', 'platforms': ['PS4', 'PS5'], 'rating': 4.7, 'released': '2021-03-26'},
    {'name': 'A Plague Tale: Requiem', 'platforms': ['PS5'], 'rating': 4.6, 'released': '2022-10-18'},

    // Multiplayer Games
    {'name': 'Fortnite', 'platforms': ['PS4', 'PS5'], 'rating': 4.0, 'released': '2017-07-25'},
    {'name': 'Apex Legends', 'platforms': ['PS4', 'PS5'], 'rating': 4.2, 'released': '2019-02-04'},
    {'name': 'Overwatch 2', 'platforms': ['PS4', 'PS5'], 'rating': 3.8, 'released': '2022-10-04'},
    {'name': 'Rocket League', 'platforms': ['PS4', 'PS5'], 'rating': 4.3, 'released': '2015-07-07'},
    {'name': 'Fall Guys', 'platforms': ['PS4', 'PS5'], 'rating': 4.1, 'released': '2020-08-04'},

    // Horror Games
    {'name': 'Resident Evil 4', 'platforms': ['PS4', 'PS5'], 'rating': 4.8, 'released': '2023-03-24'},
    {'name': 'Dead Space', 'platforms': ['PS5'], 'rating': 4.6, 'released': '2023-01-27'},
    {'name': 'The Dark Pictures Anthology: House of Ashes', 'platforms': ['PS4', 'PS5'], 'rating': 4.2, 'released': '2021-10-22'},

    // Indie Games
    {'name': 'Hades', 'platforms': ['PS4', 'PS5'], 'rating': 4.8, 'released': '2021-08-13'},
    {'name': 'Celeste', 'platforms': ['PS4'], 'rating': 4.7, 'released': '2018-01-25'},
    {'name': 'Hollow Knight', 'platforms': ['PS4'], 'rating': 4.6, 'released': '2018-09-25'},
  ];

  // Initialize and seed the local game database
  Future<void> seedGameDatabase() async {
    try {
      // Check if games collection exists and has data
      final gamesCollection = _firestore.collection('game_database');
      final snapshot = await gamesCollection.limit(1).get();

      if (snapshot.docs.isEmpty) {
        // Seed with fallback games
        final batch = _firestore.batch();
        for (var game in _fallbackGames) {
          final docRef = gamesCollection.doc();
          batch.set(docRef, {
            ...game,
            'searchName': game['name'].toString().toLowerCase(),
            'createdAt': FieldValue.serverTimestamp(),
            'source': 'fallback',
          });
        }
        await batch.commit();
        print('Game database seeded with ${_fallbackGames.length} games');
      }
    } catch (e) {
      print('Error seeding game database: $e');
    }
  }

  // Search games from API or fallback
  Future<List<Map<String, dynamic>>> searchGames(String query) async {
    if (query.isEmpty || query.length < 2) return [];

    final lowerQuery = query.toLowerCase();

    try {
      // First, try to use the RAWG API if configured
      if (ApiConfig.isApiKeyValid) {
        return await _searchGamesFromAPI(query);
      } else {
        // Use local/fallback search
        return await _searchGamesLocally(lowerQuery);
      }
    } catch (e) {
      print('Error searching games: $e');
      // Fallback to local search on any error
      return await _searchGamesLocally(lowerQuery);
    }
  }

  // Search games from RAWG API
  Future<List<Map<String, dynamic>>> _searchGamesFromAPI(String query) async {
    try {
      final url = Uri.parse(
          '${ApiConfig.rawgBaseUrl}/games?key=${ApiConfig.rawgApiKey}&search=$query&page_size=10&platforms=${ApiConfig.playStation4Id},${ApiConfig.playStation5Id}'
      );

      final response = await http.get(url).timeout(ApiConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        return results.map((game) {
          // Parse platforms
          final platforms = <String>[];
          if (game['platforms'] != null) {
            for (var platform in game['platforms']) {
              final platformName = platform['platform']['name'];
              if (platformName == 'PlayStation 4') platforms.add('PS4');
              if (platformName == 'PlayStation 5') platforms.add('PS5');
            }
          }

          // Parse genres
          final genres = <String>[];
          if (game['genres'] != null) {
            for (var genre in game['genres']) {
              genres.add(genre['name']);
            }
          }

          return {
            'id': game['id'].toString(),
            'name': game['name'],
            'background_image': game['background_image'],
            'rating': game['rating'],
            'platforms': platforms,
            'genres': genres,
            'released': game['released'],
            'source': 'rawg_api',
          };
        }).toList();
      } else {
        throw Exception('API returned status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching from RAWG API: $e');
      rethrow;
    }
  }

  // Search games locally from Firestore or fallback data
  Future<List<Map<String, dynamic>>> _searchGamesLocally(String lowerQuery) async {
    try {
      // Try Firestore first
      final snapshot = await _firestore
          .collection('game_database')
          .where('searchName', isGreaterThanOrEqualTo: lowerQuery)
          .where('searchName', isLessThanOrEqualTo: lowerQuery + '\uf8ff')
          .limit(10)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'],
            'background_image': data['background_image'],
            'rating': data['rating'],
            'platforms': List<String>.from(data['platforms'] ?? []),
            'genres': List<String>.from(data['genres'] ?? []),
            'released': data['released'],
            'source': data['source'] ?? 'firestore',
          };
        }).toList();
      }
    } catch (e) {
      print('Error searching Firestore: $e');
    }

    // Fallback to in-memory search
    final results = _fallbackGames.where((game) {
      final gameName = game['name'].toString().toLowerCase();
      return gameName.contains(lowerQuery);
    }).take(10).map((game) {
      return {
        'id': game['name'].hashCode.toString(),
        'name': game['name'],
        'background_image': null,
        'rating': game['rating'],
        'platforms': List<String>.from(game['platforms']),
        'genres': List<String>.from(game['genres'] ?? []),
        'released': game['released'],
        'source': 'fallback',
      };
    }).toList();

    return results;
  }

  // Get popular games
  Future<List<Map<String, dynamic>>> getPopularGames() async {
    try {
      if (ApiConfig.isApiKeyValid) {
        final url = Uri.parse(
            '${ApiConfig.rawgBaseUrl}/games?key=${ApiConfig.rawgApiKey}&page_size=20&platforms=${ApiConfig.playStation4Id},${ApiConfig.playStation5Id}&ordering=-rating&metacritic=80,100'
        );

        final response = await http.get(url).timeout(ApiConfig.apiTimeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return _parseAPIGames(data['results']);
        }
      }
    } catch (e) {
      print('Error fetching popular games: $e');
    }

    // Return top rated fallback games
    final sortedGames = List<Map<String, dynamic>>.from(_fallbackGames);
    sortedGames.sort((a, b) => (b['rating'] ?? 0).compareTo(a['rating'] ?? 0));
    return sortedGames.take(20).toList();
  }

  // Helper to parse API game results
  List<Map<String, dynamic>> _parseAPIGames(List<dynamic> results) {
    return results.map((game) {
      final platforms = <String>[];
      if (game['platforms'] != null) {
        for (var platform in game['platforms']) {
          final platformName = platform['platform']['name'];
          if (platformName == 'PlayStation 4') platforms.add('PS4');
          if (platformName == 'PlayStation 5') platforms.add('PS5');
        }
      }

      return {
        'id': game['id'].toString(),
        'name': game['name'],
        'background_image': game['background_image'],
        'rating': game['rating'],
        'platforms': platforms,
        'released': game['released'],
        'source': 'rawg_api',
      };
    }).toList();
  }
}