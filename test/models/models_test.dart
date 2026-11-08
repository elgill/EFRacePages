import 'dart:convert';

import 'package:ef_race_pages/models/race.dart';
import 'package:ef_race_pages/models/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Race', () {
    test('round-trips through JSON', () {
      final r = Race(
          id: '42',
          date: 'Sat 6/13/2026',
          location: 'Bangor, ME',
          name: 'Beer Run',
          registrationUrl: 'https://reg.example/42');
      final back = Race.fromJson(json.decode(json.encode(r.toJson())));
      expect(back.id, '42');
      expect(back.date, 'Sat 6/13/2026');
      expect(back.location, 'Bangor, ME');
      expect(back.name, 'Beer Run');
      expect(back.registrationUrl, 'https://reg.example/42');
    });

    test('registrationUrl is optional', () {
      final r = Race(id: '1', date: 'd', location: 'l', name: 'n');
      expect(Race.fromJson(r.toJson()).registrationUrl, isNull);
    });

    test('toString includes the identifying fields', () {
      final r = Race(id: '1', date: 'd', location: 'l', name: 'n');
      expect(r.toString(), 'ID: 1, Date: d, Location: l, Name: n');
    });

    test('fromJson throws on a record missing a required field', () {
      // Anything that persists a partial race will make every later read of
      // it throw. Documented so a change in this behaviour is deliberate.
      expect(() => Race.fromJson({'id': '1', 'date': 'd', 'location': 'l'}),
          throwsA(isA<TypeError>()));
    });
  });

  group('UserSettings', () {
    test('defaults show bib, division and t-shirt only', () {
      final s = UserSettings.getDefault();
      final visible = s.fieldVisibility.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toSet();
      expect(visible, {'bib', 'division', 't_shirt'});
      expect(s.normalizeTShirtSizes, isFalse);
    });

    test('defaults cover every bib_data column the search page can show', () {
      expect(UserSettings.getDefault().fieldVisibility.keys.toSet(), {
        'bib',
        'name',
        'age',
        'gender',
        'city',
        'state',
        'division',
        'team',
        't_shirt',
        'extra',
        'status',
      });
    });

    test('getDefault returns independent instances', () {
      final a = UserSettings.getDefault();
      a.fieldVisibility['name'] = true;
      expect(UserSettings.getDefault().fieldVisibility['name'], isFalse);
    });

    test('round-trips through the JSON form SettingsService stores', () {
      final s = UserSettings.getDefault()
        ..fieldVisibility['name'] = true
        ..normalizeTShirtSizes = true;
      final back = UserSettings.fromMap(jsonDecode(jsonEncode(s.toMap())));
      expect(back.fieldVisibility, s.fieldVisibility);
      expect(back.normalizeTShirtSizes, isTrue);
    });

    test('fromMap throws when normalizeTShirtSizes is missing', () {
      expect(
          () => UserSettings.fromMap({
                'fieldVisibility': {'bib': true}
              }),
          throwsA(isA<TypeError>()));
    });

    test('fromMap throws when a visibility value is not a bool', () {
      expect(
          () => UserSettings.fromMap({
                'fieldVisibility': {'bib': 'yes'},
                'normalizeTShirtSizes': false,
              }),
          throwsA(isA<TypeError>()));
    });
  });
}
