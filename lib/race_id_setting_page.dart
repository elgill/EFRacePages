import 'package:ef_race_pages/models/race.dart';
import 'package:ef_race_pages/race_info_scraper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:ef_race_pages/race_web_pages.dart';

class RaceIDSettingPage extends StatefulWidget {
  const RaceIDSettingPage({super.key});

  @override
  _RaceIDSettingPageState createState() => _RaceIDSettingPageState();
}

class _RaceIDSettingPageState extends State<RaceIDSettingPage> {
  final TextEditingController _controller = TextEditingController();

  List<Race> races = [];
  bool isLoading = true;
  String? errorMessage;  // To store an error message, if any

  void fetchData() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    fetchRaces().then((fetchedRaces) {
      setState(() {
        races = fetchedRaces;
        isLoading = false;
      });
    }).catchError((error) {
      setState(() {
        isLoading = false;
        errorMessage = "Failed to fetch races. Please try again later.";
      });
    });
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }


  _saveRaceID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('raceid', _controller.text);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RaceWebPages(raceId: _controller.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())  // Show loading indicator while fetching
            : errorMessage != null
            ? buildErrorWidget()  // Show the error message if there's any
            : buildSelectorPage(),
      ),
    );
  }

  Widget buildSelectorPage() {
    return Center(
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: "Enter RaceID"),
            ),
            ElevatedButton(
              onPressed: _saveRaceID,
              child: const Text("Save and View Race Pages"),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: races.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(races[index].name),
                    subtitle: Text('${races[index].location} on ${races[index].date}'),
                    trailing: Text(races[index].id),
                    onTap: () {
                      _controller.text = races[index].id;
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
  }

  Widget buildErrorWidget() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(errorMessage!),
        const SizedBox(height: 20), // spacing between the error message and the button
        ElevatedButton(
          onPressed: fetchData,
          child: const Text("Retry"),
        )
      ],
    ),
  );

}

