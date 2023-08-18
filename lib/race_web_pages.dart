import 'package:ef_race_pages/registration_page.dart';
import 'package:ef_race_pages/bib_lookup_page.dart';
import 'package:ef_race_pages/results_page.dart';
import 'package:flutter/material.dart';

class RaceWebPages extends StatefulWidget {
  final String raceId;

  const RaceWebPages({super.key, required this.raceId});

  @override
  _RaceWebPagesState createState() => _RaceWebPagesState();
}

class _RaceWebPagesState extends State<RaceWebPages> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            RegistrationPage(raceId: widget.raceId),
            BibLookupPage(raceId: widget.raceId),
            ResultsPage(raceId: widget.raceId),
            // ... other pages
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
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
            icon: Icon(Icons.leaderboard),
            label: 'Results',
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
