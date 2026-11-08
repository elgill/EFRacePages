import 'package:ef_race_pages/race_info_scraper.dart';
import 'package:ef_race_pages/services/race_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(usePrefs);

  Future<T> serve<T>(http.Response Function() res, Future<T> Function() f) =>
      withHttp(routeClient({'elitefeats.com/upcoming': res}), f);

  test('parses races and persists each one', () async {
    final html = upcomingPage([
      upcomingSection(
          id: '101',
          name: 'Turkey Trot',
          location: 'Portland, ME',
          date: 'Thu 11/26/2026',
          registrationHref: 'https://reg/101'),
      upcomingSection(
          id: '102',
          name: 'Jingle Run',
          location: 'Bangor, ME',
          date: 'Sat 12/5/2026'),
    ]);
    final races = await serve(() => utf8Response(html), fetchRaces);

    expect(races.map((r) => r.id), ['101', '102']);
    expect(races.first.name, 'Turkey Trot');
    expect(races.first.location, 'Portland, ME');
    expect(races.first.date, 'Thu 11/26/2026');
    expect(races.first.registrationUrl, 'https://reg/101');

    final stored = await RaceService.getRace('102');
    expect(stored!.name, 'Jingle Run');
  });

  test('stars races that use the red date badge', () async {
    final html = upcomingPage([
      upcomingSection(
          id: '5', name: 'Featured', location: 'X', date: 'D', red: true),
    ]);
    final races = await serve(() => utf8Response(html), fetchRaces);
    expect(races.single.name, '★ Featured');
  });

  test('decodes UTF-8 names correctly', () async {
    final html = upcomingPage([
      upcomingSection(
          id: '6', name: 'Café 5K – Montréal', location: 'QC', date: 'D'),
    ]);
    final races = await serve(() => utf8Response(html), fetchRaces);
    expect(races.single.name, 'Café 5K – Montréal');
  });

  test('skips sections missing an id, date, location or name', () async {
    final html = upcomingPage([
      '<section class="post"><div class="BlueDateDiv">D</div></section>',
      upcomingSection(id: '7', name: 'Ok', location: 'L', date: 'D'),
    ]);
    final races = await serve(() => utf8Response(html), fetchRaces);
    expect(races.map((r) => r.id), ['7']);
  });

  test('empty listing returns an empty list', () async {
    final races = await serve(() => utf8Response(upcomingPage([])), fetchRaces);
    expect(races, isEmpty);
  });

  for (final c in <String, http.Response Function()>{
    'HTTP 503': () => http.Response('down', 503),
    'empty body': () => http.Response('', 200),
  }.entries) {
    test('throws on ${c.key}', () async {
      await expectLater(serve(c.value, fetchRaces), throwsException);
    });
  }

  test('throws on network failure', () async {
    await expectLater(
        withHttp(routeClientThrowing(Exception('offline')), fetchRaces),
        throwsException);
  });
}
