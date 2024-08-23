import 'package:ef_race_pages/models/race.dart';
import 'package:ef_race_pages/services/race_service.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'dart:convert';

Future<List<Race>> fetchRaces() async {
  try {
    final response = await http.get(Uri.parse('http://elitefeats.com/upcoming')).timeout(const Duration(seconds: 20));
    if (response.statusCode == 200 && response.body.isNotEmpty) {
      var document = parse(utf8.decode(response.bodyBytes));
      List<Race> races = [];

      for (var section in document.querySelectorAll('section.post')) {
        var isRedDate = section.querySelector('.RedDateDiv') != null;
        var date = section.querySelector('.BlueDateDiv')?.text ?? section.querySelector('.RedDateDiv')?.text;
        var location = section.querySelector('div[style="text-align:center"] h3')?.text.trim();
        var name = section.querySelector('h3[style="text-align:center;font-size: 1.2em"]')?.text.trim();

        // Add a star to the beginning of the name if it's from the red div
        if (isRedDate && name != null) {
          name = "★ $name";
        }

        var id = section.querySelector('a[href^="../race-results/?ID="]')?.attributes['href']?.split('=').last;

        if (id != null && date != null && location != null && name != null) {
          Race race= Race(id: id, date: date, location: location, name: name);
          races.add(race);
          await RaceService.saveRace(race);

        }
      }

      return races;
    } else {
      throw Exception('Failed to load race data. Invalid response or empty content.');
    }
  } catch (error) {
    throw Exception('Failed to fetch races due to a network error.');
  }
}

