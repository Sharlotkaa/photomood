import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/theme_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _email;
  bool _isExporting = false;
  bool _isLoading = true;
  int _entriesCount = 0;

  @override
  void initState() {
    super.initState();
    // Загружаем данные сразу после инициализации виджета
    Future.delayed(Duration.zero, _loadUserData);
  }

  Future<void> _loadUserData() async {
    try {
      final email = await AuthService().getCurrentEmail();
      final entries = await DatabaseService().getAllEntries();
      
      setState(() {
        _email = email;
        _entriesCount = entries.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки данных пользователя: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки профиля: $e')),
        );
      }
    }
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    try {
      final jsonData = await _prepareExportData();
      final fileName = 'photomood_export_${DateTime.now().millisecondsSinceEpoch}.json';
      
      final exportService = ExportService();
      final file = await exportService.createExportFile(jsonData, fileName);
      
      await Share.shareXFiles([XFile(file.path)],
        text: 'Экспорт данных PhotoMood',
        subject: 'PhotoMood данные',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<Map<String, dynamic>> _prepareExportData() async {
    final entries = await DatabaseService().getAllEntries();
    final userData = {
      'email': _email,
      'export_date': DateTime.now().toIso8601String(),
      'total_entries': entries.length,
    };

    final entriesData = entries.map((entry) => entry.toMap()).toList();

    return {
      'user': userData,
      'entries': entriesData,
    };
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти?'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService().logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context, 
          '/welcome', 
          (route) => false
        );
      }
    }
  }

  Widget _buildThemeSettings(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.red,
      Colors.teal,
      Colors.indigo,
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Внешний вид',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Тема
                Row(
                  children: [
                    const Icon(Icons.color_lens, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Тема',
                      style: TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    DropdownButton<ThemeMode>(
                      value: themeService.themeMode,
                      onChanged: (ThemeMode? newValue) {
                        if (newValue != null) {
                          themeService.setThemeMode(newValue);
                        }
                      },
                      items: ThemeMode.values.map((ThemeMode mode) {
                        return DropdownMenuItem<ThemeMode>(
                          value: mode,
                          child: Text(_getThemeModeName(mode)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Акцентный цвет
                Row(
                  children: [
                    const Icon(Icons.palette, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Акцентный цвет',
                      style: TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        itemCount: colors.length,
                        itemBuilder: (context, index) {
                          final color = colors[index];
                          return GestureDetector(
                            onTap: () {
                              themeService.setAccentColor(color);
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: themeService.accentColor == color 
                                      ? Colors.black 
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Системная';
      case ThemeMode.light:
        return 'Светлая';
      case ThemeMode.dark:
        return 'Темная';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Информация пользователя
                    Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.blue,
                              child: Icon(Icons.person, size: 40, color: Colors.white),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _email ?? 'Пользователь',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Записей: $_entriesCount',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Настройки темы
                    _buildThemeSettings(context),

                    const SizedBox(height: 20),

                    // Функции приложения
                    const Text(
                      'Функции',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Экспорт данных
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.file_download),
                        title: const Text('Экспорт данных'),
                        subtitle: const Text('Скачать все записи в JSON'),
                        trailing: _isExporting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _isExporting ? null : _exportData,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Ответы на вопросы дня
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.question_answer),
                        title: const Text('Мои ответы'),
                        subtitle: const Text('История ответов на вопросы дня'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pushNamed(context, '/answers');
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // О приложении
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info),
                        title: const Text('О приложении'),
                        subtitle: const Text('PhotoMood v1.0.0'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'PhotoMood',
                            applicationVersion: '1.0.0',
                            applicationLegalese: '© 2024 PhotoMood\nДневник настроения через фото',
                            children: [
                              const SizedBox(height: 20),
                              const Text(
                                'PhotoMood - это дневник настроения, который помогает отслеживать эмоции через фотографии и заметки.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Кнопка выхода
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Выйти из аккаунта'),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}