import 'package:ef_race_pages/pages/bib_reserve_page.dart';
import 'package:ef_race_pages/pages/registration_page.dart';
import 'package:ef_race_pages/pages/bib_lookup_page.dart';
import 'package:ef_race_pages/pages/results_page.dart';
import 'package:ef_race_pages/race_id_setting_page.dart';
import 'package:ef_race_pages/services/recent_event_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RaceWebPages extends StatefulWidget {
  final String raceId;

  const RaceWebPages({super.key, required this.raceId});

  @override
  _RaceWebPagesState createState() => _RaceWebPagesState();
}

class _RaceWebPagesState extends State<RaceWebPages> {
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _currentIndexNotifier.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildDrawer() {
    return FutureBuilder<List<String>>(
      future: getRecentRaces(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Drawer(child: const Center(child: CircularProgressIndicator()));
        }

        List<String> recentRaces = snapshot.data!;
        return Drawer(
          child: ListView(
            children: [
              ...recentRaces.map((raceId) => ListTile(
                title: Text("Race: $raceId"),
                trailing: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    removeRaceFromRecentList(raceId);
                    setState(() {});  // Refresh UI
                  },
                ),
                onTap: () {
                  Navigator.pop(context);  // Close the drawer
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RaceWebPages(raceId: raceId),
                    ),
                  );
                },
              )),
              ListTile(
                title: Text("Add New Race"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RaceIDSettingPage()),
                  );
                },
              ),
              ListTile(
                title: Text("Clear All"),
                onTap: () {
                  clearAllRecentRaces();
                  setState(() {});  // Refresh UI
                },
              ),
            ],
          ),
        );
      },
    );
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
      appBar: AppBar(
        title: Text("Race Web Pages"),
      ),
      drawer: _buildDrawer(),
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
