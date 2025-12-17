import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/mood_entry.dart';
import '../services/database_service.dart';
import '../services/location_weather_service.dart';

class AddEditScreen extends StatefulWidget {
  final dynamic arguments;

  const AddEditScreen({super.key, required this.arguments});

  @override
  _AddEditScreenState createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  Uint8List? _imageBytes;
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
        if (kIsWeb) {
          // На вебе получаем bytes
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _imageBytes = bytes;
            _image = null;
          });
        } else {
          // На мобильных/десктоп
          setState(() {
            _image = File(pickedFile.path);
            _imageBytes = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }
 Future<void> _saveEntry() async {
  // Проверяем, есть ли новое изображение
    final hasNewImage = _image != null || _imageBytes != null;
    
    if (!_isEditMode && !hasNewImage) {
      // Для новой записи изображение обязательно
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите фото')),
      );
      return;
    }

    // Для Web создаем уникальный ключ для изображения
    String? imagePath;
    
    if (kIsWeb && _imageBytes != null) {
      // На вебе сохраняем bytes в локальное хранилище
      imagePath = 'web_image_${DateTime.now().millisecondsSinceEpoch}';
      await _saveImageForWeb(imagePath, _imageBytes!);
    } else if (_image != null) {
      // На других платформах используем путь к файлу
      imagePath = _image!.path;
    } else if (_isEditMode && _existingEntry?.imagePath != null) {
      // В режиме редактирования, если изображение не меняли, используем старое
      imagePath = _existingEntry!.imagePath;
    }

    // ==== ВСТАВЬТЕ ЭТОТ БЛОК ЗДЕСЬ (НАЧАЛО) ====
    // Получаем местоположение и погоду
    String? location;
    String? weather;
    
    try {
      final locationData = await LocationWeatherService.getCurrentLocation();
      if (locationData.containsKey('location') && !locationData.containsKey('error')) {
        location = locationData['location'];
        
        // Получаем погоду если есть координаты
        if (locationData.containsKey('lat') && locationData.containsKey('lon')) {
          final lat = double.parse(locationData['lat']!);
          final lon = double.parse(locationData['lon']!);
          weather = await LocationWeatherService.getWeather(lat, lon);
        }
      }
    } catch (e) {
      print('Ошибка получения геолокации: $e');
    }
    // ==== ВСТАВЬТЕ ЭТОТ БЛОК ЗДЕСЬ (КОНЕЦ) ====

    print('📍 Сохраняем локацию: $location');
    print('☁️ Сохраняем погоду: $weather');

    // Создаем запись
    final entry = MoodEntry(
      id: _existingEntry?.id,
      date: _selectedDate ?? _existingEntry?.date ?? DateTime.now(),
      imagePath: imagePath ?? '',
      emotion: _selectedEmotion,
      note: _noteController.text.trim(),
      location: location,  // ← передаем местоположение
      weather: weather,    // ← передаем погоду
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


  // Метод для сохранения изображения на Web
  Future<void> _saveImageForWeb(String key, Uint8List bytes) async {
    try {
      // Используем shared_preferences для простоты
      // Установите пакет: flutter pub add shared_preferences
      // import 'package:shared_preferences/shared_preferences.dart';
      
      // final prefs = await SharedPreferences.getInstance();
      // final base64String = base64.encode(bytes);
      // await prefs.setString('image_$key', base64String);
      
      // ИЛИ используйте localstorage:
      // Установите пакет: flutter pub add localstorage
      // import 'package:localstorage/localstorage.dart';
      // final storage = LocalStorage('mood_images');
      // await storage.setItem(key, base64.encode(bytes));
      
      print('Изображение сохранено с ключом: $key');
    } catch (e) {
      print('Ошибка сохранения изображения на Web: $e');
    }
  }

  // Метод для загрузки изображения на Web
  Future<Uint8List?> _loadImageForWeb(String key) async {
    try {
      // Аналогично _saveImageForWeb, загрузите из shared_preferences или localstorage
      // final prefs = await SharedPreferences.getInstance();
      // final base64String = prefs.getString('image_$key');
      // if (base64String != null) {
      //   return base64.decode(base64String);
      // }
      return null;
    } catch (e) {
      print('Ошибка загрузки изображения на Web: $e');
      return null;
    }
  }

  Widget _buildImagePreview() {
    if (_imageBytes != null) {
      // Для Web (и мобильных, если используем bytes)
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.memory(
          _imageBytes!,
          fit: BoxFit.cover,
        ),
      );
    } else if (_image != null) {
      // Для мобильных/десктоп
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.file(
          _image!,
          fit: BoxFit.cover,
        ),
      );
    } else if (_isEditMode && _existingEntry?.imagePath != null) {
      // Показываем, что изображение уже есть (для режима редактирования)
      return FutureBuilder<Uint8List?>(
        future: kIsWeb 
            ? _loadImageForWeb(_existingEntry!.imagePath)
            : null,
        builder: (context, snapshot) {
          if (kIsWeb && snapshot.hasData) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
              ),
            );
          } else if (!kIsWeb) {
            // Для мобильных показываем placeholder, т.к. изображение уже в базе
            return _buildEditModePlaceholder();
          }
          return _buildPlaceholder();
        },
      );
    }
    
    return _buildPlaceholder();
  }

  Widget _buildEditModePlaceholder() {
    return Stack(
      children: [
        Container(
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.photo, size: 60, color: Colors.grey),
          ),
        ),
        Container(
          color: Colors.black54,
          child: const Center(
            child: Text(
              'Изображение сохранено\nНажмите, чтобы изменить',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 60, color: Colors.grey),
        SizedBox(height: 10),
        Text('Нажмите, чтобы добавить фото'),
      ],
    );
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
                child: _buildImagePreview(),
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