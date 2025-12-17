import 'package:shared_preferences/shared_preferences.dart';

class AnswersService {
  static final AnswersService _instance = AnswersService._internal();
  factory AnswersService() => _instance;
  AnswersService._internal();

  static const String _answersKey = 'daily_answers';

  Future<void> saveAnswer(DateTime date, String question, String answer) async {
    final prefs = await SharedPreferences.getInstance();
    final answers = await getAnswers();
    
    answers.add({
      'date': date.toIso8601String(),
      'question': question,
      'answer': answer,
    });
    
    await prefs.setStringList(_answersKey, 
      answers.map((a) => 
        '${a['date']}|${a['question']}|${a['answer']}'
      ).toList()
    );
  }

  Future<List<Map<String, String>>> getAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final answersData = prefs.getStringList(_answersKey) ?? [];
    
    return answersData.map((entry) {
      final parts = entry.split('|');
      return {
        'date': parts[0],
        'question': parts[1],
        'answer': parts[2],
      };
    }).toList();
  }

  Future<void> clearAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_answersKey);
  }
}