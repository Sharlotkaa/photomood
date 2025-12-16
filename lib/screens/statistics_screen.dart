import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../services/database_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, int> _monthStats = {};
  Map<String, int> _allStats = {};
  Map<String, int> _weeklyStats = {};
  int _totalEntries = 0;
  String _currentMonth = '';
  bool _isLoading = true;

  // Цвета для эмоций
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
    
    // Безопасная инициализация формата даты
    try {
      _currentMonth = DateFormat('MMMM yyyy', 'ru_RU').format(DateTime.now());
    } catch (e) {
      // Если русская локаль не инициализирована, используем английскую
      _currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    }
    
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    
    final now = DateTime.now();
    
    // Используем новые методы DatabaseService
    final allEntries = await DatabaseService().getAllEntries();
    
    // Статистика за текущий месяц
    final monthStats = await DatabaseService().getEmotionStats(
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 0),
    );
    
    // Общая статистика
    final allStats = await DatabaseService().getEmotionStats();
    
    // Статистика по дням недели за последние 30 дней
    final weeklyStats = await DatabaseService().getWeeklyStats();

    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _monthStats = monthStats;
      _allStats = allStats;
      _weeklyStats = weeklyStats;
      _totalEntries = allEntries.length;
      _isLoading = false;
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

  // Метод для получения отсортированных дней недели
  List<String> _getSortedWeekDays() {
    final days = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    final today = DateTime.now().weekday;
    
    // Сортируем дни недели, начиная с понедельника
    final sortedDays = <String>[];
    for (int i = 1; i <= 7; i++) {
      final index = (today + i - 2) % 7;
      sortedDays.add(days[index]);
    }
    
    return sortedDays;
  }

  // ИСПРАВЛЕННАЯ ВЕРСИЯ: Карточка статистики с фиксированной высотой
  Widget _buildStatCard(String title, IconData icon, Color color, String value, String subtitle) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 130, // Фиксированная минимальная высота
        maxHeight: 150, // Максимальная высота
      ),
      margin: const EdgeInsets.symmetric(vertical: 4), // Уменьшен отступ
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
        ]),
        borderRadius: BorderRadius.circular(16), // Уменьшен радиус
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16), // Уменьшен padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10), // Уменьшен padding
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24), // Уменьшен размер иконки
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 24, // Уменьшен размер шрифта
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12, // Уменьшен размер шрифта
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10, // Уменьшен размер шрифта
                  color: Colors.grey,
                ),
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
            touchCallback: (FlTouchEvent event, pieTouchResponse) {},
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final sortedWeekDays = _getSortedWeekDays();
    final shortDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    
    // Находим максимальное значение для масштабирования
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
                final dayName = sortedWeekDays[group.x.toInt()];
                return BarTooltipItem(
                  '$dayName\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: '${rod.toY.toInt()} записей',
                      style: const TextStyle(
                        color: Colors.white,
                      ),
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
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 11),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[200],
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              left: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          barGroups: List.generate(7, (index) {
            final dayName = sortedWeekDays[index];
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
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
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
              child: Text(
                _getEmoji(entry.key),
                style: const TextStyle(fontSize: 20),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    _getEmotionName(entry.key),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${entry.value}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
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
            // Карточка приветствия
            Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            
            // Сетка с метриками
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
            
            // Круговая диаграмма
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // График активности
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

  // Метод для получения самой частой эмоции с эмодзи
  String _getMostFrequentEmoji() {
    if (_allStats.isEmpty) return '-';
    
    final mostFrequent = _allStats.entries.reduce((a, b) => a.value > b.value ? a : b);
    return _getEmoji(mostFrequent.key);
  }

  @override
  Widget build(BuildContext context) {
    final totalMonth = _monthStats.values.fold(0, (sum, count) => sum + count);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика настроения'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: _isLoading
          ? _buildShimmerLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Приветствие
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          Theme.of(context).colorScheme.primary.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.emoji_emotions,
                          color: Theme.of(context).colorScheme.primary,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Анализ настроения',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'На основе ваших записей',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Ключевые метрики в сетке
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.1,
                    children: [
                      _buildStatCard(
                        'Всего записей',
                        Icons.book,
                        Colors.blue,
                        '$_totalEntries',
                        '',
                      ),
                      _buildStatCard(
                        'За месяц',
                        Icons.calendar_month,
                        Colors.green,
                        '$totalMonth',
                        _currentMonth,
                      ),
                      _buildStatCard(
                        'Разных эмоций',
                        Icons.emoji_emotions,
                        Colors.orange,
                        '${_allStats.length}',
                        '',
                      ),
                      _buildStatCard(
                        'Самая частая',
                        Icons.star,
                        Colors.purple,
                        _getMostFrequentEmoji(),
                        '',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Круговая диаграмма за месяц
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

                  // График активности
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

                  // Статистика за месяц
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

                  // Общая статистика
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

                  const SizedBox(height: 20), // Дополнительный отступ внизу
                ],
              ),
            ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadStatistics,
        backgroundColor: Theme.of(context).colorScheme.primary,
        mini: true,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}