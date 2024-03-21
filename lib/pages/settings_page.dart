import 'package:flutter/material.dart';

import '../models/user_settings.dart';
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  UserSettings _settings = UserSettings.getDefault();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  _loadSettings() async {
    UserSettings settings = await SettingsService.loadUserSettings();
    setState(() {
      _settings = settings;
    });
  }

  _saveSettings() async {
    await SettingsService.saveUserSettings(_settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: <Widget>[
          const ListTile(
            title: Text('General Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
/*          SwitchListTile(
            title: const Text('Normalize T-Shirt Sizes'),
            value: _settings.normalizeTShirtSizes,
            onChanged: (bool value) {
              setState(() {
                _settings.normalizeTShirtSizes = value;
              });
              _saveSettings();
            },
          ),*/
          const ListTile(
            title: Text('Display Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            subtitle: Text('Customize which fields are visible in the search results.'),
          ),
          ..._settings.fieldVisibility.keys.map((String key) {
            return CheckboxListTile(
              title: Text(_capitalize(key)),
              value: _settings.fieldVisibility[key],
              onChanged: (bool? value) {
                setState(() {
                  _settings.fieldVisibility[key] = value!;
                });
                _saveSettings();
              },
            );
          }).toList(),
          // Placeholder for future settings categories
        ],
      ),
    );
  }

  String _capitalize(String s) {
    return s[0].toUpperCase() + s.substring(1);
  }
}
