import 'dart:convert';

import 'package:ef_race_pages/models/race.dart';
import 'package:ef_race_pages/models/user_settings.dart';
import 'package:ef_race_pages/services/race_service.dart';
import 'package:ef_race_pages/services/recent_event_manager.dart';
import 'package:ef_race_pages/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_env.dart';

Race race(String id, {String? reg}) => Race(
    id: id,
    date: 'Sat 6/13/2026',
    location: 'Bangor',
    name: 'Race $id',
    registrationUrl: reg);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(usePrefs);

  group('RaceService.saveRace / getRace', () {
    test('round-trips a race', () async {
      await RaceService.saveRace(race('7', reg: 'https://r/7'));
      final got = await RaceService.getRace('7');
      expect(got!.name, 'Race 7');
      expect(got.registrationUrl, 'https://r/7');
    });

    test('unknown race yields a placeholder, never null', () async {
      final got = await RaceService.getRace('999');
      expect(got, isNotNull);
      expect(got!.name, 'Unknown: 999');
      expect(got.date, '');
      expect(got.registrationUrl, isNull);
    });

    test('a corrupt stored race throws instead of falling back', () async {
      usePrefs({'5': 'not json'});
      expect(RaceService.getRace('5'), throwsFormatException);
    });
  });

  group('RaceService.getAllRaces', () {
    test('returns races when only races are stored', () async {
      await RaceService.saveRace(race('1'));
      await RaceService.saveRace(race('2'));
      final all = await RaceService.getAllRaces();
      expect(all.map((r) => r.id), unorderedEquals(['1', '2']));
    });

    test('skips non-race prefs stored alongside races', () async {
      // Races share the SharedPreferences namespace with currentRace,
      // recentRaces, userSettings and previous_race_id. getAllRaces used to
      // decode every key as a Race and throw in any real install.
      await RaceService.saveRace(race('1'));
      await saveCurrentRace('1');
      await addRaceToRecentList('1');
      final all = await RaceService.getAllRaces();
      expect(all.map((r) => r.id), ['1']);
    });
  });

  group('RaceService.getRegistrationUrl', () {
    test('returns the cached URL without touching the network', () async {
      await RaceService.saveRace(race('3', reg: 'https://cached/3'));
      final calls = <Uri>[];
      final url = await withHttp(routeClient({}, log: calls),
          () => RaceService.getRegistrationUrl('3'));
      expect(url, 'https://cached/3');
      expect(calls, isEmpty);
    });

    test('scrapes #MoreInfo from the results page and caches it', () async {
      await RaceService.saveRace(race('4'));
      final client = routeClient({
        'race-results/?ID=4': () => utf8Response(
            '<div id="MoreInfo"><a href="https://reg/4">More</a></div>'),
      });
      final url =
          await withHttp(client, () => RaceService.getRegistrationUrl('4'));
      expect(url, 'https://reg/4');
      expect(
          (await RaceService.getRace('4'))!.registrationUrl, 'https://reg/4');
    });

    test('unknown race: caches the URL under a placeholder race', () async {
      final client = routeClient({
        'ID=8': () => utf8Response(
            '<div id="MoreInfo"><a href="https://reg/8">x</a></div>'),
      });
      await withHttp(client, () => RaceService.getRegistrationUrl('8'));
      final stored = await RaceService.getRace('8');
      expect(stored!.name, 'Unknown: 8');
      expect(stored.registrationUrl, 'https://reg/8');
    });

    for (final c in <String, http.Response Function()>{
      'no MoreInfo link': () => utf8Response('<html></html>'),
      'HTTP 500': () => http.Response('boom', 500),
    }.entries) {
      test('falls back to the home page on ${c.key}', () async {
        final url = await withHttp(routeClient({'ID=9': c.value}),
            () => RaceService.getRegistrationUrl('9'));
        expect(url, 'https://www.elitefeats.com');
      });
    }

    test('falls back to the home page when the request throws', () async {
      final client = routeClientThrowing(Exception('offline'));
      final url =
          await withHttp(client, () => RaceService.getRegistrationUrl('9'));
      expect(url, 'https://www.elitefeats.com');
    });
  });

  group('recent_event_manager', () {
    test('adds races newest-first without duplicates', () async {
      await addRaceToRecentList('1');
      await addRaceToRecentList('2');
      await addRaceToRecentList('1');
      expect(await getRecentRaces(), ['2', '1']);
    });

    test('removes a single race', () async {
      await addRaceToRecentList('1');
      await addRaceToRecentList('2');
      await removeRaceFromRecentList('1');
      expect(await getRecentRaces(), ['2']);
    });

    test('removing an absent race is a no-op', () async {
      await removeRaceFromRecentList('nope');
      expect(await getRecentRaces(), isEmpty);
    });

    test('clears all recent races', () async {
      await addRaceToRecentList('1');
      await clearAllRecentRaces();
      expect(await getRecentRaces(), isEmpty);
    });

    test('saves, reads and clears the current race', () async {
      expect(await getCurrentRace(), isNull);
      await saveCurrentRace('12');
      expect(await getCurrentRace(), '12');
      await clearCurrentRace();
      expect(await getCurrentRace(), isNull);
    });
  });

  group('SettingsService', () {
    test('returns defaults when nothing is saved', () async {
      final s = await SettingsService.loadUserSettings();
      expect(s.fieldVisibility, UserSettings.getDefault().fieldVisibility);
    });

    test('persists and reloads settings', () async {
      final s = UserSettings.getDefault()..fieldVisibility['team'] = true;
      expect(await SettingsService.saveUserSettings(s), isTrue);
      final back = await SettingsService.loadUserSettings();
      expect(back.fieldVisibility['team'], isTrue);
    });

    test('notifies listeners on save and stops after removal', () async {
      var calls = 0;
      void l() => calls++;
      SettingsService.addListener(l);
      await SettingsService.saveUserSettings(UserSettings.getDefault());
      SettingsService.removeListener(l);
      await SettingsService.saveUserSettings(UserSettings.getDefault());
      expect(calls, 1);
    });

    test('a corrupt saved blob falls back to defaults', () async {
      // This used to throw into SearchPage/SettingsPage, which never caught it.
      usePrefs({
        'userSettings': jsonEncode({'fieldVisibility': {}})
      });
      final s = await SettingsService.loadUserSettings();
      expect(s.fieldVisibility, UserSettings.getDefault().fieldVisibility);
    });
  });

  test('prefs helper isolates tests', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
