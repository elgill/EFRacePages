import 'dart:convert';
import 'dart:io';

import 'package:ef_race_pages/pages/search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite/sqflite.dart';

import '../helpers/test_env.dart';

const raceId = '500';

final roster = bibCsv([
  csvRow(101, 'Ann', 'Alpha',
      gender: 'F', division: 'F30-39', shirt: 'Small', team: 'Harriers'),
  csvRow(102, 'Bob', 'Bravo', division: 'M30-39', shirt: 'Medi'),
  csvRow(103, 'Cat', 'Charlie',
      gender: 'F', division: 'F20-29', shirt: 'Smal', team: 'Harriers'),
  csvRow(150, 'Dan', 'Delta', division: 'M40-49', shirt: 'Large'),
  csvRow(210, 'Eve', 'Echo',
      gender: 'F', division: 'F40-49', shirt: 'noThankYou'),
]);

/// The roster download normally takes longer than the local DB query that
/// initState also kicks off. Functional tests keep that ordering; the
/// regression group covers the cases where it does not hold.
const realisticLatency = Duration(milliseconds: 500);

MockClient csvClient(String body,
        {int status = 200, Duration delay = realisticLatency}) =>
    routeClient(
        {'Bibs/?ID=$raceId&csv=yesplease': () => utf8Response(body, status)},
        delay: delay);

/// Pumps a SearchPage inside a Scaffold (it shows SnackBars) and lets the
/// initial load settle.
Future<void> pumpSearch(WidgetTester tester, http.Client client,
    {bool waitForLoad = true}) async {
  await withHttp(client, () async {
    await tester.pumpWidget(
        wrapInApp(const Scaffold(body: SearchPage(raceId: raceId))));
    if (waitForLoad) await settle(tester);
  });
}

List<String> shownNames(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((t) => (t.title as Text).data!)
    .toList();

Future<void> search(WidgetTester tester, String q) async {
  await tester.enterText(find.byType(TextField), q);
  await settle(tester);
}

void main() {
  late Directory dbDir;

  setUp(() async {
    // Same race as last time, so initState also runs a search immediately.
    usePrefs({'previous_race_id': raceId});
    dbDir = await useTempSqflite();
  });

  tearDown(() async {
    if (await dbDir.exists()) await dbDir.delete(recursive: true);
  });

  group('loading', () {
    testWidgets('downloads the roster and lists everyone by bib',
        (tester) async {
      await pumpSearch(tester, csvClient(roster));
      expect(find.text('Results: 5'), findsOneWidget);
      expect(shownNames(tester).first, 'Alpha, Ann');
      expect(find.text('Updated 5 participants'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('skips malformed CSV lines', (tester) async {
      final csv = bibCsv([csvRow(1, 'A', 'B'), '2,Only,Three']);
      await pumpSearch(tester, csvClient(csv));
      expect(find.text('Results: 1'), findsOneWidget);
    });

    testWidgets('shows a parse error when bibs are not posted', (tester) async {
      await pumpSearch(tester, csvClient('', status: 404));
      expect(find.textContaining('Are bibs posted'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('header-only CSV reports nothing to update', (tester) async {
      await pumpSearch(tester, csvClient(csvHeader));
      expect(find.textContaining('No data available'), findsOneWidget);
    });

    testWidgets('no connectivity reports an internet error', (tester) async {
      await pumpSearch(
          tester, routeClientThrowing(const SocketException('offline')));
      expect(find.textContaining('No Internet connection'), findsOneWidget);
    });

    testWidgets('switching race clears the previous race roster',
        (tester) async {
      // Seed the db with someone from another race (real I/O → runAsync).
      await tester.runAsync(() async {
        final db = await openDatabase('race_data.db',
            version: 1,
            onCreate: (db, _) => db.execute(
                'CREATE TABLE bib_data (id INTEGER PRIMARY KEY AUTOINCREMENT, bib INTEGER, name TEXT, age INTEGER, gender TEXT, city TEXT, state TEXT, division TEXT, team TEXT, t_shirt TEXT, extra TEXT, status TEXT)'));
        await db.insert('bib_data', {'bib': 9, 'name': 'Old, Racer'});
        await db.close();
      });
      usePrefs({'previous_race_id': 'other'});

      await pumpSearch(tester, csvClient('', status: 500));
      await search(tester, 'Old');
      expect(find.text('Results: 0'), findsOneWidget);
    });
  });

  group('query language', () {
    final cases = <String, List<String>>{
      '102': ['Bravo, Bob'],
      'charlie': ['Charlie, Cat'],
      '101-103': ['Alpha, Ann', 'Bravo, Bob', 'Charlie, Cat'],
      '101/150': ['Alpha, Ann', 'Delta, Dan'],
      // N? = bib N ± (number of ?s)
      '102?': ['Alpha, Ann', 'Bravo, Bob', 'Charlie, Cat'],
      '10?': [], // bib 9..11, nobody
      'division:F & team:harriers': ['Alpha, Ann', 'Charlie, Cat'],
      '!101-150': ['Echo, Eve'],
      'gender:F & !Alpha': ['Charlie, Cat', 'Echo, Eve'],
      // Unknown field names are ignored, so the term matches everyone.
      'bogusfield:x': [
        'Alpha, Ann',
        'Bravo, Bob',
        'Charlie, Cat',
        'Delta, Dan',
        'Echo, Eve'
      ],
    };

    for (final c in cases.entries) {
      testWidgets('"${c.key}"', (tester) async {
        await pumpSearch(tester, csvClient(roster));
        await search(tester, c.key);
        expect(shownNames(tester), c.value);
      });
    }

    testWidgets('sort toggle reverses bib order', (tester) async {
      await pumpSearch(tester, csvClient(roster));
      await tester.tap(find.byTooltip('Toggle Sort Order'));
      await settle(tester);
      expect(shownNames(tester).first, 'Echo, Eve');
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('clear button resets the search', (tester) async {
      await pumpSearch(tester, csvClient(roster));
      await search(tester, '102');
      await tester.tap(find.byIcon(Icons.clear));
      await settle(tester);
      expect(find.text('Results: 5'), findsOneWidget);
    });
  });

  group('display', () {
    testWidgets('subtitle shows only fields enabled in settings',
        (tester) async {
      await pumpSearch(tester, csvClient(roster));
      expect(find.text('Bib: 101'), findsOneWidget);
      expect(find.text('Division: F30-39'), findsOneWidget);
      expect(find.text('T_shirt: Small'), findsOneWidget);
      expect(find.text('Team: Harriers'), findsNothing);
    });

    testWidgets('stats dialog aggregates and normalizes sizes', (tester) async {
      await pumpSearch(tester, csvClient(roster));
      // The floating "Updated N" snackbar sits over the FAB; dismiss it.
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      await settle(tester);
      await tester.tap(find.byIcon(Icons.analytics));
      await settle(tester);
      expect(find.text('Statistics'), findsOneWidget);
      expect(find.text('Small: 2'), findsOneWidget); // "Small" + "Smal"
      expect(find.text('Medium: 1'), findsOneWidget); // "Medi"
      expect(find.text('No T-Shirt: 1'), findsOneWidget);
      expect(find.text('Harriers: 2'), findsOneWidget);
      expect(find.text('F: 3'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(find.text('Statistics'), findsNothing);
    });
  });

  // ------------------------------------------------------------------------
  // Regression tests for crashes found while adding this suite. Comments
  // describe the original failure mode; each test failed before the fix.
  // ------------------------------------------------------------------------
  group('regression', () {
    testWidgets(
        'roster download beats the startup query: shared DB closed mid-write',
        (tester) async {
      // initState runs _checkAndClearDbIfNeeded (→ _searchDatabase) and
      // _loadData (→ storeDataLocally) concurrently. If the download returns
      // before the local query finishes (fast network, slow disk), the query
      // closes the shared DB under the insert transaction. The error is
      // swallowed and the user sees "Failed to parse data" with no roster.
      await pumpSearch(tester, csvClient(roster, delay: Duration.zero));
      expect(find.textContaining('Are bibs posted'), findsNothing);
      expect(find.text('Results: 5'), findsOneWidget);
    });

    testWidgets(
        'typing while a search is in flight: shared DB closed under another query',
        (tester) async {
      // Every helper in SearchPage used to do openDatabase → work → close().
      // sqflite returns ONE shared instance per path, so whichever call
      // closed first killed the others mid-query: database_closed.
      // Now the page uses BibDatabase.instance, which stays open.
      await pumpSearch(tester, csvClient(roster));
      final field = tester.widget<TextField>(find.byType(TextField));
      for (final q in ['1', '10', '102']) {
        field.onChanged!(q); // keystrokes arriving faster than the DB
      }
      await settle(tester);
      expect(find.text('Results: 1'), findsOneWidget);
    });

    testWidgets(
        'opening Stats while the roster is being stored: shared DB closed',
        (tester) async {
      await pumpSearch(tester, csvClient(roster));
      // Pull-to-refresh (re-download + store) then immediately tap Stats.
      await withHttp(csvClient(roster), () async {
        final refresh =
            tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
        refresh.onRefresh();
        await tester.pump(realisticLatency); // download done, store begins
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed!();
        await settle(tester);
      });
      expect(find.text('Statistics'), findsOneWidget);
    });

    testWidgets(
        'leaving the Search tab before the roster download finishes',
        (tester) async {
      // RaceWebPages does not keep SearchPage alive, so switching tabs or
      // races disposes it. _loadData has no HTTP timeout and its `finally`
      // used to call setState unconditionally.
      final requests = <Uri>[];
      final slow = routeClient({
        'csv=yesplease': () => utf8Response(roster),
      }, delay: const Duration(seconds: 3), log: requests);
      await pumpSearch(tester, slow, waitForLoad: false);
      await withHttp(slow, () async {
        await settle(tester, rounds: 3); // startup reaches the download
        expect(requests, isNotEmpty, reason: 'download must be in flight');
        await tester
            .pumpWidget(wrapInApp(const Scaffold(body: Text('elsewhere'))));
        await tester.pump(const Duration(seconds: 4)); // download completes
        await settle(tester);
      });
      expect(find.text('elsewhere'), findsOneWidget);
    });

    testWidgets(
        'corrupt saved settings fall back to defaults instead of crashing',
        (tester) async {
      // loadUserSettings throws (uncaught), so the `late _userSettings` is
      // never assigned and anything that reads it (result rows, field:
      // queries) throws LateInitializationError.
      usePrefs({
        'previous_race_id': raceId,
        'userSettings': jsonEncode({
          'fieldVisibility': {'bib': true}
        }),
      });
      await pumpSearch(tester, csvClient(roster));
      expect(find.text('Results: 5'), findsOneWidget);
    });
  });
}
