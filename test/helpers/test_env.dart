import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ef_race_pages/services/bib_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Points sqflite at a real (host) SQLite in a throwaway directory so each
/// test starts with an empty `race_data.db`.
///
/// Uses the no-isolate FFI factory so database futures complete under the
/// widget tester's fake async clock.
Future<Directory> useTempSqflite() async {
  BibDatabase.reset(); // drop the previous test's open connection
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  final dir = await Directory.systemTemp.createTemp('efrace_db_');
  await databaseFactory.setDatabasesPath(dir.path);
  return dir;
}

/// Resets SharedPreferences to [values] (the plugin's in-memory test store).
void usePrefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
}

/// Builds a [MockClient] that routes on URL substrings.
///
/// Unmatched requests return 404 so a test never silently hits the network.
/// [delay] simulates a slow server, which matters for lifecycle races.
MockClient routeClient(Map<String, http.Response Function()> routes,
    {Duration delay = Duration.zero, List<Uri>? log}) {
  return MockClient((req) async {
    log?.add(req.url);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    for (final e in routes.entries) {
      if (req.url.toString().contains(e.key)) return e.value();
    }
    return http.Response('not found: ${req.url}', 404);
  });
}

/// A client whose every request fails with [error] (e.g. no connectivity).
MockClient routeClientThrowing(Object error) =>
    MockClient((_) async => throw error);

http.Response utf8Response(String body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(body), status,
        headers: {'content-type': 'text/html; charset=utf-8'});

/// Runs [body] with every top-level `http.get` (as used throughout lib/)
/// served by [client].
Future<T> withHttp<T>(http.Client client, Future<T> Function() body) =>
    http.runWithClient(body, () => client);

Widget wrapInApp(Widget child) => MaterialApp(home: child);

/// Lets both fake-clock work (timers, HTTP mock delays, frames) and real I/O
/// (sqflite file access, which never completes under fake async) make
/// progress. Use instead of pumpAndSettle, which never settles while a
/// progress indicator is spinning.
Future<void> settle(WidgetTester tester, {int rounds = 15}) async {
  for (var i = 0; i < rounds; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// --------------------------------------------------------------------------
// Fixtures
// --------------------------------------------------------------------------

/// Mirrors the markup the scraper in lib/race_info_scraper.dart expects from
/// http://elitefeats.com/upcoming.
String upcomingSection({
  required String id,
  required String name,
  required String location,
  required String date,
  bool red = false,
  String? registrationHref,
}) =>
    '''
<section class="post">
  ${registrationHref != null ? '<a href="$registrationHref">Register</a>' : ''}
  <div class="${red ? 'RedDateDiv' : 'BlueDateDiv'}">$date</div>
  <div style="text-align:center"><h3> $location </h3></div>
  <h3 style="text-align:center;font-size: 1.2em"> $name </h3>
  <a href="../race-results/?ID=$id">Results</a>
</section>''';

String upcomingPage(List<String> sections) =>
    '<html><body>${sections.join('\n')}</body></html>';

const csvHeader = 'Bib,First,Last,Gender,Age,Team,Division,Shirt,City,State';

String csvRow(int bib, String first, String last,
        {String gender = 'M',
        int age = 30,
        String team = '',
        String division = 'M30-39',
        String shirt = 'Medium',
        String city = 'Bangor',
        String state = 'ME'}) =>
    '$bib,$first,$last,$gender,$age,$team,$division,$shirt,$city,$state';

String bibCsv(List<String> rows) => [csvHeader, ...rows].join('\n');
