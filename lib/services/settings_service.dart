import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/user_settings.dart';

class SettingsService {
  static const _settingsKey = 'userSettings';
  static final _listeners = <Function>[];

  static void addListener(Function callback) {
    _listeners.add(callback);
  }

  static void removeListener(Function callback) {
    _listeners.remove(callback);
  }

  // Save settings
  static Future<bool> saveUserSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    bool success = await prefs.setString(_settingsKey, jsonEncode(settings.toMap()));

    for (var listener in _listeners) {
      listener();
    }
    return success;

  }

  // Load settings
  static Future<UserSettings> loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_settingsKey)) {
      Map<String, dynamic> settingsMap = jsonDecode(prefs.getString(_settingsKey)!);
      return UserSettings.fromMap(settingsMap);
    }
    return UserSettings.getDefault();
  }

}
