import 'package:shared_preferences/shared_preferences.dart';

Future<void> addRaceToRecentList(String raceId) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> recentRaces = prefs.getStringList('recentRaces') ?? [];
  if (!recentRaces.contains(raceId)) {
    recentRaces.insert(0, raceId);  // Add to the top for convenience
  }
  await prefs.setStringList('recentRaces', recentRaces);
}

Future<List<String>> getRecentRaces() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('recentRaces') ?? [];
}

Future<void> clearAllRecentRaces() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.remove('recentRaces');
}

Future<void> removeRaceFromRecentList(String raceId) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> recentRaces = prefs.getStringList('recentRaces') ?? [];
  recentRaces.remove(raceId);
  await prefs.setStringList('recentRaces', recentRaces);
}

Future<void> saveCurrentRace(String raceid) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('currentRace', raceid);
}

Future<String?> getCurrentRace() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('currentRace');
}

