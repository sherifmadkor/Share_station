import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  // Language settings
  Locale _locale = const Locale('en', '');
  Locale get locale => _locale;

  // Theme settings
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  // Remember me settings
  bool _rememberMe = false;
  bool get rememberMe => _rememberMe;

  String? _savedEmail;
  String? get savedEmail => _savedEmail;

  String? _savedPassword;
  String? get savedPassword => _savedPassword;

  // Borrow window settings (admin controlled)
  bool _isBorrowWindowOpen = false;
  bool get isBorrowWindowOpen => _isBorrowWindowOpen;

  DateTime? _nextBorrowWindow;
  DateTime? get nextBorrowWindow => _nextBorrowWindow;

  AppProvider(this._prefs) {
    _loadSettings();
  }

  // Load saved settings from SharedPreferences
  void _loadSettings() {
    // Load language
    final languageCode = _prefs.getString('language_code') ?? 'en';
    _locale = Locale(languageCode, '');

    // Load theme
    final themeIndex = _prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];

    // Load remember me settings
    _rememberMe = _prefs.getBool('remember_me') ?? false;
    if (_rememberMe) {
      _savedEmail = _prefs.getString('saved_email');
      _savedPassword = _prefs.getString('saved_password');
    }

    // Load borrow window settings
    _isBorrowWindowOpen = _prefs.getBool('borrow_window_open') ?? false;
    final windowTimestamp = _prefs.getInt('next_borrow_window');
    if (windowTimestamp != null) {
      _nextBorrowWindow = DateTime.fromMillisecondsSinceEpoch(windowTimestamp);
    } else {
      // Default to next Friday
      _calculateNextFriday();
    }

    notifyListeners();
  }

  // Change app language
  Future<void> changeLanguage(String languageCode) async {
    if (languageCode != _locale.languageCode) {
      _locale = Locale(languageCode, '');
      await _prefs.setString('language_code', languageCode);
      notifyListeners();
    }
  }

  // Toggle between Arabic and English
  Future<void> toggleLanguage() async {
    final newLanguage = _locale.languageCode == 'en' ? 'ar' : 'en';
    await changeLanguage(newLanguage);
  }

  // Change theme mode
  Future<void> changeThemeMode(ThemeMode mode) async {
    if (mode != _themeMode) {
      _themeMode = mode;
      await _prefs.setInt('theme_mode', mode.index);
      notifyListeners();
    }
  }

  // Toggle theme between light and dark
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await changeThemeMode(newMode);
  }

  // Save login credentials
  Future<void> saveCredentials(String email, String password, bool remember) async {
    _rememberMe = remember;
    await _prefs.setBool('remember_me', remember);

    if (remember) {
      _savedEmail = email;
      _savedPassword = password;
      await _prefs.setString('saved_email', email);
      await _prefs.setString('saved_password', password);
    } else {
      _savedEmail = null;
      _savedPassword = null;
      await _prefs.remove('saved_email');
      await _prefs.remove('saved_password');
    }
    notifyListeners();
  }

  // Clear saved credentials
  Future<void> clearCredentials() async {
    _rememberMe = false;
    _savedEmail = null;
    _savedPassword = null;
    await _prefs.setBool('remember_me', false);
    await _prefs.remove('saved_email');
    await _prefs.remove('saved_password');
    notifyListeners();
  }

  // Toggle borrow window (Admin only)
  Future<void> toggleBorrowWindow(bool isOpen) async {
    _isBorrowWindowOpen = isOpen;
    await _prefs.setBool('borrow_window_open', isOpen);

    if (!isOpen) {
      _calculateNextFriday();
    }

    notifyListeners();
  }

  // Calculate next Friday
  void _calculateNextFriday() {
    final now = DateTime.now();
    int daysUntilFriday = DateTime.friday - now.weekday;
    if (daysUntilFriday <= 0) {
      daysUntilFriday += 7;
    }
    _nextBorrowWindow = DateTime(
      now.year,
      now.month,
      now.day + daysUntilFriday,
      0, 0, 0, // Midnight
    );
    _prefs.setInt('next_borrow_window', _nextBorrowWindow!.millisecondsSinceEpoch);
  }

  // Check if borrow window is currently open
  bool isBorrowWindowCurrentlyOpen() {
    if (_isBorrowWindowOpen) return true; // Admin override

    final now = DateTime.now();
    // Check if it's Friday (weekday == 5)
    return now.weekday == DateTime.friday;
  }

  // Get time until next borrow window
  Duration? getTimeUntilNextWindow() {
    if (_isBorrowWindowOpen) return null; // Window is always open
    if (_nextBorrowWindow == null) return null;

    final now = DateTime.now();
    if (now.weekday == DateTime.friday) {
      return Duration.zero; // Window is open today
    }

    return _nextBorrowWindow!.difference(now);
  }

  // Format duration for display
  String formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '$days ${days == 1 ? "day" : "days"}, $hours ${hours == 1 ? "hour" : "hours"}';
    } else if (hours > 0) {
      return '$hours ${hours == 1 ? "hour" : "hours"}, $minutes ${minutes == 1 ? "minute" : "minutes"}';
    } else {
      return '$minutes ${minutes == 1 ? "minute" : "minutes"}';
    }
  }

  // Check if user is using Arabic
  bool get isArabic => _locale.languageCode == 'ar';

  // Check if dark mode is enabled
  bool get isDarkMode => _themeMode == ThemeMode.dark;
}