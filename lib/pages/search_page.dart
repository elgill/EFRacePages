import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

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

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final document = parser.parse(response.body);

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
          });
        }
      }

      return runners;
    } else {
      throw Exception('Failed to load webpage = ${response.statusCode}');
    }
  }


  Future<void> _loadData() async {
    // Here, call the method to scrape data and then store it locally
    var scrapedData = await scrapeDataFromWebPage(widget.raceId);
    await storeDataLocally(scrapedData);

    setState(() => _isLoading = false);
  }

/*
  Future<void> _searchDatabase(String query) async {
    final db = await _openDatabase();
    List<Map<String, dynamic>> results = [];

    // Define the sort order based on the _isAscending flag
    String sortOrder = _isAscending ? 'ASC' : 'DESC';

    if (query.contains('-')) {
      // Handle range query
      var parts = query.split('-');
      if (parts.length == 2) {
        int start = int.tryParse(parts[0].trim()) ?? 0;
        int end = int.tryParse(parts[1].trim()) ?? 0;

        results = await db.query(
          'bib_data',
          where: 'bib BETWEEN ? AND ?',
          whereArgs: [start, end],
          orderBy: 'bib $sortOrder', // Use sortOrder in the query
        );
      }
    } else {
      // Handle regular query
      results = await db.query(
        'bib_data',
        where: 'bib LIKE ? OR name LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'bib $sortOrder', // Use sortOrder in the query
      );
    }

    setState(() {
      _searchResults = results;
    });
    await db.close();
  }
*/

  Future<void> _searchDatabase(String query) async {
    final db = await _openDatabase();
    List<Map<String, dynamic>> results = [];

    // Define the sort order based on the _isAscending flag
    String sortOrder = _isAscending ? 'ASC' : 'DESC';

    if (query.contains('-')) {
      // Handle range query
      var parts = query.split('-');
      if (parts.length == 2) {
        int start = int.tryParse(parts[0].trim()) ?? 0;
        int end = int.tryParse(parts[1].trim()) ?? 0;

        results = await db.query(
          'bib_data',
          where: 'bib BETWEEN ? AND ?',
          whereArgs: [start, end],
          orderBy: 'bib $sortOrder', // Use sortOrder in the query
        );
      }
    } else if (query.contains('/')) {
      // Handle multiple bib numbers or names
      var searchTerms = query.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      // Building a combined query for bib and name
      var combinedQuery = searchTerms.map((term) {
        return '(bib LIKE ? OR name LIKE ?)';
      }).join(' OR ');

      results = await db.query(
        'bib_data',
        where: combinedQuery,
        whereArgs: searchTerms.expand((term) => ['%$term%', '%$term%']).toList(),
        orderBy: 'bib $sortOrder',
      );
    } else {
      // Handle regular query
      results = await db.query(
        'bib_data',
        where: 'bib LIKE ? OR name LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'bib $sortOrder', // Use sortOrder in the query
      );
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
                        //helperText: 'Enter bib numbers, names, ranges (100-105), or multiple terms separated by "/"',
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
                          Text('Bib: ${result['bib']}'),
                          Text('Div: ${result['division']}'),
                          Text('T-Shirt: ${result['t_shirt']}'), // Display t-shirt size
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

}
