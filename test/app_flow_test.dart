import 'dart:convert';

import 'package:ef_race_pages/main.dart';
import 'package:ef_race_pages/models/user_settings.dart';
import 'package:ef_race_pages/pages/more_page.dart';
import 'package:ef_race_pages/pages/settings_page.dart';
import 'package:ef_race_pages/race_id_setting_page.dart';
import 'package:ef_race_pages/race_web_pages.dart';
import 'package:ef_race_pages/services/recent_event_manager.dart';
import 'package:ef_race_pages/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/fake_webview_platform.dart';
import 'helpers/test_env.dart';

void main() {
  late FakeInAppWebViewPlatform platform;

  setUp(() async {
    usePrefs();
    platform = FakeInAppWebViewPlatform.install();
    await useTempSqflite();
  });

  final upcoming = upcomingPage([
    upcomingSection(
        id: '301',
        name: 'Harbor Run',
        location: 'Bar Harbor',
        date: 'Sat 7/4/2026',
        registrationHref: 'https://reg/301'),
    upcomingSection(
        id: '302',
        name: 'Hill Climb',
        location: 'Camden',
        date: 'Sun 7/5/2026'),
  ]);

  http.Client upcomingClient({int status = 200}) => routeClient({
        'elitefeats.com/upcoming': () => utf8Response(upcoming, status),
        'csv=yesplease': () => utf8Response(csvHeader),
      }, delay: const Duration(milliseconds: 200));

  group('MyApp start-up', () {
    testWidgets('first launch shows the race picker', (tester) async {
      await withHttp(upcomingClient(), () async {
        await tester.pumpWidget(const MyApp());
        await settle(tester);
      });
      expect(find.byType(RaceIDSettingPage), findsOneWidget);
    });

    testWidgets('returning user lands on their current race', (tester) async {
      usePrefs({
        'currentRace': '301',
        '301': jsonEncode({
          'id': '301',
          'date': 'd',
          'location': 'l',
          'name': 'Harbor Run',
          'registrationUrl': 'https://reg/301'
        }),
      });
      await withHttp(upcomingClient(), () async {
        await tester.pumpWidget(const MyApp());
        await settle(tester);
      });
      expect(find.byType(RaceWebPages), findsOneWidget);
      expect(find.text('Harbor Run'), findsOneWidget);
    });
  });

  group('RaceIDSettingPage', () {
    Future<void> pumpPicker(WidgetTester tester, http.Client client) =>
        withHttp(client, () async {
          await tester.pumpWidget(wrapInApp(const RaceIDSettingPage()));
          await settle(tester);
        });

    testWidgets('lists upcoming races', (tester) async {
      await pumpPicker(tester, upcomingClient());
      expect(find.text('Harbor Run'), findsOneWidget);
      expect(find.text('Camden on Sun 7/5/2026'), findsOneWidget);
      expect(find.text('302'), findsOneWidget);
    });

    testWidgets('tapping a race fills in its id', (tester) async {
      await pumpPicker(tester, upcomingClient());
      await tester.tap(find.text('Hill Climb'));
      await tester.pump();
      expect(find.widgetWithText(TextField, '302'), findsOneWidget);
    });

    testWidgets('saving opens the race and remembers it', (tester) async {
      await pumpPicker(tester, upcomingClient());
      await withHttp(upcomingClient(), () async {
        await tester.tap(find.text('Harbor Run'));
        await tester.tap(find.text('Save and View Race Pages'));
        await settle(tester);
      });
      expect(find.byType(RaceWebPages), findsOneWidget);
      expect(find.text('Harbor Run'), findsOneWidget);
      expect(await tester.runAsync(getCurrentRace), '301');
      expect(await tester.runAsync(getRecentRaces), ['301']);
    });

    testWidgets('a failed fetch shows an error with a working Retry',
        (tester) async {
      await pumpPicker(tester, upcomingClient(status: 500));
      expect(find.textContaining('Failed to fetch races'), findsOneWidget);
      await withHttp(upcomingClient(), () async {
        await tester.tap(find.text('Retry'));
        await settle(tester);
      });
      expect(find.text('Harbor Run'), findsOneWidget);
    });

    testWidgets('leaving before the list loads is safe', (tester) async {
      final client = upcomingClient();
      await withHttp(client, () async {
        await tester.pumpWidget(wrapInApp(const RaceIDSettingPage()));
        await tester.pumpWidget(wrapInApp(const Text('gone')));
        await settle(tester);
      });
      expect(find.text('gone'), findsOneWidget);
    });
  });

  group('SettingsPage', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      // Tall enough that the lazy ListView builds every checkbox.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrapInApp(SettingsPage()));
      await settle(tester, rounds: 3);
    }

    bool? checked(WidgetTester tester, String label) => tester
        .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, label))
        .value;

    testWidgets('shows a checkbox per field, reflecting saved settings',
        (tester) async {
      final s = UserSettings.getDefault()..fieldVisibility['team'] = true;
      await SettingsService.saveUserSettings(s);
      await pumpSettings(tester);
      expect(find.byType(CheckboxListTile),
          findsNWidgets(s.fieldVisibility.length));
      expect(checked(tester, 'Team'), isTrue);
      expect(checked(tester, 'Name'), isFalse);
    });

    testWidgets('toggling saves and notifies listeners', (tester) async {
      var notified = 0;
      void l() => notified++;
      SettingsService.addListener(l);
      addTearDown(() => SettingsService.removeListener(l));

      await pumpSettings(tester);
      await tester.tap(find.text('Name'));
      await settle(tester, rounds: 3);
      expect(checked(tester, 'Name'), isTrue);
      final saved = await tester.runAsync(SettingsService.loadUserSettings);
      expect(saved!.fieldVisibility['name'], isTrue);
      expect(notified, 1);
    });

    testWidgets('clear cookies reports success', (tester) async {
      await pumpSettings(tester);
      await tester.tap(find.text('Clear Browser Cookies'));
      await tester.pump();
      expect(platform.deleteAllCookiesCalls, 1);
      expect(find.text('Cookies cleared successfully'), findsOneWidget);
    });

    testWidgets('clear cookies reports failure', (tester) async {
      platform.deleteAllCookiesError = Exception('nope');
      await pumpSettings(tester);
      await tester.tap(find.text('Clear Browser Cookies'));
      await tester.pump();
      expect(find.textContaining('Failed to clear cookies'), findsOneWidget);
    });

    testWidgets('regression: corrupt saved settings open with defaults',
        (tester) async {
      usePrefs({
        'userSettings': jsonEncode({
          'fieldVisibility': {'bib': true}
        })
      });
      await pumpSettings(tester);
      expect(find.byType(CheckboxListTile), findsWidgets);
    });
  });

  group('MorePage', () {
    testWidgets('each card navigates to its page index', (tester) async {
      final hits = <int>[];
      await tester.pumpWidget(wrapInApp(
          Scaffold(body: MorePage(raceId: '1', onNavigateToPage: hits.add))));
      await tester.tap(find.text('Bib Reserve'));
      await tester.tap(find.text('Reader Status'));
      await tester.tap(find.text('Event Recap'));
      expect(hits, [5, 6, 7]);
    });
  });
}
