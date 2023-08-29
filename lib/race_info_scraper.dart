import 'package:ef_race_pages/race.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

Future<List<Race>> fetchRaces() async {
  try {
    final response = await http.get(Uri.parse('http://elitefeats.com/upcoming')).timeout(const Duration(seconds: 20));
    if (response.statusCode == 200 && response.body.isNotEmpty) {
      var document = parse(response.body);
      List<Race> races = [];

      for (var section in document.querySelectorAll('section.post')) {
        var date = section.querySelector('.BlueDateDiv')?.text ?? section.querySelector('.RedDateDiv')?.text;
        var location = section.querySelector('div[style="text-align:center"] h3')?.text.trim();
        var name = section.querySelector('h3[style="text-align:center;font-size: 1.2em"]')?.text.trim();
        var id = section.querySelector('a[href^="../race-results.asp?ID="]')?.attributes['href']?.split('=').last;

        if (id != null && date != null && location != null && name != null) {
          races.add(Race(id: id, date: date, location: location, name: name));
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

