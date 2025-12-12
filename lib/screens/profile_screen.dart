import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _email;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final email = await AuthService().getCurrentEmail();
    setState(() => _email = email);
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    try {
      final jsonData = await _prepareExportData();
      final fileName = 'photomood_export_${DateTime.now().millisecondsSinceEpoch}.json';
      
      // Создаем временный файл
      final exportService = ExportService();
      final file = await exportService.createExportFile(jsonData, fileName);
      
      // Делимся файлом
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Информация пользователя
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      child: Icon(Icons.person, size: 40),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _email ?? 'Пользователь',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Настройки
            const Text(
              'Настройки',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Экспорт данных
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Экспорт данных'),
              subtitle: const Text('Скачать все записи в JSON'),
              trailing: _isExporting
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.chevron_right),
              onTap: _isExporting ? null : _exportData,
            ),

            const Divider(),

            // О приложении
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('О приложении'),
              subtitle: const Text('PhotoMood v1.0.0'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'PhotoMood',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2024 PhotoMood\nДневник настроения через фото',
                );
              },
            ),

            const Spacer(),

            // Кнопка выхода
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Выйти'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}