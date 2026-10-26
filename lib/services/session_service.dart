import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';

class SessionService extends ChangeNotifier {
  static const _tokenKey = 'auth_token', _userKey = 'auth_user';
  String? token;
  AppUser? user;
  bool ready = false;
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey);
    final json = prefs.getString(_userKey);
    if (json != null) { try { user = AppUser.fromJson(jsonDecode(json) as Map<String, dynamic>); } catch (_) {} }
    ready = true;
    notifyListeners();
  }
  Future<void> save(String newToken, AppUser newUser) async {
    final prefs = await SharedPreferences.getInstance();
    token = newToken; user = newUser;
    await prefs.setString(_tokenKey, newToken);
    await prefs.setString(_userKey, jsonEncode(newUser.toJson()));
    notifyListeners();
  }
  Future<void> updateUser(AppUser newUser) async {
    user = newUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(newUser.toJson()));
    notifyListeners();
  }
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey); await prefs.remove(_userKey);
    token = null; user = null; notifyListeners();
  }
}
