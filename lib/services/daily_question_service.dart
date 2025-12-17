import 'package:shared_preferences/shared_preferences.dart';

class DailyQuestionService {
  static final DailyQuestionService _instance = DailyQuestionService._internal();
  factory DailyQuestionService() => _instance;
  DailyQuestionService._internal();

  static final List<String> _questions = [
    'Какой был самый лучший день в твоем детстве?',
    'Как ты понимаешь, что тебе плохо?',
    'Что делает тебя по-настоящему счастливым?',
    'О чем ты мечтал в детстве?',
    'Что бы ты сказал себе 5 лет назад?',
    'Какой комплимент ты бы хотел услышать?',
    'Что ты больше всего ценишь в друзьях?',
    'Чего ты боишься в будущем?',
    'Что тебя вдохновляет?',
    'Какой момент из прошлого ты хотел бы пережить снова?',
    'Что значит для тебя успех?',
    'Что тебя успокаивает в трудные моменты?',
    'Какой совет ты дал бы своему ребенку?',
    'Что ты узнал о себе за последний год?',
    'За что ты благодарен в своей жизни?',
  ];

  Future<String> getTodaysQuestion() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final lastQuestionDate = prefs.getString('last_question_date');
    final lastQuestionIndex = prefs.getInt('last_question_index') ?? 0;
    
    // Если сегодня уже показывали вопрос
    if (lastQuestionDate == _formatDate(today)) {
      return _questions[lastQuestionIndex];
    }
    
    // Генерируем новый вопрос
    final newIndex = (today.day - 1) % _questions.length;
    
    await prefs.setString('last_question_date', _formatDate(today));
    await prefs.setInt('last_question_index', newIndex);
    
    return _questions[newIndex];
  }

  Future<void> saveAnswer(String question, String answer) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _formatDate(DateTime.now());
    
    await prefs.setString('answer_$today', answer);
    await prefs.setString('question_$today', question);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}