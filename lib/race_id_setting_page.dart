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

  _saveRaceID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //await prefs.setString('raceid', _controller.text);
    await prefs.setString('raceid', "23325");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RaceWebPages(raceId: _controller.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
          child: Center(
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
              ],
            ),
          ),
        )

    );
  }
}