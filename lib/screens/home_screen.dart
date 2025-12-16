import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/mood_entry.dart';
import '../services/database_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, MoodEntry> _entries = {};
  List<MoodEntry> _recentPhotoEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    
    try {
      final entries = await DatabaseService().getEntriesForMonth(_focusedDay);
      
      // Получаем последние записи с фото и заметками
      final allEntries = await DatabaseService().getAllEntries();
      final photoEntries = allEntries
          .where((entry) => (entry.note?.isNotEmpty ?? false) || entry.imagePath.isNotEmpty)
          .take(5)
          .toList();
      
      setState(() {
        _entries = {
          for (var entry in entries)
            DateTime(entry.date.year, entry.date.month, entry.date.day): entry
        };
        _recentPhotoEntries = photoEntries;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки: $e');
      setState(() => _isLoading = false);
    }
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

  Color _getEmotionColor(String emotion) {
    switch (emotion) {
      case 'happy': return Colors.yellow;
      case 'neutral': return Colors.grey;
      case 'sad': return Colors.blue;
      case 'excited': return Colors.pink;
      case 'angry': return Colors.red;
      default: return Colors.grey;
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

  Widget _buildDayContent(DateTime day, List<dynamic> events) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final entry = _entries[normalizedDay];
    final isToday = isSameDay(day, DateTime.now());
    
    return Container(
      margin: const EdgeInsets.all(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day.day.toString(),
            style: TextStyle(
              fontSize: 14,
              color: day.month == _focusedDay.month 
                ? (isToday ? Colors.blue : Colors.black)
                : Colors.grey,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (entry != null) ...[
            const SizedBox(height: 2),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getEmotionColor(entry.emotion).withOpacity(0.2),
                border: Border.all(
                  color: _getEmotionColor(entry.emotion),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  _getEmoji(entry.emotion),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Виджет для отображения фото или заметки
  Widget _buildPhotoNoteItem(MoodEntry entry, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/day',
          arguments: {'entry': entry},
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Дата и эмоция
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getEmotionColor(entry.emotion).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${entry.date.day}.${entry.date.month}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getEmotionColor(entry.emotion).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getEmoji(entry.emotion),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            
            // Изображение (если есть)
            if (entry.imagePath.isNotEmpty)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                ),
                child: FutureBuilder<Uint8List?>(
                  future: kIsWeb 
                      ? DatabaseService().loadImageBytes(entry.imagePath)
                      : null,
                  builder: (context, snapshot) {
                    if (kIsWeb) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: _getEmotionColor(entry.emotion),
                          ),
                        );
                      }
                      if (snapshot.hasData && snapshot.data != null) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 120,
                        );
                      } else {
                        return Container(
                          color: _getEmotionColor(entry.emotion).withOpacity(0.2),
                          child: Center(
                            child: Text(
                              _getEmoji(entry.emotion),
                              style: const TextStyle(fontSize: 40),
                            ),
                          ),
                        );
                      }
                    } else {
                      return Image.file(
                        File(entry.imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 120,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: _getEmotionColor(entry.emotion).withOpacity(0.2),
                            child: Center(
                              child: Text(
                                _getEmoji(entry.emotion),
                                style: const TextStyle(fontSize: 40),
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            
            // Заметка (если есть)
            if (entry.note?.isNotEmpty ?? false)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.note ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              )
            else if (entry.imagePath.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    _getEmotionName(entry.emotion),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getEmotionColor(entry.emotion),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PhotoMood'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.pushNamed(context, '/statistics');
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Календарь с фиксированной высотой
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55, // 55% экрана
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedDay, day);
                        },
                        onDaySelected: (selectedDay, focusedDay) async {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                          
                          final entry = await DatabaseService()
                            .getEntryForDate(selectedDay);
                            
                          if (entry != null && mounted) {
                            Navigator.pushNamed(
                              context,
                              '/day',
                              arguments: {'entry': entry},
                            );
                          } else if (mounted) {
                            Navigator.pushNamed(
                              context,
                              '/add',
                              arguments: selectedDay,
                            );
                          }
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                          _loadEntries();
                        },
                        calendarFormat: _calendarFormat,
                        onFormatChanged: (format) {
                          setState(() => _calendarFormat = format);
                        },
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          markersAlignment: Alignment.bottomCenter,
                          markersMaxCount: 1,
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false, // Убираем кнопку формата
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          leftChevronIcon: Icon(Icons.chevron_left, size: 24),
                          rightChevronIcon: Icon(Icons.chevron_right, size: 24),
                          headerPadding: EdgeInsets.symmetric(vertical: 8),
                          leftChevronMargin: EdgeInsets.only(left: 16),
                          rightChevronMargin: EdgeInsets.only(right: 16),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          weekendStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            return _buildDayContent(day, []);
                          },
                          todayBuilder: (context, day, focusedDay) {
                            return _buildDayContent(day, []);
                          },
                          selectedBuilder: (context, day, focusedDay) {
                            return _buildDayContent(day, []);
                          },
                        ),
                      ),
                    ),
                  ),
                  
                  // Разделитель
                  Container(
                    height: 1,
                    color: Colors.grey[200],
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Заголовок для фото и заметок
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Недавние фото и заметки',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_recentPhotoEntries.isNotEmpty)
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Все',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Фото и заметки
                  if (_recentPhotoEntries.isNotEmpty)
                    SizedBox(
                      height: 160, // Фиксированная высота для горизонтального списка
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentPhotoEntries.length,
                        itemBuilder: (context, index) {
                          return _buildPhotoNoteItem(_recentPhotoEntries[index], index);
                        },
                      ),
                    )
                  else
                    Container(
                      height: 140,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library,
                              size: 50,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Пока нет фото и заметок',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Кнопка добавления записи
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/add',
                          arguments: DateTime.now(),
                        );
                      },
                      icon: const Icon(Icons.add_a_photo, size: 20),
                      label: const Text(
                        'Добавить запись на сегодня',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20), // Отступ снизу
                ],
              ),
            ),
    );
  }
}