import 'dart:io';

import 'package:ef_race_pages/models/race.dart';
import 'package:ef_race_pages/pages/settings_page.dart';
import 'package:ef_race_pages/race_id_setting_page.dart';
import 'package:ef_race_pages/race_web_pages.dart';
import 'package:ef_race_pages/services/race_service.dart';
import 'package:ef_race_pages/services/recent_event_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/fake_webview_platform.dart';
import 'helpers/test_env.dart';

final raceA = Race(
    id: '100',
    date: 'Sat 6/13/2026',
    location: 'Bangor',
    name: 'Alpha 5K',
    registrationUrl: 'https://reg/100');
final raceB = Race(
    id: '200',
    date: 'Sun 6/14/2026',
    location: 'Orono',
    name: 'Bravo 10K',
    registrationUrl: 'https://reg/200');

void main() {
  late FakeInAppWebViewPlatform platform;
  late Directory dbDir;
  late List<Uri> requests;
  late http.Client client;

  setUp(() async {
    platform = FakeInAppWebViewPlatform.install();
    dbDir = await useTempSqflite();
    usePrefs({
      raceA.id:
          '{"id":"100","date":"Sat 6/13/2026","location":"Bangor","name":"Alpha 5K","registrationUrl":"https://reg/100"}',
      raceB.id:
          '{"id":"200","date":"Sun 6/14/2026","location":"Orono","name":"Bravo 10K","registrationUrl":"https://reg/200"}',
      'recentRaces': ['100', '200'],
      'currentRace': '100',
      'previous_race_id': '100',
    });
    requests = [];
    client = routeClient({
      'csv=yesplease': () => utf8Response(bibCsv([csvRow(1, 'Ann', 'Alpha')])),
      'race-results/?ID=': () => utf8Response(
          '<div id="MoreInfo"><a href="https://scraped/reg">x</a></div>'),
      'elitefeats.com/upcoming': () => utf8Response(upcomingPage([])),
    }, delay: const Duration(milliseconds: 300), log: requests);
  });

  tearDown(() async {
    if (await dbDir.exists()) await dbDir.delete(recursive: true);
  });

  Future<void> pumpRace(WidgetTester tester, String id) =>
      withHttp(client, () async {
        await tester.pumpWidget(wrapInApp(RaceWebPages(raceId: id)));
        await settle(tester);
      });

  /// Runs [body] with HTTP mocked, since taps can create pages that fetch.
  Future<void> act(WidgetTester tester, Future<void> Function() body) =>
      withHttp(client, () async {
        await body();
        await settle(tester);
      });

  String appBarTitle(WidgetTester tester) => tester
      .widget<Text>(find
          .descendant(of: find.byType(AppBar), matching: find.byType(Text))
          .first)
      .data!;

  group('loading', () {
    testWidgets('shows the race name and its registration page',
        (tester) async {
      await pumpRace(tester, '100');
      expect(appBarTitle(tester), 'Alpha 5K');
      expect(platform.webViews.single.initialUrl, 'https://reg/100');
      expect(requests, isEmpty); // registration URL was cached
    });

    testWidgets('unknown race: scrapes the registration URL', (tester) async {
      await pumpRace(tester, '999');
      expect(appBarTitle(tester), 'Unknown: 999');
      expect(platform.webViews.single.initialUrl, 'https://scraped/reg');
    });
  });

  group('navigation', () {
    Future<void> tapNav(WidgetTester tester, String label) => act(
        tester,
        () => tester.tap(find.descendant(
            of: find.byType(BottomNavigationBar), matching: find.text(label))));

    int navIndex(WidgetTester tester) => tester
        .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
        .currentIndex;

    testWidgets('bottom tabs open the matching pages', (tester) async {
      await pumpRace(tester, '100');
      await tapNav(tester, 'Lookup');
      expect(platform.webViews.last.initialUrl,
          'https://www.elitefeats.com/Bibs/?ID=100');
      await tapNav(tester, 'Results');
      expect(platform.webViews.last.initialUrl,
          'https://www.elitefeats.com/race-results?ID=100');
      expect(navIndex(tester), 2);
      await tapNav(tester, 'Search');
      expect(find.text('Results: 1'), findsOneWidget);
    });

    testWidgets('webview tabs are kept alive between visits', (tester) async {
      await pumpRace(tester, '100');
      await tapNav(tester, 'Lookup');
      await tapNav(tester, 'Registration');
      await tapNav(tester, 'Lookup');
      expect(platform.webViews.length, 2); // registration + lookup, once each
    });

    testWidgets('Search tab is NOT kept alive: re-downloads every visit',
        (tester) async {
      // Characterization: each visit disposes and rebuilds SearchPage,
      // re-running its network + DB startup. This multiplies the chances of
      // hitting the SearchPage lifecycle races (see search_page_test.dart).
      await pumpRace(tester, '100');
      for (var i = 0; i < 3; i++) {
        await tapNav(tester, 'Search');
        await tapNav(tester, 'Lookup');
      }
      expect(requests.where((u) => u.query.contains('csv')).length, 3);
    });

    testWidgets('More → sub-pages, titled, with a back button', (tester) async {
      await pumpRace(tester, '100');
      await tapNav(tester, 'More');
      expect(find.text('More Options'), findsOneWidget);

      for (final (card, suffix, url) in [
        ('Bib Reserve', 'Bib Reserve', 'https://www.elitefeats.com/bibreserve'),
        (
          'Reader Status',
          'Reader Status',
          'https://elitefeats.com/ReaderStatus/'
        ),
        ('Event Recap', 'Event Recap', 'https://events.elitefeats.com/recap'),
      ]) {
        await act(tester, () => tester.tap(find.text(card)));
        expect(appBarTitle(tester), 'Alpha 5K - $suffix');
        expect(platform.webViews.last.initialUrl, url);
        expect(navIndex(tester), 4); // "More" stays highlighted
        await act(tester, () => tester.tap(find.byIcon(Icons.arrow_back)));
        expect(find.text('More Options'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
      }
    });

    testWidgets('settings button opens Settings', (tester) async {
      await pumpRace(tester, '100');
      await act(tester, () => tester.tap(find.byIcon(Icons.settings)));
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });

  group('drawer', () {
    Future<void> openDrawer(WidgetTester tester) => act(tester, () async {
          tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
        });

    testWidgets('lists recent races', (tester) async {
      await pumpRace(tester, '100');
      await openDrawer(tester);
      expect(find.text('Alpha 5K (100)'), findsOneWidget);
      expect(find.text('Bravo 10K (200)'), findsOneWidget);
    });

    testWidgets('tapping a race switches to it and remembers it',
        (tester) async {
      await pumpRace(tester, '100');
      await openDrawer(tester);
      await act(tester, () => tester.tap(find.text('Bravo 10K (200)')));
      expect(appBarTitle(tester), 'Bravo 10K');
      expect(await tester.runAsync(getCurrentRace), '200');
    });

    testWidgets('removing another race just updates the list', (tester) async {
      await pumpRace(tester, '100');
      await openDrawer(tester);
      await act(
          tester,
          () => tester.tap(find.descendant(
              of: find.widgetWithText(ListTile, 'Bravo 10K (200)'),
              matching: find.byIcon(Icons.clear))));
      expect(find.text('Bravo 10K (200)'), findsNothing);
      expect(appBarTitle(tester), 'Alpha 5K');
    });

    testWidgets('removing the current race moves to the next one',
        (tester) async {
      await pumpRace(tester, '100');
      await openDrawer(tester);
      await act(
          tester,
          () => tester.tap(find.descendant(
              of: find.widgetWithText(ListTile, 'Alpha 5K (100)'),
              matching: find.byIcon(Icons.clear))));
      expect(appBarTitle(tester), 'Bravo 10K');
    });

    testWidgets('removing the only race goes to Add Race', (tester) async {
      usePrefs({
        'recentRaces': ['100'],
        '100':
            '{"id":"100","date":"d","location":"l","name":"Alpha 5K","registrationUrl":"https://reg/100"}'
      });
      await pumpRace(tester, '100');
      await openDrawer(tester);
      await act(tester, () => tester.tap(find.byIcon(Icons.clear)));
      expect(find.byType(RaceIDSettingPage), findsOneWidget);
    });

    testWidgets('Add New Race pushes the race picker', (tester) async {
      await pumpRace(tester, '100');
      await openDrawer(tester);
      await act(tester, () => tester.tap(find.text('Add New Race')));
      expect(find.text('Add Race'), findsOneWidget);
    });

    testWidgets('Clear All forgets everything and goes to Add Race',
        (tester) async {
      await pumpRace(tester, '100');
      await openDrawer(tester);
      await act(tester, () => tester.tap(find.text('Clear All')));
      expect(find.byType(RaceIDSettingPage), findsOneWidget);
      expect(await tester.runAsync(getRecentRaces), isEmpty);
      expect(await tester.runAsync(getCurrentRace), isNull);
    });
  });

  group('regression', () {
    testWidgets('switching race from the drawer while Search is loading',
        (tester) async {
      // The real user path to the SearchPage dispose race: open Search,
      // then pick another race before the roster download completes.
      await pumpRace(tester, '100');
      // A roster download that outlives the ~300ms route transition, as on a
      // cellular connection at a race venue.
      final slow = routeClient({
        'csv=yesplease': () =>
            utf8Response(bibCsv([csvRow(1, 'Ann', 'Alpha')])),
      }, delay: const Duration(seconds: 2));
      await withHttp(slow, () async {
        await tester.tap(find.text('Search'));
        await tester.pump(); // Search starts its 2s download
        tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
        // Populate the drawer (200ms); the download is still in flight.
        await settle(tester, rounds: 4);
        expect(find.text('Results: 0'), findsOneWidget, // still loading
            reason: 'race switch must happen before the roster arrives');
        await tester.tap(find.text('Bravo 10K (200)'));
        await settle(tester, rounds: 60); // 3s: transition ends, download lands
      });
      expect(appBarTitle(tester), 'Bravo 10K');
    });
  });

  test('fixtures stay in sync with RaceService encoding', () async {
    usePrefs();
    await RaceService.saveRace(raceA);
    expect((await RaceService.getRace('100'))!.registrationUrl,
        raceA.registrationUrl);
  });
}
