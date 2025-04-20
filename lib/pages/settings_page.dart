import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  // Add this method to clear cookies
  _clearCookies() async {
    try {
      await WebViewCookieManager().clearCookies();
      if (mounted) {
        // TODO: fix error here
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cookies cleared successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear cookies: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
          // Add the cookie clearing button here
          ListTile(
            title: const Text('Clear Browser Cookies'),
            subtitle: const Text('Clear stored website data and cookies'),
            trailing: const Icon(Icons.delete),
            onTap: _clearCookies,
          ),
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
        ],
      ),
    );
  }

  String _capitalize(String s) {
    return s[0].toUpperCase() + s.substring(1);
  }
}