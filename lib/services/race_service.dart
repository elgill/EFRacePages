import 'dart:convert';
import 'dart:developer';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
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
    } else{
      return Race(id: id, date: '', location: '', name: 'Unknown: $id');
    }
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

  static Future<String?> getRegistrationUrl(String raceId) async {
    try {
      // First check if we have a cached race with registration URL
      Race? race = await getRace(raceId);
      if (race?.registrationUrl != null) {
        return race!.registrationUrl;
      }

      // If no registration URL, fetch from results page
      final response = await http
          .get(Uri.parse('https://www.elitefeats.com/race-results/?ID=$raceId'))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        var document = parse(response.body);

        // Look for registration link in "More info" section
        var moreInfoLink = document.querySelector('#MoreInfo a');
        if (moreInfoLink != null) {
          var url = moreInfoLink.attributes['href'];

          // If we found a URL and have race data, update it
          if (url != null && race != null) {
            final updatedRace = Race(
                id: race.id,
                date: race.date,
                location: race.location,
                name: race.name,
                registrationUrl: url
            );
            await saveRace(updatedRace);
          }
          return url;
        }
      }
    } catch (e) {
      log('Error fetching registration URL for race $raceId: $e');
    }
    return 'https://www.elitefeats.com';
  }
}
