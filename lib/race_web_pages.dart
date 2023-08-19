import 'package:ef_race_pages/bib_reserve_page.dart';
import 'package:ef_race_pages/registration_page.dart';
import 'package:ef_race_pages/bib_lookup_page.dart';
import 'package:ef_race_pages/results_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RaceWebPages extends StatefulWidget {
  final String raceId;

  const RaceWebPages({super.key, required this.raceId});

  @override
  _RaceWebPagesState createState() => _RaceWebPagesState();
}

class _RaceWebPagesState extends State<RaceWebPages> {
  ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);
  PageController _pageController = PageController();

  @override
  void dispose() {
    _currentIndexNotifier.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    ));

    return Scaffold(
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) => _currentIndexNotifier.value = index,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            if (index == 0) return RegistrationPage(raceId: widget.raceId);
            if (index == 1) return BibLookupPage(raceId: widget.raceId);
            if (index == 2) return BibReservePage(raceId: widget.raceId);
            if (index == 3) return ResultsPage(raceId: widget.raceId);
            //... add more cases as required
            return Container();
          },
        ),
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _currentIndexNotifier,
        builder: (context, currentIndex, child) {
          return BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: currentIndex,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.app_registration),
                label: 'Registration',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.directions_run),
                label: 'Bib Lookup',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event_note),
                label: 'Bib Reserve',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard),
                label: 'Results',
              ),
            ],
            onTap: (index) {
              _pageController.jumpToPage(index);
            },
          );
        },
      ),
    );
  }
}
