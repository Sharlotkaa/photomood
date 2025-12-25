import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../models/mood_entry.dart';
import '../services/theme_service.dart';


class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, int> _monthStats = {};
  Map<String, int> _allStats = {};
  Map<String, int> _weeklyStats = {};
  Map<String, int> _yearlyStats = {};
  Map<String, int> _photoStats = {};
  Map<String, int> _noteStats = {};
  List<MoodEntry> _allEntries = [];
  
  int _totalEntries = 0;
  int _photoEntriesCount = 0;
  int _noteEntriesCount = 0;
  int _entriesWithBoth = 0;
  double _averageEntriesPerDay = 0;
  String _currentMonth = '';
  DateTime? _firstEntryDate;
  DateTime? _lastEntryDate;
  String _mostActiveDay = '';
  String _mostActiveMonth = '';
  String _longestStreak = '0';
  String _currentStreak = '0';
  
  bool _isLoading = true;
  bool _isCalculating = false;
  DateTime? _lastCalculationTime;

  static const Map<String, Color> _emotionColors = {
    'happy': Color(0xFF4CAF50),
    'excited': Color(0xFFFFC107),
    'neutral': Color(0xFF2196F3),
    'sad': Color(0xFF9C27B0),
    'angry': Color(0xFFF44336),
  };

  @override
  void initState() {
    super.initState();
    
    try {
      _currentMonth = DateFormat('MMMM yyyy', 'ru_RU').format(DateTime.now());
    } catch (e) {
      _currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    }
    
    Future.delayed(Duration.zero, () {
      _loadStatistics();
    });
  }

  Future<void> _loadStatistics({bool forceRefresh = false}) async {
    final now = DateTime.now();
    
    if (_lastCalculationTime != null && 
        !forceRefresh && 
        now.difference(_lastCalculationTime!) < const Duration(minutes: 5)) {
      return;
    }
    
    if (_isCalculating) return;
    
    try {
      setState(() {
        _isLoading = true;
        _isCalculating = true;
      });
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      final allEntries = await DatabaseService().getAllEntries();
      _allEntries = allEntries;
      
      // Собираем расширенную статистику
      final futures = await Future.wait([
        DatabaseService().getEmotionStats(
          startDate: DateTime(now.year, now.month, 1),
          endDate: DateTime(now.year, now.month + 1, 0),
        ),
        DatabaseService().getEmotionStats(),
        DatabaseService().getWeeklyStats(),
        DatabaseService().getYearlyStats(),
      ]);
      
      final monthStats = futures[0] as Map<String, int>;
      final allStats = futures[1] as Map<String, int>;
      final weeklyStats = futures[2] as Map<String, int>;
      final yearlyStats = futures[3] as Map<String, int>;
      
      // Расширенная статистика
      final photoEntries = allEntries.where((e) => e.imagePath.isNotEmpty).length;
      final noteEntries = allEntries.where((e) => (e.note?.isNotEmpty ?? false)).length;
      final entriesWithBoth = allEntries.where((e) => 
          e.imagePath.isNotEmpty && (e.note?.isNotEmpty ?? false)).length;
      
      // Даты первой и последней записи
      final dates = allEntries.map((e) => e.date).toList();
      final firstDate = dates.isNotEmpty ? dates.reduce((a, b) => a.isBefore(b) ? a : b) : null;
      final lastDate = dates.isNotEmpty ? dates.reduce((a, b) => a.isAfter(b) ? a : b) : null;
      
      // Среднее количество записей в день
      double avgPerDay = 0;
      if (firstDate != null && allEntries.isNotEmpty) {
        final daysDiff = lastDate!.difference(firstDate).inDays + 1;
        avgPerDay = daysDiff > 0 ? allEntries.length / daysDiff : allEntries.length.toDouble();
      }
      
      // Самая активная неделя и месяц
      final mostActiveDayEntry = weeklyStats.entries.isNotEmpty 
          ? weeklyStats.entries.reduce((a, b) => a.value > b.value ? a : b)
          : null;
      final mostActiveMonthEntry = yearlyStats.entries.isNotEmpty
          ? yearlyStats.entries.reduce((a, b) => a.value > b.value ? a : b)
          : null;
      
      // Серия записей (streak)
      final streakInfo = _calculateStreaks(allEntries);
      
      setState(() {
        _monthStats = monthStats;
        _allStats = allStats;
        _weeklyStats = weeklyStats;
        _yearlyStats = yearlyStats;
        
        _totalEntries = allEntries.length;
        _photoEntriesCount = photoEntries;
        _noteEntriesCount = noteEntries;
        _entriesWithBoth = entriesWithBoth;
        _averageEntriesPerDay = avgPerDay;
        _firstEntryDate = firstDate;
        _lastEntryDate = lastDate;
        _mostActiveDay = mostActiveDayEntry?.key ?? '-';
        _mostActiveMonth = mostActiveMonthEntry?.key ?? '-';
        _longestStreak = streakInfo['longest'] ?? '0';
        _currentStreak = streakInfo['current'] ?? '0';
        
        _isLoading = false;
        _lastCalculationTime = now;
      });
      
    } catch (e) {
      print('Ошибка загрузки статистики: $e');
      setState(() => _isLoading = false);
    } finally {
      setState(() => _isCalculating = false);
    }
  }

  Map<String, String> _calculateStreaks(List<MoodEntry> entries) {
    if (entries.isEmpty) return {'longest': '0', 'current': '0'};
    
    // Сортируем записи по дате
    final sortedEntries = entries.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    // Уникальные даты
    final uniqueDates = sortedEntries
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .toList()
      ..sort();
    
    int longestStreak = 0;
    int currentStreak = 0;
    int tempStreak = 1;
    
    // Начинаем с первой даты
    DateTime? lastDate = uniqueDates.first;
    
    for (int i = 1; i < uniqueDates.length; i++) {
      final currentDate = uniqueDates[i];
      final difference = currentDate.difference(lastDate!).inDays;
      
      if (difference == 1) {
        // Последовательные дни
        tempStreak++;
      } else {
        // Разрыв в последовательности
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
        tempStreak = 1;
      }
      
      lastDate = currentDate;
    }
    
    // Проверяем последнюю последовательность
    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
    }
    
    // Текущая серия (до сегодняшнего дня)
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (uniqueDates.isNotEmpty) {
      final lastEntryDate = uniqueDates.last;
      final diff = today.difference(lastEntryDate).inDays;
      
      if (diff == 0) {
        // Запись сегодня
        currentStreak = tempStreak;
      } else if (diff == 1 && 
          yesterday.year == lastEntryDate.year &&
          yesterday.month == lastEntryDate.month &&
          yesterday.day == lastEntryDate.day) {
        // Запись была вчера
        currentStreak = tempStreak;
      }
    }
    
    return {
      'longest': longestStreak.toString(),
      'current': currentStreak.toString(),
    };
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

  Widget _buildAdvancedStatCard(String title, IconData icon, Color color, String value, String subtitle, [String? extraInfo]) {
    return Container(
      constraints: const BoxConstraints(minHeight: 130, maxHeight: 150),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (extraInfo != null && extraInfo.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                extraInfo,
                style: TextStyle(fontSize: 9, color: color.withOpacity(0.7)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    final themeService = Provider.of<ThemeService>(context);
    final isDarkMode = themeService.isDarkMode;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [Colors.purple.withOpacity(0.3), Colors.purple.withOpacity(0.1)]
              : [Colors.purple.withOpacity(0.15), Colors.purple.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department, color: Colors.orange, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Текущая серия: $_currentStreak дней',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Рекорд: $_longestStreak дней',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (_currentStreak != '0')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.whatshot, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '🔥',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineInfo() {
    if (_firstEntryDate == null || _lastEntryDate == null) {
      return Container();
    }
    
    final daysTotal = _lastEntryDate!.difference(_firstEntryDate!).inDays + 1;
    final monthsTotal = (daysTotal / 30.44).toStringAsFixed(1);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Text(
                'Хронология',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Начало',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    DateFormat('dd.MM.yyyy').format(_firstEntryDate!),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                height: 1,
                width: 40,
                color: Colors.grey[300],
              ),
              Column(
                children: [
                  Text(
                    '$daysTotal дней',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '(${monthsTotal} мес.)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
              Container(
                height: 1,
                width: 40,
                color: Colors.grey[300],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Последняя',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    DateFormat('dd.MM.yyyy').format(_lastEntryDate!),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentTypeStats() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Типы записей',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildContentTypeItem('С фото', _photoEntriesCount, Icons.photo, Colors.blue),
              const SizedBox(width: 16),
              _buildContentTypeItem('С заметками', _noteEntriesCount, Icons.note, Colors.green),
              const SizedBox(width: 16),
              _buildContentTypeItem('Оба типа', _entriesWithBoth, Icons.photo_library, Colors.purple),
            ],
          ),
          if (_totalEntries > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _photoEntriesCount / _totalEntries,
              backgroundColor: Colors.grey[200],
              color: Colors.blue,
              minHeight: 6,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${((_photoEntriesCount / _totalEntries) * 100).toStringAsFixed(0)}% с фото',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '${((_noteEntriesCount / _totalEntries) * 100).toStringAsFixed(0)}% с заметками',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentTypeItem(String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityInsights() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Инсайты активности',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInsightItem(
                  'Среднее в день',
                  '${_averageEntriesPerDay.toStringAsFixed(2)}',
                  Icons.trending_up,
                  _averageEntriesPerDay >= 0.5 ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightItem(
                  'Активный день',
                  _mostActiveDay,
                  Icons.calendar_today,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInsightItem(
                  'Активный месяц',
                  _mostActiveMonth,
                  Icons.date_range,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightItem(
                  'Записей с фото',
                  '${((_photoEntriesCount / (_totalEntries == 0 ? 1 : _totalEntries)) * 100).toStringAsFixed(0)}%',
                  Icons.photo_camera,
                  Colors.cyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> stats, int total) {
    if (stats.isEmpty || total == 0) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pie_chart_outline, size: 50, color: Colors.grey),
              SizedBox(height: 10),
              Text('Нет данных для отображения'),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: stats.entries.map((entry) {
            final color = _emotionColors[entry.key] ?? Colors.grey;
            return PieChartSectionData(
              color: color,
              value: entry.value.toDouble(),
              title: '${(entry.value / total * 100).toStringAsFixed(0)}%',
              radius: 35,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              if (event is FlTapUpEvent && pieTouchResponse != null) {
                final section = pieTouchResponse.touchedSection;
                if (section != null) {
                  final index = section.touchedSectionIndex;
                  final emotion = stats.keys.elementAt(index);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${_getEmotionName(emotion)}: ${stats[emotion]} записей (${((stats[emotion]! / total) * 100).toStringAsFixed(1)}%)',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final days = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    final shortDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    
    final maxValue = _weeklyStats.values.isNotEmpty 
      ? _weeklyStats.values.reduce((a, b) => a > b ? a : b)
      : 0;
    
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue + 1.0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.black87,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final dayName = days[group.x.toInt()];
                return BarTooltipItem(
                  '$dayName\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: '${rod.toY.toInt()} записей',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      shortDays[value.toInt()],
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Text(value.toInt().toString(), style: const TextStyle(fontSize: 11));
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200], strokeWidth: 1),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              left: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          barGroups: List.generate(7, (index) {
            final dayName = days[index];
            final count = _weeklyStats[dayName] ?? 0;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: count.toDouble(),
                  color: Theme.of(context).primaryColor.withOpacity(0.7),
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildEmotionList(Map<String, int> stats, int total) {
    if (stats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.emoji_emotions_outlined, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text('Нет данных', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final sortedStats = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedStats.map((entry) {
        final percentage = total > 0 ? (entry.value / total * 100) : 0;
        final color = _emotionColors[entry.key] ?? Colors.grey;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Text(_getEmoji(entry.key), style: const TextStyle(fontSize: 20)),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    _getEmotionName(entry.key),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${entry.value}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: total > 0 ? entry.value / total : 0,
                          backgroundColor: Colors.grey[200],
                          color: color,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.1,
              children: List.generate(4, (index) => 
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            
            const SizedBox(height: 20),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMostFrequentEmoji() {
    if (_allStats.isEmpty) return '-';
    final mostFrequent = _allStats.entries.reduce((a, b) => a.value > b.value ? a : b);
    return _getEmoji(mostFrequent.key);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final totalMonth = _monthStats.values.fold(0, (sum, count) => sum + count);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расширенная статистика'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('О статистике'),
                  content: const Text(
                    'Здесь представлена расширенная статистика ваших настроений. '
                    'Данные обновляются автоматически каждые 5 минут или при обновлении вручную.\n\n'
                    '• Серия (streak) - последовательные дни с записями\n'
                    '• Инсайты - полезные выводы из ваших данных\n'
                    '• Хронология - период ведения дневника\n'
                    '• Типы записей - фото, заметки или оба типа',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Закрыть'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadStatistics(forceRefresh: true),
        child: _isLoading
          ? _buildShimmerLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Серия записей
                  _buildStreakCard(),
                  
                  // Хронология
                  _buildTimelineInfo(),
                  
                  // Основные карточки статистики
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.1,
                    children: [
                      _buildAdvancedStatCard('Всего записей', Icons.book, Colors.blue, '$_totalEntries', '', ''),
                      _buildAdvancedStatCard('За месяц', Icons.calendar_month, Colors.green, '$totalMonth', _currentMonth, ''),
                      _buildAdvancedStatCard('С фото', Icons.photo, Colors.cyan, '$_photoEntriesCount', '', ''),
                      _buildAdvancedStatCard('С заметками', Icons.note, Colors.orange, '$_noteEntriesCount', '', ''),
                    ],
                  ),
                  
                  // Инсайты активности
                  _buildActivityInsights(),
                  
                  // Типы записей
                  _buildContentTypeStats(),
                  
                  // Графики
                  const SizedBox(height: 20),
                  Text(
                    'Распределение за месяц',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPieChart(_monthStats, totalMonth),
                  
                  const SizedBox(height: 20),
                  Text(
                    'Активность по дням недели',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBarChart(),
                  
                  const SizedBox(height: 20),
                  Text(
                    'Детали за месяц',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildEmotionList(_monthStats, totalMonth),
                  ),
                  
                  const SizedBox(height: 20),
                  Text(
                    'Общая статистика',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildEmotionList(_allStats, _totalEntries),
                  ),
                  
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.insights, size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'Продолжайте вести дневник,\nчтобы увидеть больше статистики!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _loadStatistics(forceRefresh: true),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}