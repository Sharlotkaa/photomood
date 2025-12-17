class MoodEntry {
  int? id;
  DateTime date;
  String imagePath;
  String emotion;
  String? note;
  String? location; // НОВОЕ
  String? weather;  // НОВОЕ

  MoodEntry({
    this.id,
    required this.date,
    required this.imagePath,
    required this.emotion,
    this.note,
    this.location, // НОВОЕ
    this.weather,  // НОВОЕ
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'imagePath': imagePath,
      'emotion': emotion,
      'note': note,
      'location': location, // НОВОЕ
      'weather': weather,   // НОВОЕ
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'],
      date: DateTime.parse(map['date']),
      imagePath: map['imagePath'],
      emotion: map['emotion'],
      note: map['note'],
      location: map['location'], // НОВОЕ
      weather: map['weather'],   // НОВОЕ
    );
  }
}