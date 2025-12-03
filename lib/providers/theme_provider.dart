// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _key = 'isDarkMode';
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  
  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;

  ThemeProvider() {
    _loadFromPrefs();
  }

  void _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  void toggleTheme(bool isDark) async {
    _isDarkMode = isDark;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }

  // TAMBAHKAN METHOD INI
  void setTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.green,
    colorScheme: const ColorScheme.light(
      primary: Colors.green,
      secondary: Colors.blue,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFFE8F5E8),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.green.shade800,
    colorScheme: ColorScheme.dark(
      primary: Colors.green.shade800,
      secondary: Colors.lightBlue,
      surface: const Color(0xFF1E1E1E),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.green.shade800,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
    ),
  );
}