import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/race.dart';

class RaceService {
  static Future<void> saveRace(Race race) async {
    final prefs = await SharedPreferences.getInstance();
    final key = race.id;
    final value = json.encode(race.toJson()); // Convert Race object to JSON string
    prefs.setString(key, value); // Save JSON string in SharedPreferences
  }

  static Future<Race?> getRace(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(id); // Retrieve JSON string by id
    if (jsonString != null) {
      final jsonData = json.decode(jsonString); // Convert JSON string to Map
      return Race.fromJson(jsonData); // Convert Map to Race object
    }
    return null; // Return null if id does not exist in SharedPreferences
  }

  static Future<List<Race>> getAllRaces() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final races = <Race>[];
    for (var key in keys) {
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        final jsonData = json.decode(jsonString);
        races.add(Race.fromJson(jsonData));
      }
    }
    return races; // Return a list of all Race objects stored in SharedPreferences
  }
}
