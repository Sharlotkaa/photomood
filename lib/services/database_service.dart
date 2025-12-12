import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/mood_entry.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'photomood.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE mood_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE,
        imagePath TEXT,
        emotion TEXT,
        note TEXT
      )
    ''');
  }

  // CRUD операции
  Future<int> insertEntry(MoodEntry entry) async {
    final db = await database;
    return await db.insert(
      'mood_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MoodEntry>> getEntriesForMonth(DateTime month) async {
    final db = await database;
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    
    final maps = await db.query(
      'mood_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [
        firstDay.toIso8601String(),
        lastDay.toIso8601String(),
      ],
    );
    
    return List.generate(maps.length, (i) => MoodEntry.fromMap(maps[i]));
  }

  Future<MoodEntry?> getEntryForDate(DateTime date) async {
    final db = await database;
    final maps = await db.query(
      'mood_entries',
      where: 'date = ?',
      whereArgs: [date.toIso8601String()],
    );
    
    if (maps.isNotEmpty) {
      return MoodEntry.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateEntry(MoodEntry entry) async {
    final db = await database;
    return await db.update(
      'mood_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteEntry(int id) async {
    final db = await database;
    return await db.delete(
      'mood_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<MoodEntry>> getAllEntries() async {
    final db = await database;
    final maps = await db.query('mood_entries');
    return List.generate(maps.length, (i) => MoodEntry.fromMap(maps[i]));
  }
}