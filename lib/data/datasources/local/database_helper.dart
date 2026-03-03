import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Singleton helper to manage the sqflite database instance.
/// Handles creation, schema migrations, and provides the DB reference.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const int _version = 1;
  static const String _dbName = 'ticketing_cache.db';

  /// Get or create the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create all tables on first run
  Future<void> _onCreate(Database db, int version) async {
    // Tickets table
    await db.execute('''
      CREATE TABLE tickets (
        id INTEGER PRIMARY KEY,
        subject TEXT NOT NULL,
        description TEXT,
        category_id INTEGER,
        status_id INTEGER,
        priority TEXT,
        attachment TEXT,
        created_by INTEGER,
        assigned_to INTEGER,
        creator_info TEXT,
        assignee_info TEXT,
        category_json TEXT,
        status_json TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Ticket categories table
    await db.execute('''
      CREATE TABLE ticket_categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Ticket statuses table
    await db.execute('''
      CREATE TABLE ticket_statuses (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        is_final INTEGER NOT NULL DEFAULT 0,
        display_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Dashboard cache (key-value store for JSON blobs)
    await db.execute('''
      CREATE TABLE dashboard_cache (
        cache_key TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');

    // Cache metadata (tracks last sync time per table)
    await db.execute('''
      CREATE TABLE cache_metadata (
        table_name TEXT PRIMARY KEY,
        last_synced_at TEXT NOT NULL
      )
    ''');

    // Index for faster ticket queries
    await db.execute('CREATE INDEX idx_tickets_status ON tickets(status_id)');
    await db.execute('CREATE INDEX idx_tickets_priority ON tickets(priority)');
    await db.execute(
      'CREATE INDEX idx_tickets_created_at ON tickets(created_at DESC)',
    );
  }

  /// Handle schema migrations for future versions
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
    // if (oldVersion < 2) { ... }
  }

  /// Close the database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Delete the entire database (used for full reset)
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
