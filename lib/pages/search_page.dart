import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:http/http.dart' as http;

import '../models/user_settings.dart';
import '../services/settings_service.dart';

class SearchPage extends StatefulWidget {
  final String raceId;

  const SearchPage({Key? key, required this.raceId}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;
  bool _isAscending = true;

  late UserSettings _userSettings;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    SettingsService.removeListener(_settingsChanged);
    super.dispose();
  }

  void _settingsChanged() {
    if (mounted) {
      _loadUserSettings();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _checkAndClearDbIfNeeded();
    _loadData();

    SettingsService.addListener(_settingsChanged);
  }

  Future<void> _loadUserSettings() async {
    UserSettings settings = await SettingsService.loadUserSettings();
    setState(() {
      _userSettings = settings;
    });
  }


  Future<Database> _openDatabase() async {
    return await openDatabase(
      'race_data.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE bib_data (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bib INTEGER,
          name TEXT,
          age INTEGER,
          gender TEXT,
          city TEXT,
          state TEXT,
          division TEXT,
          team TEXT,
          t_shirt TEXT,
          extra TEXT,
          status TEXT
        );
      ''');
      },
    );
  }


  Future<List<Map<String, dynamic>>> scrapeDataFromWebPage(String raceId) async {
    final String url = 'https://www.elitefeats.com/Bibs/?ID=$raceId&csv=yesplease';

    final response = await http.get(Uri.parse(url));

    // Check for response status
    if (response.statusCode == 200) {
      final csvData = utf8.decode(response.bodyBytes);

      final lines = LineSplitter.split(csvData).toList();

      //Lets ignore these for now
      final headers = lines.first.split(',');
      lines.removeAt(0);

      List<Map<String, dynamic>> runners = [];

      for (var line in lines) {
        final fields = line.split(',');

        if (fields.length != headers.length) {
          // Skip this line as it's malformed
          log('Skipping malformed line: $line');
          continue;
        }

        final runnerData = {
          'bib': int.tryParse(fields[0]) ?? 0,
          'name': '${fields[2]}, ${fields[1]}', // Last, First
          'gender': fields[3],
          'age': int.tryParse(fields[4]) ?? 0,
          'team': fields[5],
          'division': fields[6],
          't_shirt': fields[7],
          'city': fields[8],
          'state': fields[9],
          // Adding empty or default values for fields not present in CSV
          'status': '',
          'extra': '',
        };

        // Add the runner data to the list
        runners.add(runnerData);
      }

      return runners;
    } else {
      throw Exception('Failed to load webpage = ${response.statusCode}');
    }
  }


  Future<void> _loadData() async {
    try {
      var scrapedData = await scrapeDataFromWebPage(widget.raceId);

      if (scrapedData.isNotEmpty) {
        await storeDataLocally(scrapedData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Updated ${scrapedData.length} participants'),
                backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            )
        );
        _searchDatabase(_searchController.text);
      } else {
        if (!mounted) return;

        _showSnackBarWithMessage('No data available to update. Please try again later.', Colors.orange);
      }
    } on SocketException {
      _showSnackBarWithMessage('No Internet connection. Please check your connection and try again.', Colors.red);
    } catch (e) {
      // The catch block now handles both failed HTTP requests and parsing errors
      log('Exception $e');
      if (e is HttpException) {
        // Handle HTTP errors specifically
        _showSnackBarWithMessage('Failed to load data. Please check your internet connection.', Colors.red);
      } else {
        // Handle parsing and other types of errors
        _showSnackBarWithMessage('Failed to parse data. Are bibs posted to bib lookup?', Colors.red);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _searchDatabase(String query) async {
    final db = await _openDatabase();
    List<Map<String, dynamic>> results = [];

    // Define the sort order based on the _isAscending flag
    String sortOrder = _isAscending ? 'ASC' : 'DESC';

    // Split the query into AND parts
    var andParts = query.split('&').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    // Initialize a list to hold parts of the WHERE clause and the corresponding arguments
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    // Process each AND part
    for (var andPart in andParts) {
      List<String> orClauses = [];

      // Further split each AND part into OR parts
      var orParts = andPart.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (var term in orParts) {
        bool isNot = term.startsWith('!');
        if (isNot) {
          term = term.substring(1); // Remove the '!' prefix
        }
        var questionMarks = term.split('?');
        if (questionMarks.length > 1 && RegExp(r'^\d+$').hasMatch(questionMarks[0])) {
          int baseNumber = int.parse(questionMarks[0]);
          int range = questionMarks.length - 1;
          String clause = '(bib BETWEEN ? AND ?)';
          orClauses.add(isNot ? '(NOT $clause)' : clause);
          whereArgs.add(baseNumber - range);
          whereArgs.add(baseNumber + range);
        } else if (term.contains('-')) {
          var parts = term.split('-');
          if (parts.length == 2) {
            String clause = '(bib BETWEEN ? AND ?)';
            orClauses.add(isNot ? '(NOT $clause)' : clause);
            whereArgs.addAll([int.tryParse(parts[0].trim()) ?? 0, int.tryParse(parts[1].trim()) ?? 9999999]);
          }
        } else if (term.contains(':')) {
          var parts = term.split(':');
          if (parts.length == 2) {
            String field = parts[0].trim().toLowerCase();
            String searchterm = parts[1].trim();
            if (_userSettings.fieldVisibility.containsKey(field)) {
              String clause = '($field LIKE ?)';
              orClauses.add(isNot ? '(NOT $clause)' : clause);
              whereArgs.add('%$searchterm%');
            }
          }
        } else {
          String clause = '(bib LIKE ? OR name LIKE ?)';
          orClauses.add(isNot ? '(NOT $clause)' : clause);
          whereArgs.addAll([term, '%$term%']);
        }
      }

      // Combine the OR clauses using OR logic
      if (orClauses.isNotEmpty) {
        whereClauses.add('(${orClauses.join(' OR ')})');
      }
    }

    // Combine the AND parts using AND logic
    String combinedQuery = whereClauses.join(' AND ');

    // Uncomment for debugging
    log('CombinedQuery: $combinedQuery\n$whereArgs');

    if (combinedQuery.isNotEmpty) {
      results = await db.query(
        'bib_data',
        where: combinedQuery,
        whereArgs: whereArgs,
        orderBy: 'bib $sortOrder',
      );
    } else {
      results = await db.query('bib_data', orderBy: 'bib $sortOrder');
    }

    setState(() {
      _searchResults = results;
    });
    await db.close();
  }




// Function to store data in SQLite database
  Future<void> storeDataLocally(List<Map<String, dynamic>> data) async {
    final db = await _openDatabase();
    await db.transaction((txn) async {
      await txn.delete('bib_data'); // Clear the table

      for (var row in data) {
        await txn.insert('bib_data', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    await db.close();
  }

  Future<void> _checkAndClearDbIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final previousRaceId = prefs.getString('previous_race_id') ?? '';

    log('Previous Race ID: $previousRaceId');
    log('Current Race ID: ${widget.raceId}');

    if (previousRaceId != widget.raceId) {
      log('Race ID has changed. Clearing database...');
      await clearDbData();
      await prefs.setString('previous_race_id', widget.raceId);
      log('Database cleared and new Race ID stored.');
    } else {
      log('Race ID is the same. No need to clear database.');
      _searchDatabase(_searchController.text);
    }
  }


  // Function to store data in SQLite database
  Future<void> clearDbData() async {
    final db = await _openDatabase();
    await db.transaction((txn) async {
      await txn.delete('bib_data'); // Clear the table
    });
    await db.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showStats,
        tooltip: 'Show Stats',
        child: const Icon(Icons.analytics),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus(); // Unfocus text field when tapping outside
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchDatabase,
                      decoration: InputDecoration(
                        labelText: 'Search (e.g. "123", "Doe", "102-105", "101/150")',
                        border: const OutlineInputBorder(),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchDatabase(''); // Clear search results
                          },
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward),
                    onPressed: () {
                      setState(() {
                        _isAscending = !_isAscending; // Toggle sorting order
                        _searchDatabase(_searchController.text); // Perform search again with new order
                      });
                    },
                    tooltip: 'Toggle Sort Order',
                  ),
                ],
              ),
            ),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Results: ${_searchResults.length}'),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadData();
                },
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    var result = _searchResults[index];
                    return ListTile(
                      title: Text(result['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _userSettings.fieldVisibility.entries
                            .where((entry) => entry.value == true && result.containsKey(entry.key)) // Ensure the field is marked true and exists in result
                            .map((entry) {
                          String displayValue = '${entry.key[0].toUpperCase()}${entry.key.substring(1)}: ${result[entry.key]}';
                          return Text(displayValue);
                        }).toList(),
                      ),

                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStats() async {
    final db = await _openDatabase();
    // Example query to calculate total number of people for each t-shirt size
    List<Map> tShirtSizes = await db.rawQuery('SELECT t_shirt, COUNT(*) as total FROM bib_data GROUP BY t_shirt ORDER BY COUNT(*) DESC');

    // Similar queries for division and gender
    List<Map> divisions = await db.rawQuery('SELECT division, COUNT(*) as total FROM bib_data GROUP BY division ORDER BY COUNT(*) DESC');
    List<Map> genders = await db.rawQuery('SELECT gender, COUNT(*) as total FROM bib_data GROUP BY gender ORDER BY COUNT(*) DESC');
    List<Map> teams = await db.rawQuery('SELECT team, COUNT(*) as total FROM bib_data GROUP BY team ORDER BY COUNT(*) DESC');

    await db.close();

    // Show the results
    _showStatsDialog(tShirtSizes, divisions, genders, teams);
  }

  void _showStatsDialog(List<Map> tShirtSizes, List<Map> divisions, List<Map> genders, List<Map> teams) {
    teams = teams.where((e) => e['team']?.isNotEmpty ?? false).toList();
    var filteredTshirts = _normalizeAndAggregateSizes(tShirtSizes);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Statistics'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                const Text('Divisions:'),
                ...divisions.map((e) => Text('${e['division']}: ${e['total']}')).toList(),
                const SizedBox(height: 16),
                const Text('T-Shirt Sizes:'),
                ...filteredTshirts.entries.map((e) => Text('${e.key}: ${e.value}')).toList(),
                const SizedBox(height: 16),
                const Text('Teams:'),
                ...teams.map((e) => Text('${e['team']}: ${e['total']}')).toList(),
                const SizedBox(height: 16),
                const Text('Genders:'),
                ...genders.map((e) => Text('${e['gender']}: ${e['total']}')).toList(),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Map<String, int> _normalizeAndAggregateSizes(List<Map> sizes) {
    Map<String, String> normalizationMap = {
      'Smal': 'Small',
      'small': 'Small',
      'X-Sm': 'X-Small',
      'Medi': 'Medium',
      'Larg': 'Large',
      'large': 'Large',
      'X-La': 'X-Large',
      'XX-L': 'XX-Large',
      'xxlarge': 'XX-Large',
      'noThankYou': 'No T-Shirt',
      'No t': 'No T-Shirt',
    };

    Map<String, int> aggregatedSizes = {};

    for (var size in sizes) {
      String normalizedSize = normalizationMap[size['t_shirt']] ?? size['t_shirt'];
      // Use null-aware operators to ensure null-safety
      int currentValue = aggregatedSizes[normalizedSize] ?? 0;
      int additionalValue = size['total'] as int? ?? 0; // Cast and ensure not null, defaulting to 0
      aggregatedSizes[normalizedSize] = currentValue + additionalValue;
    }

    return aggregatedSizes;
  }

  void _showSnackBarWithMessage(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        )
    );
  }


}
