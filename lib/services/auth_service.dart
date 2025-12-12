import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Future<bool> register(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Простая хэш-функция для пароля
    final passwordHash = sha256.convert(utf8.encode(password)).toString();
    
    await prefs.setString('user_email', email);
    await prefs.setString('user_password_hash', passwordHash);
    await prefs.setBool('is_logged_in', true);
    
    return true;
  }

  Future<bool> login(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('user_email');
    final savedHash = prefs.getString('user_password_hash');
    
    if (savedEmail == email) {
      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      if (passwordHash == savedHash) {
        await prefs.setBool('is_logged_in', true);
        return true;
      }
    }
    
    return false;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  Future<String?> getCurrentEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
  }
}