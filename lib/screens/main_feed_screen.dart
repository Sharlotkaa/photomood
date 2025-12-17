import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/mood_entry.dart';
import '../services/database_service.dart';
import '../services/answers_service.dart';
import '../data/daily_questions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainFeedScreen extends StatefulWidget {
  const MainFeedScreen({super.key});

  @override
  _MainFeedScreenState createState() => _MainFeedScreenState();
}

class _MainFeedScreenState extends State<MainFeedScreen> {
  List<dynamic> _allItems = [];
  bool _isLoading = true;
  String _dailyQuestion = '';
  bool _hasTodayEntry = false;
  
  // Для пагинации
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _currentPage = 0;
  final int _pageSize = 10;
  bool _hasMoreData = true;
  
  static final List<String> _questionLibrary = dailyQuestions;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkAndUpdateDailyQuestion();
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore && _hasMoreData) {
        _loadMoreData();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkAndUpdateDailyQuestion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';
      
      final lastDateKey = prefs.getString('last_question_date');
      final savedQuestion = prefs.getString('daily_question');
      
      // Если сегодня уже показывали вопрос
      if (lastDateKey == todayKey && savedQuestion != null) {
        setState(() {
          _dailyQuestion = savedQuestion;
        });
        print('[MainFeed] Загружен сохраненный вопрос дня');
        return;
      }
      
      // Если новый день или нет сохраненного вопроса
      _generateDailyQuestion();
      
      // Сохраняем новый вопрос и дату
      await prefs.setString('last_question_date', todayKey);
      await prefs.setString('daily_question', _dailyQuestion);
      
      print('[MainFeed] Сгенерирован новый вопрос дня');
      
    } catch (e) {
      print('Ошибка при проверке вопроса дня: $e');
      _generateDailyQuestion(); // Резервный вариант
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final entries = await DatabaseService().getAllEntries();
      final todayEntry = await DatabaseService().getEntryForDate(DateTime.now());
      
      final answersData = await AnswersService().getAnswers();
      
      final allItems = <dynamic>[];
      allItems.addAll(entries);
      
      for (var answer in answersData) {
        allItems.add({
          'type': 'answer',
          'date': DateTime.parse(answer['date']!),
          'question': answer['question']!,
          'answer': answer['answer']!,
        });
      }
      
      allItems.sort((a, b) {
        DateTime dateA = a is MoodEntry ? a.date : a['date'];
        DateTime dateB = b is MoodEntry ? b.date : b['date'];
        return dateB.compareTo(dateA);
      });
      
      setState(() {
        _allItems = allItems.take(_pageSize).toList();
        _hasTodayEntry = todayEntry != null;
        _isLoading = false;
        _currentPage = 1;
        _hasMoreData = allItems.length > _pageSize;
      });
    } catch (e) {
      print('Ошибка загрузки: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      
      final entries = await DatabaseService().getAllEntries();
      final answersData = await AnswersService().getAnswers();
      
      final allItems = <dynamic>[];
      allItems.addAll(entries);
      
      for (var answer in answersData) {
        allItems.add({
          'type': 'answer',
          'date': DateTime.parse(answer['date']!),
          'question': answer['question']!,
          'answer': answer['answer']!,
        });
      }
      
      allItems.sort((a, b) {
        DateTime dateA = a is MoodEntry ? a.date : a['date'];
        DateTime dateB = b is MoodEntry ? b.date : b['date'];
        return dateB.compareTo(dateA);
      });
      
      final startIndex = _currentPage * _pageSize;
      final endIndex = startIndex + _pageSize;
      
      if (startIndex >= allItems.length) {
        setState(() => _hasMoreData = false);
      } else {
        final newItems = allItems.sublist(
          startIndex, 
          endIndex.clamp(0, allItems.length)
        );
        
        setState(() {
          _allItems.addAll(newItems);
          _currentPage++;
          _hasMoreData = endIndex < allItems.length;
        });
      }
    } catch (e) {
      print('Ошибка загрузки дополнительных данных: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _generateDailyQuestion() {
    if (_questionLibrary.isEmpty) {
      setState(() {
        _dailyQuestion = 'Как прошел ваш день?';
      });
      return;
    }
    
    // Используем день месяца для выбора вопроса
    final dayOfMonth = DateTime.now().day;
    final questionIndex = (dayOfMonth - 1) % _questionLibrary.length;
    
    setState(() {
      _dailyQuestion = _questionLibrary[questionIndex];
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);
    
    if (entryDate == today) return 'Сегодня';
    if (entryDate == today.subtract(const Duration(days: 1))) return 'Вчера';
    
    final difference = today.difference(entryDate).inDays;
    if (difference < 7) return '$difference дней назад';
    
    return '${date.day}.${date.month}.${date.year}';
  }

  Widget _buildTodayPrompt() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withOpacity(0.1),
            Colors.purple.withOpacity(0.05),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _hasTodayEntry ? 'Сегодня уже добавлена запись!' : 'Добавить запись за сегодня?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _hasTodayEntry ? Colors.grey[700] : Colors.blue[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasTodayEntry 
              ? 'Вы можете просмотреть или изменить запись дня'
              : 'Запечатлейте сегодняшний день и своё настроение',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (_hasTodayEntry) {
                  final todayEntry = await DatabaseService().getEntryForDate(DateTime.now());
                  if (todayEntry != null && mounted) {
                    Navigator.pushNamed(
                      context,
                      '/day',
                      arguments: {'entry': todayEntry},
                    );
                  }
                } else {
                  if (mounted) {
                    Navigator.pushNamed(
                      context,
                      '/add',
                      arguments: DateTime.now(),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasTodayEntry ? Colors.grey[300] : Colors.blue,
                foregroundColor: _hasTodayEntry ? Colors.grey[700] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_hasTodayEntry ? 'Посмотреть запись' : 'Добавить запись'),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDailyQuestion() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.withOpacity(0.1),
            Colors.deepOrange.withOpacity(0.05),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: Colors.purple[700]),
              const SizedBox(width: 8),
              Text(
                'Вопрос дня',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _dailyQuestion,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _showAnswerDialog(),
            child: const Text('Ответить на вопрос'),
          ),
        ],
      ),
    );
  }

  void _showAnswerDialog() {
    final answerController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ответ на вопрос дня'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _dailyQuestion,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: answerController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Напишите ваш ответ...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              if (answerController.text.trim().isNotEmpty) {
                await AnswersService().saveAnswer(
                  DateTime.now(),
                  _dailyQuestion,
                  answerController.text.trim(),
                );
                
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ответ сохранен!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  _loadData();
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(MoodEntry entry, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getEmotionColor(entry.emotion).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(
                  _formatDate(entry.date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getEmotionColor(entry.emotion).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _getEmoji(entry.emotion),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getEmotionName(entry.emotion),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getEmotionColor(entry.emotion),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (entry.imagePath.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.pushNamed(
                context,
                '/day',
                arguments: {'entry': entry},
              ),
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[100]),
                child: _buildOptimizedImage(entry),
              ),
            ),

          if (entry.note?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                entry.note!,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptimizedImage(MoodEntry entry) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List?>(
        future: DatabaseService().loadImageBytes(entry.imagePath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: Colors.grey[100],
              child: Center(
                child: Icon(
                  Icons.photo,
                  color: _getEmotionColor(entry.emotion),
                  size: 40,
                ),
              ),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 250,
              cacheWidth: 500,
              cacheHeight: 250,
            );
          }
          return _buildImageError(entry);
        },
      );
    } else {
      try {
        return Image.file(
          File(entry.imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildImageError(entry),
          cacheWidth: 500,
          cacheHeight: 250,
        );
      } catch (e) {
        return _buildImageError(entry);
      }
    }
  }

  Widget _buildImageError(MoodEntry entry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _getEmoji(entry.emotion),
            style: const TextStyle(fontSize: 50),
          ),
          const SizedBox(height: 8),
          const Text(
            'Фото не найдено',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(Map<String, dynamic> answer, int index) {
    final date = answer['date'] as DateTime;
    final question = answer['question'] as String;
    final answerText = answer['answer'] as String;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.question_answer, size: 16, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  _formatDate(date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 14, color: Colors.purple),
                      SizedBox(width: 4),
                      Text(
                        'Ответ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Text(
              question,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: Colors.purple,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              answerText,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion) {
      case 'happy': return Colors.yellow.shade700;
      case 'neutral': return Colors.blueGrey;
      case 'sad': return Colors.blue;
      case 'excited': return Colors.pink;
      case 'angry': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            'Пока нет записей',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавьте первую запись, чтобы начать',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(
              context,
              '/add',
              arguments: DateTime.now(),
            ),
            child: const Text('Добавить первую запись'),
          ),
        ],
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
            icon: const Icon(Icons.calendar_today),
            onPressed: () => Navigator.pushNamed(context, '/calendar'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.pushNamed(context, '/statistics'),
          ),
          IconButton(
            icon: const Icon(Icons.question_answer),
            onPressed: () => Navigator.pushNamed(context, '/answers'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) => false,
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildTodayPrompt()),
              SliverToBoxAdapter(child: _buildDailyQuestion()),
              SliverToBoxAdapter(
                child: Container(
                  height: 1,
                  color: Colors.grey[200],
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Text(
                        'Ваши записи',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${_allItems.length} записей',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (_allItems.isEmpty && !_isLoading)
                SliverFillRemaining(child: _buildEmptyState())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index < _allItems.length) {
                        final item = _allItems[index];
                        if (item is MoodEntry) {
                          return _buildEntryCard(item, index);
                        } else if (item is Map<String, dynamic>) {
                          return _buildAnswerCard(item, index);
                        }
                      }
                      
                      if (_isLoadingMore) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        );
                      }
                      
                      if (!_hasMoreData && _allItems.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'Это все записи',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        );
                      }
                      
                      return const SizedBox.shrink();
                    },
                    childCount: _allItems.length + (_hasMoreData ? 1 : 1),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(
          context,
          '/add',
          arguments: DateTime.now(),
        ),
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}