import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/mood_entry.dart';
import '../services/database_service.dart';

class AddEditScreen extends StatefulWidget {
  final dynamic arguments;

  const AddEditScreen({super.key, required this.arguments});

  @override
  _AddEditScreenState createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  String _selectedEmotion = 'happy';
  final _noteController = TextEditingController();
  bool _isEditMode = false;
  MoodEntry? _existingEntry;
  DateTime? _selectedDate;

  final Map<String, String> _emotions = {
    'happy': '😊 Счастливый',
    'excited': '🤩 Восторг',
    'neutral': '😐 Нейтральный',
    'sad': '😔 Грустный',
    'angry': '😠 Злой',
  };

  @override
  void initState() {
    super.initState();
    
    if (widget.arguments is Map) {
      final args = widget.arguments as Map;
      _isEditMode = args['edit'] ?? false;
      _existingEntry = args['entry'];
      _selectedEmotion = _existingEntry?.emotion ?? 'happy';
      _noteController.text = _existingEntry?.note ?? '';
      if (_existingEntry?.imagePath != null) {
        _image = File(_existingEntry!.imagePath);
      }
    } else if (widget.arguments is DateTime) {
      _selectedDate = widget.arguments as DateTime;
    } else {
      _selectedDate = DateTime.now();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() => _image = File(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _saveEntry() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите фото')),
      );
      return;
    }

    final entry = MoodEntry(
      id: _existingEntry?.id,
      date: _selectedDate ?? _existingEntry?.date ?? DateTime.now(),
      imagePath: _image!.path,
      emotion: _selectedEmotion,
      note: _noteController.text.trim(),
    );

    try {
      if (_isEditMode && entry.id != null) {
        await DatabaseService().updateEntry(entry);
      } else {
        await DatabaseService().insertEntry(entry);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Редактировать' : 'Новая запись'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Превью фото
            GestureDetector(
              onTap: () => _showImagePickerDialog(),
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          _image!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo, size: 60, color: Colors.grey),
                          SizedBox(height: 10),
                          Text('Нажмите, чтобы добавить фото'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 30),

            // Выбор эмоции
            const Text(
              'Как вы себя чувствуете?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _emotions.entries.map((emotion) {
                final isSelected = _selectedEmotion == emotion.key;
                return ChoiceChip(
                  label: Text(emotion.value),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedEmotion = emotion.key);
                  },
                  selectedColor: Colors.blue[100],
                );
              }).toList(),
            ),
            const SizedBox(height: 30),

            // Заметка
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Заметка (необязательно)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 30),

            // Кнопки выбора фото
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Сделать фото'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Из галереи'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Кнопка сохранения
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveEntry,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Сделать фото'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Выбрать из галереи'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}