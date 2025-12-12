import 'package:flutter/material.dart';
import '../services/database_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, int> _monthStats = {};
  Map<String, int> _allStats = {};
  int _totalEntries = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final now = DateTime.now();
    final allEntries = await DatabaseService().getAllEntries();
    final monthEntries = await DatabaseService().getEntriesForMonth(now);

    // Статистика за месяц
    final monthStats = <String, int>{};
    for (var entry in monthEntries) {
      monthStats[entry.emotion] = (monthStats[entry.emotion] ?? 0) + 1;
    }

    // Общая статистика
    final allStats = <String, int>{};
    for (var entry in allEntries) {
      allStats[entry.emotion] = (allStats[entry.emotion] ?? 0) + 1;
    }

    setState(() {
      _monthStats = monthStats;
      _allStats = allStats;
      _totalEntries = allEntries.length;
    });
  }

  String _getEmoji(String emotion) {
    switch (emotion) {
      case 'happy': return '😊';
      case 'neutral': return '😐';
      case 'sad': return '😔';
      case 'excited': return '🤩';
      case 'angry': return '😠';
      default: return '😊';
    }
  }

  String _getEmotionName(String emotion) {
    switch (emotion) {
      case 'happy': return 'Счастливый';
      case 'neutral': return 'Нейтральный';
      case 'sad': return 'Грустный';
      case 'excited': return 'Восторг';
      case 'angry': return 'Злой';
      default: return emotion;
    }
  }

  Widget _buildEmotionCard(String emotion, int count, int total) {
    final percentage = total > 0 ? (count / total * 100) : 0;
    
    return Card(
      child: ListTile(
        leading: Text(
          _getEmoji(emotion),
          style: const TextStyle(fontSize: 32),
        ),
        title: Text(_getEmotionName(emotion)),
        subtitle: LinearProgressIndicator(
          value: total > 0 ? count / total : 0,
          backgroundColor: Colors.grey[200],
          color: _getColorForEmotion(emotion),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$count'),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForEmotion(String emotion) {
    switch (emotion) {
      case 'happy': return Colors.green;
      case 'excited': return Colors.yellow;
      case 'neutral': return Colors.blue;
      case 'sad': return Colors.purple;
      case 'angry': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Общая информация
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.photo_library, size: 50, color: Colors.blue),
                    const SizedBox(height: 10),
                    Text(
                      'Всего записей: $_totalEntries',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Статистика за месяц
            const Text(
              'За этот месяц:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            if (_monthStats.isEmpty)
              const Text('Нет записей за этот месяц')
            else
              Column(
                children: _monthStats.entries.map((entry) {
                  final totalMonth = _monthStats.values.fold(0, (sum, count) => sum + count);
                  return _buildEmotionCard(entry.key, entry.value, totalMonth);
                }).toList(),
              ),

            const SizedBox(height: 30),

            // Общая статистика
            const Text(
              'За все время:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            if (_allStats.isEmpty)
              const Text('Нет записей')
            else
              Column(
                children: _allStats.entries.map((entry) {
                  return _buildEmotionCard(entry.key, entry.value, _totalEntries);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}