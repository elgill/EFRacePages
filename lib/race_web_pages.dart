import 'package:ef_race_pages/pages/bib_reserve_page.dart';
import 'package:ef_race_pages/pages/recap_page.dart';
import 'package:ef_race_pages/pages/registration_page.dart';
import 'package:ef_race_pages/pages/bib_lookup_page.dart';
import 'package:ef_race_pages/pages/results_page.dart';
import 'package:ef_race_pages/pages/search_page.dart';
import 'package:ef_race_pages/pages/settings_page.dart';
import 'package:ef_race_pages/pages/more_page.dart';
import 'package:ef_race_pages/pages/reader_status_page.dart';
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

  // Store pages to maintain state
  final Map<int, Widget> _cachedPages = {};

  // Track which pages have been created for proper disposal
  final Set<int> _createdPageIndices = <int>{};

  Race? _race;
  String _registrationUrl = 'about:blank';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRaceData();
  }

  @override
  void dispose() {
    _currentIndexNotifier.dispose();
    _pageController.dispose();
    _cachedPages.clear();
    _createdPageIndices.clear();
    super.dispose();
  }

  Future<void> _fetchRaceData() async {
    Race? fetchedRace = await RaceService.getRace(widget.raceId);
    String? registrationUrl = fetchedRace?.registrationUrl ??
        await RaceService.getRegistrationUrl(widget.raceId);

    if (mounted) {
      setState(() {
        _race = fetchedRace;
        _registrationUrl = registrationUrl ?? "about:blank";
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
                        : null,
                    title: Text("${race.name} (${race.id})"),
                    trailing: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () async {
                        await removeRaceFromRecentList(race.id);

                        if (race.id == widget.raceId) {
                          List<String> updatedRecentRaces = await getRecentRaces();

                          if (updatedRecentRaces.isNotEmpty) {
                            String newRaceId = updatedRecentRaces.first;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RaceWebPages(raceId: newRaceId),
                              ),
                            );
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RaceIDSettingPage(),
                              ),
                            );
                          }
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                    onTap: () {
                      saveCurrentRace(race.id);
                      Navigator.pop(context);
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
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RaceIDSettingPage(),
                        ),
                      );
                      setState(() {});
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

  Widget _getPage(int index) {
    // Return cached page if it exists
    if (_cachedPages.containsKey(index)) {
      return _cachedPages[index]!;
    }

    Widget page;
    switch (index) {
      case 0:
        page = RegistrationPage(raceId: widget.raceId, initialUrl: _registrationUrl);
        break;
      case 1:
        page = BibLookupPage(raceId: widget.raceId);
        break;
      case 2:
        page = ResultsPage(raceId: widget.raceId);
        break;
      case 3:
        page = SearchPage(raceId: widget.raceId);
        break;
      case 4:
      // More page is always fresh to ensure callback works properly
        return MorePage(
          raceId: widget.raceId,
          onNavigateToPage: _navigateToPage,
        );
      case 5:
        page = BibReservePage(raceId: widget.raceId);
        break;
      case 6:
        page = const ReaderStatusPage();
        break;
      case 7:
        page = const RecapPage();
        break;
      default:
        page = Container();
    }

    // Cache the page and track its creation
    _cachedPages[index] = page;
    _createdPageIndices.add(index);
    return page;
  }

  void _navigateToPage(int pageIndex) {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(pageIndex);
    }
  }

  // Get the bottom navigation index (0-4) from the current page index
  int _getBottomNavIndex(int pageIndex) {
    if (pageIndex >= 5) {
      return 4; // Always show "More" as selected for additional pages
    }
    return pageIndex;
  }

  // Get the app bar title based on current page
  String _getAppBarTitle(int currentIndex) {
    if (_race == null) return "Loading...";

    switch (currentIndex) {
      case 5:
        return "${_race!.name} - Bib Reserve";
      case 6:
        return "${_race!.name} - Reader Status";
      case 7:
        return "${_race!.name} - Event Recap";
      default:
        return _race!.name;
    }
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
        title: ValueListenableBuilder<int>(
          valueListenable: _currentIndexNotifier,
          builder: (context, currentIndex, child) {
            return Text(_getAppBarTitle(currentIndex));
          },
        ),
        actions: [
          // Add back button for additional pages
          ValueListenableBuilder<int>(
            valueListenable: _currentIndexNotifier,
            builder: (context, currentIndex, child) {
              if (currentIndex >= 5) {
                return IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _pageController.jumpToPage(4), // Go back to More page
                );
              }
              return const SizedBox.shrink();
            },
          ),
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
          itemCount: 8, // Total pages: 5 main + 3 additional
          itemBuilder: (context, index) => _getPage(index),
        ),
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _currentIndexNotifier,
        builder: (context, currentIndex, child) {
          return BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _getBottomNavIndex(currentIndex),
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
                icon: Icon(Icons.leaderboard),
                label: 'Results',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz),
                label: 'More',
              ),
            ],
            onTap: (index) {
              // Only navigate to main pages (0-4) from bottom navigation
              if (index <= 4) {
                _pageController.jumpToPage(index);
              }
            },
          );
        },
      ),
    );
  }
}