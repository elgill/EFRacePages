import 'package:ef_race_pages/base_web_view_page.dart';
import 'package:ef_race_pages/models/race.dart';
import 'package:ef_race_pages/pages/bib_lookup_page.dart';
import 'package:ef_race_pages/pages/bib_reserve_page.dart';
import 'package:ef_race_pages/pages/reader_status_page.dart';
import 'package:ef_race_pages/pages/recap_page.dart';
import 'package:ef_race_pages/pages/registration_page.dart';
import 'package:ef_race_pages/pages/results_page.dart';
import 'package:ef_race_pages/services/race_service.dart';
import 'package:ef_race_pages/services/recent_event_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../helpers/fake_webview_platform.dart';
import '../helpers/test_env.dart';

const home = 'https://example.com/home';
const other = 'https://example.com/other';

void main() {
  late FakeInAppWebViewPlatform platform;

  setUp(() {
    usePrefs();
    platform = FakeInAppWebViewPlatform.install();
  });

  Future<FakeWebView> pumpPage(WidgetTester tester, Widget page,
      {bool created = true}) async {
    await tester.pumpWidget(wrapInApp(Scaffold(body: page)));
    final wv = platform.webViews.last;
    if (created) wv.fireCreated();
    return wv;
  }

  group('page URLs', () {
    final cases = <String, (Widget, String)>{
      'Registration': (
        const RegistrationPage(raceId: '9', initialUrl: 'https://reg/9'),
        'https://reg/9'
      ),
      'Bib lookup': (
        const BibLookupPage(raceId: '9'),
        'https://www.elitefeats.com/Bibs/?ID=9'
      ),
      'Results': (
        const ResultsPage(raceId: '9'),
        'https://www.elitefeats.com/race-results?ID=9'
      ),
      'Bib reserve': (
        const BibReservePage(raceId: '9'),
        'https://www.elitefeats.com/bibreserve'
      ),
      'Reader status': (
        const ReaderStatusPage(),
        'https://elitefeats.com/ReaderStatus/'
      ),
      'Recap': (const RecapPage(), 'https://events.elitefeats.com/recap'),
    };
    for (final c in cases.entries) {
      testWidgets('${c.key} loads ${c.value.$2}', (tester) async {
        final wv = await pumpPage(tester, c.value.$1);
        expect(wv.initialUrl, c.value.$2);
      });
    }
  });

  group('BaseWebViewPage', () {
    testWidgets('spinner shows while loading and hides on load stop',
        (tester) async {
      final wv =
          await pumpPage(tester, const BaseWebViewPage(initialUrl: home));
      wv.fireLoadStart(home);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      wv.fireLoadStop(home);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('home button navigates back to the initial URL',
        (tester) async {
      final wv =
          await pumpPage(tester, const BaseWebViewPage(initialUrl: home));
      wv.fireLoadStart(other);
      await tester.tap(find.byIcon(Icons.home));
      await tester.pump();
      expect(wv.controller.loadedUrls, [home]);
    });

    testWidgets('pull to refresh reloads; load stop and errors end refreshing',
        (tester) async {
      final wv =
          await pumpPage(tester, const BaseWebViewPage(initialUrl: home));
      final ptr = platform.pullToRefreshControllers.last;
      ptr.pull();
      await tester.pump();
      expect(wv.controller.reloadCalls, 1);
      wv.fireLoadStop(home);
      wv.fireError(home);
      await tester.pump();
      expect(ptr.endRefreshingCalls, 2);
    });

    group('app resume', () {
      Future<void> resume(WidgetTester tester) async {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
      }

      testWidgets('reloads when the OS blanked the page', (tester) async {
        final wv =
            await pumpPage(tester, const BaseWebViewPage(initialUrl: home));
        wv.controller.currentUrl = null;
        await resume(tester);
        expect(wv.controller.loadedUrls, [home]);
      });

      testWidgets('leaves a live page alone', (tester) async {
        final wv =
            await pumpPage(tester, const BaseWebViewPage(initialUrl: home));
        wv.fireLoadStart(other);
        await resume(tester);
        expect(wv.controller.loadedUrls, isEmpty);
      });

      testWidgets('reloads if querying the controller fails', (tester) async {
        final wv =
            await pumpPage(tester, const BaseWebViewPage(initialUrl: home));
        wv.controller.getUrlError = Exception('webview gone');
        await resume(tester);
        expect(wv.controller.loadedUrls, [home]);
      });

      testWidgets('does nothing before the webview exists', (tester) async {
        await pumpPage(tester, const BaseWebViewPage(initialUrl: home),
            created: false);
        await resume(tester);
        expect(tester.takeException(), isNull);
      });
    });

    group('share dialog', () {
      setUp(() {
        // Phone portrait.
        final view =
            TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
        view.physicalSize = const Size(1170, 2532);
        view.devicePixelRatio = 3;
        addTearDown(view.reset);
      });

      testWidgets('does nothing until a page has started loading',
          (tester) async {
        final wv =
            await pumpPage(tester, const BaseWebViewPage(initialUrl: home));
        wv.fireLoadStop(home); // stop the spinner so pumpAndSettle can settle
        await tester.tap(find.byIcon(Icons.qr_code));
        await tester.pumpAndSettle();
        expect(find.text('Share Page'), findsNothing);
      });

      testWidgets('shows a QR code for the current URL and copies it',
          (tester) async {
        String? copied;
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
        final wv =
            await pumpPage(tester, const BaseWebViewPage(initialUrl: home));
        wv.fireLoadStart(other);
        wv.fireLoadStop(other);
        await tester.pump();

        await tester.tap(find.byIcon(Icons.qr_code));
        await tester.pumpAndSettle();
        expect(find.text('Share Page'), findsOneWidget);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text(other), findsOneWidget);

        await tester.tap(find.text('Copy URL'));
        await tester.pumpAndSettle();
        expect(copied, other);
        expect(find.text('Share Page'), findsNothing);
        expect(find.text('URL copied to clipboard'), findsOneWidget);
      });

      testWidgets('fits a landscape phone by scrolling (no overflow)',
          (tester) async {
        // 844x390 logical: an iPhone 14 on its side. The dialog is capped
        // at 80% of screen height, which used to overflow by ~19px+.
        tester.view.physicalSize = const Size(2532, 1170);
        tester.view.devicePixelRatio = 3;
        final wv =
            await pumpPage(tester, const BaseWebViewPage(initialUrl: home));
        wv.fireLoadStart(other);
        wv.fireLoadStop(other);
        await tester.tap(find.byIcon(Icons.qr_code));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // The action buttons are reachable by scrolling.
        await tester.scrollUntilVisible(find.text('Share'), 50,
            // .first: the dialog's scroll view (the URL's SelectableText
            // has its own Scrollable further down the tree).
            scrollable: find
                .descendant(
                    of: find.byType(Dialog), matching: find.byType(Scrollable))
                .first);
        expect(find.text('Share'), findsOneWidget);
      });

      testWidgets('close button dismisses', (tester) async {
        final wv =
            await pumpPage(tester, const BaseWebViewPage(initialUrl: home));
        wv.fireLoadStart(other);
        wv.fireLoadStop(other);
        await tester.tap(find.byIcon(Icons.qr_code));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.text('Share Page'), findsNothing);
      });
    });
  });

  group('BibReservePage', () {
    testWidgets('fills the race id into the form after load', (tester) async {
      final wv = await pumpPage(tester, const BibReservePage(raceId: '321'));
      wv.fireLoadStop('https://www.elitefeats.com/bibreserve');
      await tester.pump();
      expect(wv.controller.evaluatedScripts.single,
          "document.getElementById('txtUserId').value = '321';");
    });
  });

  group('RecapPage', () {
    Future<FakeWebView> loadRecap(WidgetTester tester) async {
      final wv = await pumpPage(tester, const RecapPage());
      wv.fireLoadStop('https://events.elitefeats.com/recap');
      // prefs reads, then a deliberate 500ms wait for the form.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      return wv;
    }

    testWidgets('autofills the current race name and short date',
        (tester) async {
      await RaceService.saveRace(Race(
          id: '77', date: 'Sat 6/13/2026', location: 'L', name: 'Trail Race'));
      await saveCurrentRace('77');
      final wv = await loadRecap(tester);
      final js = wv.controller.evaluatedScripts.single;
      expect(js, contains('const raceName = "Trail Race";'));
      expect(js, contains('const raceDate = "6/13/26";'));
    });

    testWidgets('escapes quotes and backslashes in the race name',
        (tester) async {
      await RaceService.saveRace(Race(
          id: '78', date: '6/1/2026', location: 'L', name: r'Bob\s "Big" Run'));
      await saveCurrentRace('78');
      final wv = await loadRecap(tester);
      expect(wv.controller.evaluatedScripts.single,
          contains(r'const raceName = "Bob\\s \"Big\" Run";'));
    });

    testWidgets('does nothing without a current race', (tester) async {
      final wv = await loadRecap(tester);
      expect(wv.controller.evaluatedScripts, isEmpty);
    });
  });

  // ------------------------------------------------------------------------
  // Regression tests for crashes found while adding this suite. Comments
  // describe the original failure mode; each test failed before the fix.
  // ------------------------------------------------------------------------
  group('regression', () {
    testWidgets(
        'tapping Home before the native webview finishes creating is a no-op',
        (tester) async {
      // _controller is `late` and only assigned in onWebViewCreated, but the
      // Home FAB is live from the first frame. On a cold start or slow device
      // creation can take hundreds of ms.
      await pumpPage(tester, const BaseWebViewPage(initialUrl: home),
          created: false);
      await tester.tap(find.byIcon(Icons.home));
      await tester.pump();
    });

    testWidgets('load callback arriving after the page is disposed is ignored',
        (tester) async {
      // onLoadStart/onLoadStop call setState without a mounted check. Pages
      // are disposed when the user switches race from the drawer while a
      // page is still loading; a late native callback then lands here.
      final wv =
          await pumpPage(tester, const BaseWebViewPage(initialUrl: home));
      wv.fireLoadStart(home);
      await tester.pumpWidget(wrapInApp(const Text('switched race')));
      wv.fireLoadStop(home);
      await tester.pump();
    });
  });
}
