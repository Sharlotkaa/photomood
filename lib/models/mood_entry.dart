class MoodEntry {
  int? id;
  DateTime date;
  String imagePath;
  String emotion;
  String? note;

  MoodEntry({
    this.id,
    required this.date,
    required this.imagePath,
    required this.emotion,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'imagePath': imagePath,
      'emotion': emotion,
      'note': note,
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'],
      date: DateTime.parse(map['date']),
      imagePath: map['imagePath'],
      emotion: map['emotion'],
      note: map['note'],
    );
  }
}