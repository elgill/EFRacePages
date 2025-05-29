import 'package:ef_race_pages/race_id_setting_page.dart';
import 'package:ef_race_pages/race_web_pages.dart';
import 'package:ef_race_pages/services/recent_event_manager.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        // Add other theme properties if required
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: false
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        // Add other theme properties if required
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: false
      ),
      home: FutureBuilder<String?>(
        future: getCurrentRace(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.data != null) {
              return RaceWebPages(raceId: snapshot.data!);
            } else {
              return RaceIDSettingPage();
            }
          } else {
            return CircularProgressIndicator();  // Show a loading spinner while checking
          }
        },
      ),
    );
  }
}
