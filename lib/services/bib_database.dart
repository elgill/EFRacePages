import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// App-wide handle to the local bib roster database.
///
/// sqflite hands every `openDatabase` call for the same path the *same*
/// connection, so code that opens, uses and then closes the database breaks
/// any other in-flight query (`database_closed`). Instead, the database is
/// opened once, lazily, and kept open for the life of the app; sqflite
/// serializes operations on the single connection.
class BibDatabase {
  BibDatabase._();

  static const fileName = 'race_data.db';

  static Future<Database>? _db;

  static Future<Database> get instance =>
      _db ??= _open().catchError((Object e) {
        _db = null; // allow a retry after a failed open
        throw e;
      });

  static Future<Database> _open() => openDatabase(
        fileName,
        version: 1,
        onCreate: (db, version) => db.execute('''
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
        '''),
      );

  /// Closes and forgets the shared connection (tests use a fresh database
  /// directory per test).
  ///
  /// The close is not awaited: a previous test may have left a transaction
  /// that will never finish, and close() would wait on it forever.
  @visibleForTesting
  static void reset() {
    final db = _db;
    _db = null;
    db?.then((d) => d.close()).catchError((Object _) {});
  }
}
