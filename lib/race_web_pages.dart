import 'package:ef_race_pages/pages/bib_reserve_page.dart';
import 'package:ef_race_pages/pages/registration_page.dart';
import 'package:ef_race_pages/pages/bib_lookup_page.dart';
import 'package:ef_race_pages/pages/results_page.dart';
import 'package:ef_race_pages/pages/search_page.dart';
import 'package:ef_race_pages/pages/settings_page.dart';
import 'package:ef_race_pages/race_id_setting_page.dart';
import 'package:ef_race_pages/services/race_service.dart';
import 'package:ef_race_pages/services/recent_event_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/race.dart';

class RaceWebPages extends StatefulWidget {
  final String raceId;

  const RaceWebPages({super.key, required this.raceId});

  @override
  _RaceWebPagesState createState() => _RaceWebPagesState();
}

class _RaceWebPagesState extends State<RaceWebPages> {
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);
  final PageController _pageController = PageController();

  Race? _race;
  String _registrationUrl = 'about:blank'; //placeholder
  bool _isLoading = true;  // Add loading state

  @override
  void initState() {
    super.initState();
    _fetchRaceData();
  }

  @override
  void dispose() {
    _currentIndexNotifier.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchRaceData() async {
    Race? fetchedRace = await RaceService.getRace(widget.raceId);
    String? registrationUrl = fetchedRace?.registrationUrl ??
        await RaceService.getRegistrationUrl(widget.raceId);

    if (mounted) {
      setState(() {
        _race = fetchedRace;
        _registrationUrl = registrationUrl ??
            "about:blank";
        _isLoading = false;
      });
    }
  }

  Widget _buildDrawer() {
    return FutureBuilder<List<String>>(
      future: getRecentRaces(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Drawer(child: Center(child: CircularProgressIndicator()));
        }

        List<String> recentRaceIds = snapshot.data!;
        return FutureBuilder<List<Race?>>(
          future: Future.wait(recentRaceIds.map((id) => RaceService.getRace(id)).toList()),
          builder: (context, raceSnapshot) {
            if (!raceSnapshot.hasData) {
              return const Drawer(child: Center(child: CircularProgressIndicator()));
            }

            List<Race> recentRaces = raceSnapshot.data!.whereType<Race>().toList();
            return Drawer(
              child: ListView(
                children: [
                  ...recentRaces.map((race) => ListTile(
                    tileColor: race.id == widget.raceId
                        ? Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[200]
                        : null, // Highlight current race based on theme // Highlight current race
                    title: Text("${race.name} (${race.id})"),
                    trailing: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () async {
                        await removeRaceFromRecentList(race.id);

                        if (race.id == widget.raceId) {
                          // Remove current race and check for other available races
                          List<String> updatedRecentRaces = await getRecentRaces(); // Assuming this method updates itself after removeRaceFromRecentList is called

                          if (updatedRecentRaces.isNotEmpty) {
                            // If there are other races, switch to the first one in the updated list
                            String newRaceId = updatedRecentRaces.first;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RaceWebPages(raceId: newRaceId),
                              ),
                            );
                          } else {
                            // If no other races, navigate to race selection page
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RaceIDSettingPage(),
                              ),
                            );
                          }
                        } else {
                          setState(() {});
                        }// Refresh UI
                      },
                    ),
                    onTap: () {
                      saveCurrentRace(race.id);
                      Navigator.pop(context);  // Close the drawer
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RaceWebPages(raceId: race.id),
                        ),
                      );
                    },
                  )),
                  ListTile(
                    title: const Text("Add New Race"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RaceIDSettingPage()),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text("Clear All"),
                    onTap: () {
                      clearAllRecentRaces();
                      clearCurrentRace();
                      Navigator.pop(context);  // Close the drawer
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RaceIDSettingPage(),
                        ),
                      );
                      setState(() {});  // Refresh UI
                    },
                  ),
                ],
              ),
            );
          },
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
        title: Text(_race != null ? _race!.name : "Loading..."),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
          ),
        ],

      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : PageView.builder(
          controller: _pageController,
          onPageChanged: (index) => _currentIndexNotifier.value = index,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            if (index == 0) return RegistrationPage(raceId: widget.raceId, initialUrl: _registrationUrl);
            if (index == 1) return BibLookupPage(raceId: widget.raceId);
            if (index == 2) return BibReservePage(raceId: widget.raceId);
            if (index == 3) return ResultsPage(raceId: widget.raceId);
            if (index == 4) return SearchPage(raceId: widget.raceId);
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
                label: 'Lookup',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event_note),
                label: 'Reserve',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard),
                label: 'Results',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Search',
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
