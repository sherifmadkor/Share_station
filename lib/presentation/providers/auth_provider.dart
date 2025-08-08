import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _firebaseUser;
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get firebaseUser => _firebaseUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _firebaseUser != null;
  bool get isAdmin => _currentUser?.tier == UserTier.admin;
  bool get isVIP => _currentUser?.tier == UserTier.vip;
  bool get isMember => _currentUser?.tier == UserTier.member;
  bool get isClient => _currentUser?.tier == UserTier.client;

  AuthProvider() {
    _initializeAuth();
  }

  // Initialize authentication state
  void _initializeAuth() {
    _auth.authStateChanges().listen((User? user) async {
      _firebaseUser = user;
      if (user != null) {
        await _loadUserData(user.uid);
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  // Load user data from Firestore
  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);

        // Check for automatic VIP promotion
        if (_currentUser!.isEligibleForVIP &&
            _currentUser!.tier == UserTier.member) {
          await _promoteToVIP();
        }

        // Check for suspension
        if (_currentUser!.shouldBeSuspended &&
            _currentUser!.status != UserStatus.suspended) {
          await _suspendUser();
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      _errorMessage = 'Failed to load user data';
    }
    notifyListeners();
  }

  // Sign in with email and password
  Future<Map<String, dynamic>> signInWithEmailAndPassword(
      String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _loadUserData(credential.user!.uid);

        // Check user status
        if (_currentUser?.status == UserStatus.suspended) {
          await _auth.signOut();
          return {
            'success': false,
            'message':
            'Your account has been suspended due to inactivity. Please contact support.',
          };
        }

        if (_currentUser?.status == UserStatus.pending) {
          await _auth.signOut();
          return {
            'success': false,
            'message':
            'Your account is pending approval. Please wait for admin verification.',
          };
        }

        // Update last login
        await _updateLastLogin();

        return {
          'success': true,
          'role': _currentUser?.tier.name,
          'user': _currentUser,
        };
      }

      return {
        'success': false,
        'message': 'Login failed. Please try again.',
      };
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred during login.';

      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email address.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          message = 'Invalid email address format.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message =
          'Too many failed attempts. Please try again later.';
          break;
      }

      _errorMessage = message;
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      return {
        'success': false,
        'message': _errorMessage,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register new user
  Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    required UserTier tier,
    required double subscriptionFee,
    String? referrerId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('Starting registration for email: $email');

      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print(
          'Firebase Auth user created with UID: ${credential.user?.uid}');

      if (credential.user != null) {
        // Generate member ID (3-digit)
        final String memberId = await _generateMemberId();
        print('Generated member ID: $memberId');

        // Calculate initial station limit based on tier
        double initialStationLimit = 0;
        if (tier == UserTier.member) {
          initialStationLimit = subscriptionFee * 4;
        } else if (tier == UserTier.client) {
          initialStationLimit = subscriptionFee * 4;
        }

        print('Creating Firestore document...');

        try {
          final userDoc = {
            'memberId': memberId,
            'name': name,
            'email': email,
            'phoneNumber': phoneNumber,
            'platform': 'na',
            'tier': tier.value,
            'status': tier == UserTier.user ? 'active' : 'pending',
            'joinDate': Timestamp.now(),
            'origin': 'App Registration',
            'recruiterId': referrerId ?? '',
            'referredUsers': [],
            'borrowValue': 0,
            'sellValue': 0,
            'refunds': 0,
            'referralEarnings': 0,
            'cashIn': 0,
            'usedBalance': 0,
            'expiredBalance': 0,
            'withdrawalFees': 0,
            'balanceExpiry': {},
            'points': 0,
            'convertedPoints': 0,
            'socialGiftPoints': 0,
            'goodwillPoints': 0,
            'expensePoints': 0,
            'stationLimit': initialStationLimit,
            'remainingStationLimit': initialStationLimit,
            'borrowLimit': 1,
            'currentBorrows': 0,
            'freeborrowings': tier == UserTier.client ? 5 : 0,
            'coolDownEligible': true,
            'gameShares': 0,
            'fundShares': 0,
            'totalShares': 0,
            'totalFunds': 0,
            'shareBreakdown': {},
            'coldPeriodDays': 0,
            'averageHoldPeriod': 0,
            'netLendings': 0,
            'netBorrowings': 0,
            'netExchange': 0,
            'cScore': 0,
            'fScore': 0,
            'hScore': 0,
            'eScore': 0,
            'overallScore': 0,
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          };

          print('Attempting to save to Firestore...');

          await _firestore
              .collection('users')
              .doc(credential.user!.uid)
              .set(userDoc);

          print('User document created successfully');
        } catch (firestoreError) {
          print('Error creating Firestore document: $firestoreError');
          await credential.user!.delete();
          throw Exception(
              'Failed to create user profile: $firestoreError');
        }

        if (referrerId != null && referrerId.isNotEmpty) {
          await _updateReferrer(referrerId, credential.user!.uid);
        }

        try {
          await credential.user!.sendEmailVerification();
        } catch (e) {
          print('Error sending verification email: $e');
        }

        if (tier != UserTier.user) {
          await _auth.signOut();
          return {
            'success': true,
            'message':
            'Registration successful! Please wait for admin approval.',
            'needsApproval': true,
          };
        }

        return {
          'success': true,
          'message': 'Registration successful!',
        };
      }

      return {
        'success': false,
        'message': 'Registration failed. Please try again.',
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed.';

      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          message = 'Invalid email address format.';
          break;
        case 'weak-password':
          message =
          'Password is too weak. Please use at least 6 characters.';
          break;
      }

      _errorMessage = message;
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      return {
        'success': false,
        'message': _errorMessage,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Generate unique 3-digit member ID
  Future<String> _generateMemberId() async {
    final random =
        DateTime.now().millisecondsSinceEpoch % 900 + 100;
    String memberId = random.toString();

    final query = await _firestore
        .collection('users')
        .where('memberId', isEqualTo: memberId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return _generateMemberId();
    }

    return memberId;
  }

  // Update referrer's data
  Future<void> _updateReferrer(
      String referrerId, String newUserId) async {
    try {
      final referrerDoc =
      await _firestore.collection('users').doc(referrerId).get();
      if (referrerDoc.exists) {
        final referrerData = referrerDoc.data()!;
        List<String> referredUsers =
        List<String>.from(referrerData['referredUsers'] ?? []);
        referredUsers.add(newUserId);

        await _firestore
            .collection('users')
            .doc(referrerId)
            .update({
          'referredUsers': referredUsers,
          'updatedAt': Timestamp.now(),
        });
      }
    } catch (e) {
      print('Error updating referrer: $e');
    }
  }

  // Promote user to VIP
  Future<void> _promoteToVIP() async {
    if (_currentUser == null) return;

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'tier': UserTier.vip.name,
        'borrowLimit': 5,
        'updatedAt': Timestamp.now(),
      });

      _currentUser = _currentUser!.copyWith(
        tier: UserTier.vip,
        borrowLimit: 5,
        updatedAt: DateTime.now(),
      );

      notifyListeners();
    } catch (e) {
      print('Error promoting to VIP: $e');
    }
  }

  // Suspend user account
  Future<void> _suspendUser() async {
    if (_currentUser == null) return;

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'status': UserStatus.suspended.value,
        'suspensionDate': Timestamp.now(),
        'balance': 0,
        'points': 0,
        'stationLimit': 0,
        'remainingStationLimit': 0,
        'borrowLimit': 0,
        'updatedAt': Timestamp.now(),
      });

      _currentUser = _currentUser!.copyWith(
        status: UserStatus.suspended,
        suspensionDate: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      notifyListeners();
    } catch (e) {
      print('Error suspending user: $e');
    }
  }

  // Update last login time
  Future<void> _updateLastLogin() async {
    if (_currentUser == null) return;

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'lastActivityDate': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating last login: $e');
    }
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'message': 'Password reset email sent. Please check your inbox.',
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to send reset email.';

      if (e.code == 'user-not-found') {
        message = 'No user found with this email address.';
      }

      return {
        'success': false,
        'message': message,
      };
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _currentUser = null;
      _firebaseUser = null;
      notifyListeners();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // FIXED: Added bodies for the previously empty functions
  void updateUserContribution(double contributionValue, double balanceCredit) {
    // TODO: implement actual logic
    print("Updating user contribution: $contributionValue, balance: $balanceCredit");
  }

  void updateFundContribution(double amount) {
    // TODO: implement actual logic
    print("Updating fund contribution: $amount");
  }

  // Update user profile
  Future<bool> updateUserProfile({
    String? name,
    String? phoneNumber,
    Platform? platform,
    String? psId,
  }) async {
    if (_currentUser == null) return false;

    try {
      Map<String, dynamic> updates = {
        'updatedAt': Timestamp.now(),
      };

      if (name != null) updates['name'] = name;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (platform != null) updates['platform'] = platform.value;
      if (psId != null) updates['psId'] = psId;

      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update(updates);

      _currentUser = _currentUser!.copyWith(
        name: name ?? _currentUser!.name,
        phoneNumber: phoneNumber ?? _currentUser!.phoneNumber,
        platform: platform ?? _currentUser!.platform,
        psId: psId ?? _currentUser!.psId,
        updatedAt: DateTime.now(),
      );

      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  // Check if email is already registered
  Future<bool> isEmailRegistered(String email) async {
    try {
      final methods =
      await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
