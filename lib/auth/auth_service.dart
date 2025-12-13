// Import untuk shared_preferences
import 'package:shared_preferences/shared_preferences.dart';

// Service untuk handle autentikasi dan Remember Me
class AuthService {
  // Key untuk menyimpan data di SharedPreferences
  static const String _keyUsername = 'saved_username';
  static const String _keyRememberMe = 'remember_me_enabled';

  // Fungsi untuk menyimpan data login jika Remember Me dicentang
  static Future<void> saveLoginData(String username, bool rememberMe) async {
    // Ambil instance SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    
    // Jika Remember Me dicentang, simpan username
    if (rememberMe) {
      await prefs.setString(_keyUsername, username);
      await prefs.setBool(_keyRememberMe, true);
    } else {
      // Jika tidak dicentang, hapus data yang tersimpan
      await prefs.remove(_keyUsername);
      await prefs.setBool(_keyRememberMe, false);
    }
  }

  // Fungsi untuk mengambil data login yang tersimpan
  static Future<Map<String, dynamic>> getSavedLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Cek apakah Remember Me aktif
    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    
    // Jika Remember Me aktif, ambil username yang tersimpan
    if (rememberMe) {
      final username = prefs.getString(_keyUsername);
      return {
        'username': username ?? '',
        'rememberMe': true,
      };
    }
    
    // Jika tidak ada data yang tersimpan
    return {
      'username': '',
      'rememberMe': false,
    };
  }

  // Fungsi untuk logout (hapus semua data)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsername);
    await prefs.setBool(_keyRememberMe, false);
  }
}