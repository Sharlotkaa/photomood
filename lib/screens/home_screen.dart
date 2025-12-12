import 'dart:io';
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

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await DatabaseService().getEntriesForMonth(_focusedDay);
    
    setState(() {
      _entries = {
        for (var entry in entries)
          DateTime(entry.date.year, entry.date.month, entry.date.day): entry
      };
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

  Widget _buildDayContent(DateTime day, List<dynamic> events) {
    final entry = _entries[DateTime(day.year, day.month, day.day)];
    
    return Container(
      margin: const EdgeInsets.all(4),
      child: Column(
        children: [
          Text(
            day.day.toString(),
            style: TextStyle(
              color: day.month == _focusedDay.month 
                ? Colors.black 
                : Colors.grey,
            ),
          ),
          if (entry != null) ...[
            const SizedBox(height: 2),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: ClipOval(
                child: Image.file(
                  File(entry.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(child: Text(_getEmoji(entry.emotion)));
                  },
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(_getEmoji(entry.emotion)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PhotoMood'),
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
      body: Column(
        children: [
          TableCalendar(
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
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                return _buildDayContent(day, []);
              },
              todayBuilder: (context, day, focusedDay) {
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: _buildDayContent(day, []),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/add',
                arguments: DateTime.now(),
              );
            },
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Добавить запись на сегодня'),
          ),
        ],
      ),
    );
  }
}