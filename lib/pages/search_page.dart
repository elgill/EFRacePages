import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

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
    // Replace with the actual URL, possibly using the raceId
    final String url = 'https://www.elitefeats.com/Bibs/?ID=$raceId';

    // Fetch the webpage
    final response = await http.get(Uri.parse(url));

    // Check for response status
    if (response.statusCode == 200) {
      // Parse the HTML
      final document = parser.parse(utf8.decode(response.bodyBytes));

      // Find the table with the runner information
      final table = document.querySelector('table'); // Adjust the selector as needed

      // Iterate over the rows in the table and extract data
      List<Map<String, dynamic>> runners = [];
      for (var row in table!.querySelectorAll('tr')) {
        // Extract data from each cell
        final cells = row.querySelectorAll('td').map((cell) => cell.text.trim()).toList();

        // Add the runner data to the list, ensuring there are cells (to skip headers)
        if (cells.isNotEmpty) {
          runners.add({
            'bib': cells[0],
            'name': cells[1],
            'age': cells[2],
            'gender': cells[3],
            'city': cells[4],
            'state': cells[5],
            'division': cells[6],
            'team': cells[7],
            't_shirt': cells[8],
            'extra': cells[9],
            'status': cells[10],
          });
        }
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
                behavior: SnackBarBehavior.floating,
            )
        );
        _searchDatabase('');
      } else {
        if (!mounted) return;

        // No data scraped, possibly due to network error
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to load data. Please check your internet connection.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
            )
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('An error occurred: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
          )
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _searchDatabase(String query) async {
    final db = await _openDatabase();
    List<Map<String, dynamic>> results = [];

    // Define the sort order based on the _isAscending flag
    String sortOrder = _isAscending ? 'ASC' : 'DESC';

    // Process each query term
    var searchTerms = query.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    // Initialize a list to hold parts of the WHERE clause
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    for (var term in searchTerms) {
      // Check if the term ends with '?'
      var questionMarks = term.split('?');
      if (questionMarks.length > 1 && RegExp(r'^\d+$').hasMatch(questionMarks[0])) {
        // There are '?' characters, adjust the search range
        int baseNumber = int.parse(questionMarks[0]);
        int range = questionMarks.length - 1; // Determine the range based on '?' count

        whereClauses.add('(bib BETWEEN ? AND ?)');
        whereArgs.add(baseNumber - range);
        whereArgs.add(baseNumber + range);
      } else if (term.contains('-')) {
        // Handle range within the term
        var parts = term.split('-');
        if (parts.length == 2) {
          whereClauses.add('(bib BETWEEN ? AND ?)');
          whereArgs.addAll([int.tryParse(parts[0].trim()) ?? 0, int.tryParse(parts[1].trim()) ?? 9999999]);
        }
      } else {
        // Handle single bib number or name
        whereClauses.add('(bib LIKE ? OR name LIKE ?)');
        whereArgs.addAll([term, '%$term%']);
      }
    }

    String combinedQuery = whereClauses.join(' OR ');

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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
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
                        children: [
                          if (_userSettings.fieldVisibility['bib'] == true)
                            Text('Bib: ${result['bib']}'),
                          if (_userSettings.fieldVisibility['division'] == true)
                            Text('Div: ${result['division']}'),
                          if (_userSettings.fieldVisibility['t_shirt'] == true)
                            Text('T-Shirt: ${result['t_shirt']}'),
                          // Add more fields as needed
                        ],
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



}
