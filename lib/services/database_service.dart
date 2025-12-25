import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mood_entry.dart';
import 'package:intl/intl.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static const String _webEntriesKey = 'mood_entries_web';
  static const String _webImagesKey = 'mood_images_web';

  // ============= БАЗОВЫЕ МЕТОДЫ =============

  Future<Database?> get database async {
    if (kIsWeb) {
      return null; // На Web не используем SQLite
    } else {
      if (_database != null) return _database!;
      _database = await _initDatabase();
      return _database!;
    }
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw Exception('SQLite не поддерживается на Web');
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'photomood.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE mood_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE,
        imagePath TEXT,
        emotion TEXT,
        note TEXT,
        location TEXT, 
        weather TEXT    
      )
    ''');

    await db.execute('CREATE INDEX idx_date ON mood_entries(date)');
    await db.execute('CREATE INDEX idx_emotion ON mood_entries(emotion)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      try {
        print('[Database] Обновляем базу с версии $oldVersion до $newVersion');
        
        // Ключевой момент: добавляем колонки
        await db.execute('ALTER TABLE mood_entries ADD COLUMN location TEXT');
        await db.execute('ALTER TABLE mood_entries ADD COLUMN weather TEXT');
        
        print('[Database] Добавлены колонки location и weather');
      } catch (e) {
        print('[Database] Ошибка обновления: $e');
      }
    }
  }
  // В database_service.dart добавьте:
Future<Map<String, int>> getYearlyStats() async {
  final entries = await getAllEntries();
  final stats = <String, int>{};
  
  for (final entry in entries) {
    final monthKey = DateFormat('MMMM yyyy', 'ru_RU').format(entry.date);
    stats[monthKey] = (stats[monthKey] ?? 0) + 1;
  }
  
  return stats;
}

Future<Map<String, int>> getWeeklyStats() async {
  final entries = await getAllEntries();
  final daysOfWeek = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
  final stats = <String, int>{};
  
  for (final day in daysOfWeek) {
    stats[day] = 0;
  }
  
  for (final entry in entries) {
    final dayIndex = (entry.date.weekday + 6) % 7; // Преобразование к Пн=0, Вс=6
    final dayName = daysOfWeek[dayIndex];
    stats[dayName] = (stats[dayName] ?? 0) + 1;
  }
  
  return stats;
}
  // ============= CRUD ОПЕРАЦИИ =============

  Future<int> insertEntry(MoodEntry entry) async {
    if (kIsWeb) {
      return await _insertEntryWeb(entry);
    } else {
      return await _insertEntryMobile(entry);
    }
  }

  Future<List<MoodEntry>> getAllEntries() async {
    if (kIsWeb) {
      return await _getAllEntriesWeb();
    } else {
      return await _getAllEntriesMobile();
    }
  }

  Future<MoodEntry?> getEntryForDate(DateTime date) async {
    if (kIsWeb) {
      return await _getEntryForDateWeb(date);
    } else {
      return await _getEntryForDateMobile(date);
    }
  }

  Future<int> updateEntry(MoodEntry entry) async {
    if (kIsWeb) {
      return await _updateEntryWeb(entry);
    } else {
      return await _updateEntryMobile(entry);
    }
  }

  Future<int> deleteEntry(int id) async {
    if (kIsWeb) {
      return await _deleteEntryWeb(id);
    } else {
      return await _deleteEntryMobile(id);
    }
  }

  // ============= WEB РЕАЛИЗАЦИЯ =============

  Future<int> _insertEntryWeb(MoodEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = await _getAllEntriesWeb();

      // Генерируем ID
      final newId = entries.isEmpty ? 1 : (entries.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
      final entryWithId = MoodEntry(
        id: newId,
        date: entry.date,
        imagePath: entry.imagePath,
        emotion: entry.emotion,
        note: entry.note,
      );

      entries.add(entryWithId);
      await _saveEntriesWeb(entries);

      return newId;
    } catch (e) {
      print('Ошибка вставки на Web: $e');
      return 0;
    }
  }

  Future<List<MoodEntry>> _getAllEntriesWeb() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = prefs.getStringList(_webEntriesKey) ?? [];

      return entriesJson.map((json) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          return MoodEntry.fromMap(map);
        } catch (e) {
          print('Ошибка парсинга записи: $e');
          return MoodEntry(
            id: 0,
            date: DateTime.now(),
            imagePath: '',
            emotion: 'neutral',
            note: '',
          );
        }
      }).toList();
    } catch (e) {
      print('Ошибка получения записей на Web: $e');
      return [];
    }
  }

  Future<void> _saveEntriesWeb(List<MoodEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = entries.map((entry) => jsonEncode(entry.toMap())).toList();
      await prefs.setStringList(_webEntriesKey, entriesJson);
    } catch (e) {
      print('Ошибка сохранения записей на Web: $e');
    }
  }

  Future<MoodEntry?> _getEntryForDateWeb(DateTime date) async {
    final entries = await _getAllEntriesWeb();
    final dateStr = _formatDateForComparison(date);

    for (var entry in entries) {
      final entryDateStr = _formatDateForComparison(entry.date);
      if (entryDateStr == dateStr) {
        return entry;
      }
    }
    return null;
  }

  String _formatDateForComparison(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<int> _updateEntryWeb(MoodEntry entry) async {
    try {
      final entries = await _getAllEntriesWeb();
      final index = entries.indexWhere((e) => e.id == entry.id);

      if (index != -1) {
        entries[index] = entry;
        await _saveEntriesWeb(entries);
        return 1;
      }
      return 0;
    } catch (e) {
      print('Ошибка обновления на Web: $e');
      return 0;
    }
  }

  Future<int> _deleteEntryWeb(int id) async {
    try {
      final entries = await _getAllEntriesWeb();
      final initialLength = entries.length;
      entries.removeWhere((entry) => entry.id == id);

      if (entries.length < initialLength) {
        await _saveEntriesWeb(entries);
        return 1;
      }
      return 0;
    } catch (e) {
      print('Ошибка удаления на Web: $e');
      return 0;
    }
  }

  // ============= МОБИЛЬНАЯ РЕАЛИЗАЦИЯ =============

  Future<int> _insertEntryMobile(MoodEntry entry) async {
    final db = await database;
    if (db == null) return 0;

    return await db.insert(
      'mood_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MoodEntry>> _getAllEntriesMobile() async {
    final db = await database;
    if (db == null) return [];

    final maps = await db.query('mood_entries', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => MoodEntry.fromMap(maps[i]));
  }

  Future<MoodEntry?> _getEntryForDateMobile(DateTime date) async {
    final db = await database;
    if (db == null) return null;

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

  Future<int> _updateEntryMobile(MoodEntry entry) async {
    final db = await database;
    if (db == null) return 0;

    return await db.update(
      'mood_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> _deleteEntryMobile(int id) async {
    final db = await database;
    if (db == null) return 0;

    return await db.delete(
      'mood_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============= ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ =============

  Future<List<MoodEntry>> getEntriesForMonth(DateTime month) async {
    if (kIsWeb) {
      return await _getEntriesForMonthWeb(month);
    } else {
      return await _getEntriesForMonthMobile(month);
    }
  }

  Future<List<MoodEntry>> _getEntriesForMonthWeb(DateTime month) async {
    final entries = await _getAllEntriesWeb();
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    return entries.where((entry) {
      return entry.date.isAfter(firstDay.subtract(const Duration(days: 1))) &&
          entry.date.isBefore(lastDay.add(const Duration(days: 1)));
    }).toList();
  }

  Future<List<MoodEntry>> _getEntriesForMonthMobile(DateTime month) async {
    final db = await database;
    if (db == null) return [];

    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final maps = await db.query(
      'mood_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [
        firstDay.toIso8601String(),
        lastDay.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) => MoodEntry.fromMap(maps[i]));
  }

  Future<List<MoodEntry>> getEntriesForWeek(DateTime date) async {
    if (kIsWeb) {
      return await _getEntriesForWeekWeb(date);
    } else {
      return await _getEntriesForWeekMobile(date);
    }
  }

  Future<List<MoodEntry>> _getEntriesForWeekWeb(DateTime date) async {
    final entries = await _getAllEntriesWeb();
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    return entries.where((entry) {
      return entry.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          entry.date.isBefore(weekEnd.add(const Duration(days: 1)));
    }).toList();
  }

  Future<List<MoodEntry>> _getEntriesForWeekMobile(DateTime date) async {
    final db = await database;
    if (db == null) return [];

    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final maps = await db.query(
      'mood_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [
        weekStart.toIso8601String(),
        weekEnd.toIso8601String(),
      ],
      orderBy: 'date ASC',
    );

    return List.generate(maps.length, (i) => MoodEntry.fromMap(maps[i]));
  }

  Future<Map<String, int>> _getWeeklyStatsMobile() async {
    final db = await database;
    if (db == null) return {};

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final maps = await db.rawQuery('''
      SELECT 
        strftime('%w', date) as day_of_week,
        COUNT(*) as count
      FROM mood_entries 
      WHERE date >= ?
      GROUP BY strftime('%w', date)
      ORDER BY strftime('%w', date)
    ''', [thirtyDaysAgo.toIso8601String()]);

    final Map<String, int> result = {};
    final dayNames = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];

    for (var map in maps) {
      final dayNum = int.parse(map['day_of_week'] as String);
      final dayName = dayNames[dayNum];
      result[dayName] = map['count'] as int;
    }

    return result;
  }

  Future<Map<String, int>> getEmotionStats({DateTime? startDate, DateTime? endDate}) async {
    if (kIsWeb) {
      return await _getEmotionStatsWeb(startDate: startDate, endDate: endDate);
    } else {
      return await _getEmotionStatsMobile(startDate: startDate, endDate: endDate);
    }
  }

  Future<Map<String, int>> _getEmotionStatsWeb({DateTime? startDate, DateTime? endDate}) async {
    final entries = await _getAllEntriesWeb();
    final filteredEntries = entries.where((entry) {
      if (startDate != null && endDate != null) {
        return entry.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            entry.date.isBefore(endDate.add(const Duration(days: 1)));
      }
      return true;
    }).toList();

    final Map<String, int> result = {};
    for (var entry in filteredEntries) {
      result[entry.emotion] = (result[entry.emotion] ?? 0) + 1;
    }

    return result;
  }

  Future<Map<String, int>> _getEmotionStatsMobile({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    if (db == null) return {};

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause = 'WHERE date BETWEEN ? AND ?';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }

    final maps = await db.rawQuery('''
      SELECT 
        emotion,
        COUNT(*) as count
      FROM mood_entries 
      $whereClause
      GROUP BY emotion
      ORDER BY count DESC
    ''', whereArgs);

    final Map<String, int> result = {};
    for (var map in maps) {
      result[map['emotion'] as String] = map['count'] as int;
    }

    return result;
  }

  Future<String?> getMostFrequentEmotion({DateTime? startDate, DateTime? endDate}) async {
    if (kIsWeb) {
      return await _getMostFrequentEmotionWeb(startDate: startDate, endDate: endDate);
    } else {
      return await _getMostFrequentEmotionMobile(startDate: startDate, endDate: endDate);
    }
  }

  Future<String?> _getMostFrequentEmotionWeb({DateTime? startDate, DateTime? endDate}) async {
    final stats = await _getEmotionStatsWeb(startDate: startDate, endDate: endDate);
    if (stats.isEmpty) return null;

    var maxKey = stats.keys.first;
    var maxValue = stats[maxKey]!;

    for (var entry in stats.entries) {
      if (entry.value > maxValue) {
        maxValue = entry.value;
        maxKey = entry.key;
      }
    }

    return maxKey;
  }

  Future<String?> _getMostFrequentEmotionMobile({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    if (db == null) return null;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause = 'WHERE date BETWEEN ? AND ?';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }

    final maps = await db.rawQuery('''
      SELECT 
        emotion,
        COUNT(*) as count
      FROM mood_entries 
      $whereClause
      GROUP BY emotion
      ORDER BY count DESC
      LIMIT 1
    ''', whereArgs);

    if (maps.isNotEmpty) {
      return maps.first['emotion'] as String;
    }

    return null;
  }

  Future<int> getEntryCount({DateTime? startDate, DateTime? endDate}) async {
    if (kIsWeb) {
      return await _getEntryCountWeb(startDate: startDate, endDate: endDate);
    } else {
      return await _getEntryCountMobile(startDate: startDate, endDate: endDate);
    }
  }

  Future<int> _getEntryCountWeb({DateTime? startDate, DateTime? endDate}) async {
    final entries = await _getAllEntriesWeb();
    final filteredEntries = entries.where((entry) {
      if (startDate != null && endDate != null) {
        return entry.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            entry.date.isBefore(endDate.add(const Duration(days: 1)));
      }
      return true;
    }).toList();

    return filteredEntries.length;
  }

  Future<int> _getEntryCountMobile({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    if (db == null) return 0;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause = 'WHERE date BETWEEN ? AND ?';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM mood_entries 
      $whereClause
    ''', whereArgs);

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<MoodEntry>> getRecentEntries(int limit) async {
    if (kIsWeb) {
      return await _getRecentEntriesWeb(limit);
    } else {
      return await _getRecentEntriesMobile(limit);
    }
  }

  Future<List<MoodEntry>> _getRecentEntriesWeb(int limit) async {
    final entries = await _getAllEntriesWeb();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries.take(limit).toList();
  }

  Future<List<MoodEntry>> _getRecentEntriesMobile(int limit) async {
    final db = await database;
    if (db == null) return [];

    final maps = await db.query(
      'mood_entries',
      orderBy: 'date DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) => MoodEntry.fromMap(maps[i]));
  }

  Future<List<DateTime>> getDatesWithEntries() async {
    if (kIsWeb) {
      return await _getDatesWithEntriesWeb();
    } else {
      return await _getDatesWithEntriesMobile();
    }
  }

  Future<List<DateTime>> _getDatesWithEntriesWeb() async {
    final entries = await _getAllEntriesWeb();
    final dates = entries.map((entry) => DateTime(
          entry.date.year,
          entry.date.month,
          entry.date.day,
        )).toSet().toList();
    
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }

  Future<List<DateTime>> _getDatesWithEntriesMobile() async {
    final db = await database;
    if (db == null) return [];

    final maps = await db.rawQuery('''
      SELECT DISTINCT date 
      FROM mood_entries 
      ORDER BY date DESC
    ''');

    return maps.map((map) => DateTime.parse(map['date'] as String)).toList();
  }

  Future<void> clearAllEntries() async {
    if (kIsWeb) {
      await _clearAllEntriesWeb();
    } else {
      await _clearAllEntriesMobile();
    }
  }

  Future<void> _clearAllEntriesWeb() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_webEntriesKey);
      await prefs.remove(_webImagesKey);
    } catch (e) {
      print('Ошибка очистки на Web: $e');
    }
  }

  Future<void> _clearAllEntriesMobile() async {
    final db = await database;
    if (db == null) return;

    await db.delete('mood_entries');
  }

  Future<void> close() async {
    if (!kIsWeb && _database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // ============= МЕТОДЫ ДЛЯ РАБОТЫ С ИЗОБРАЖЕНИЯМИ =============

  Future<void> saveImageBytes(String imageKey, Uint8List bytes) async {
    if (kIsWeb) {
      await _saveImageBytesWeb(imageKey, bytes);
    } else {
      // На мобильных изображения сохраняются в файловой системе
      // Этот метод может не понадобиться, если imagePath - это путь к файлу
    }
  }

  Future<void> _saveImageBytesWeb(String imageKey, Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64Image = base64.encode(bytes);
      await prefs.setString('$_webImagesKey$imageKey', base64Image);
    } catch (e) {
      print('Ошибка сохранения изображения на Web: $e');
    }
  }

  Future<Uint8List?> loadImageBytes(String imageKey) async {
    if (kIsWeb) {
      return await _loadImageBytesWeb(imageKey);
    } else {
      // На мобильных загружаем из файла
      try {
        final file = File(imageKey);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (e) {
        print('Ошибка загрузки изображения: $e');
      }
      return null;
    }
  }

  Future<Uint8List?> _loadImageBytesWeb(String imageKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64Image = prefs.getString('$_webImagesKey$imageKey');
      if (base64Image != null) {
        return base64.decode(base64Image);
      }
    } catch (e) {
      print('Ошибка загрузки изображения на Web: $e');
    }
    return null;
  }
}
