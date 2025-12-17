import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;
  bool _permissionsRequested = false;

  Future<void> init() async {
    try {
      print('[NotificationService] Инициализация...');
      
      if (_isInitialized) {
        print('[NotificationService] Уже инициализирован, пропускаем');
        return;
      }

      // Инициализация часовых поясов
      tz.initializeTimeZones();
      print('[NotificationService] Часовые пояса инициализированы');

      // Настройка канала для Android
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // Настройка для iOS
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      _notificationsPlugin = FlutterLocalNotificationsPlugin();
      
      // Инициализация плагина
      final bool? initialized = await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('[NotificationService] Уведомление нажато: ${response.payload}');
        },
      );

      if (initialized == true) {
        _isInitialized = true;
        print('[NotificationService] Плагин успешно инициализирован');
      } else {
        print('[NotificationService] Ошибка инициализации плагина');
      }

    } catch (e) {
      print('[NotificationService] Критическая ошибка инициализации: $e');
    }
  }

  // 🔹 НОВЫЙ МЕТОД: Запрос разрешений отдельно от инициализации
  Future<bool> requestPermissions() async {
    try {
      print('[NotificationService] Запрашиваем разрешения...');
      
      if (_permissionsRequested) {
        print('[NotificationService] Разрешения уже запрашивались');
        return true;
      }

      // Для Android 13+ (API 33)
      final PermissionStatus status = await Permission.notification.request();
      
      print('[NotificationService] Статус разрешения: $status');
      
      if (status.isGranted) {
        _permissionsRequested = true;
        print('[NotificationService] Разрешение на уведомления получено');
        return true;
      } else if (status.isPermanentlyDenied) {
        print('[NotificationService] Разрешение навсегда отклонено, нужно открыть настройки');
        // Можно предложить пользователю открыть настройки
        // openAppSettings();
      } else {
        print('[NotificationService] Разрешение на уведомления отклонено');
      }
      
      return false;
    } catch (e) {
      print('[NotificationService] Ошибка при запросе разрешений: $e');
      return false;
    }
  }

  // 🔹 НОВЫЙ МЕТОД: Показать тестовое уведомление немедленно
  Future<void> showTestNotification() async {
    try {
      print('[NotificationService] Показываем тестовое уведомление...');
      
      if (!_isInitialized) {
        print('[NotificationService] Плагин не инициализирован');
        return;
      }

      await _notificationsPlugin.show(
        999, // ID для теста
        '✅ PhotoMood - Тест',
        'Уведомления работают корректно!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_mood_channel',
            'Напоминания о записи настроения',
            channelDescription: 'Напоминания сделать запись в дневнике настроения',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
            //sound: RawResourceAndroidNotificationSound('notification'),
            sound: const RawResourceAndroidNotificationSound('slow_spring_board'), // Или любой другой стандартный
            channelShowBadge: true,
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default.wav',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            badgeNumber: 1,
          ),
        ),
        payload: 'test_notification',
      );
      
      print('[NotificationService] ✅ Тестовое уведомление показано');
    } catch (e) {
      print('[NotificationService] Ошибка показа тестового уведомления: $e');
    }
  }

  // 🔹 Основное планирование уведомлений с безопасным режимом
  Future<void> scheduleDailyReminders() async {
    try {
      print('[NotificationService] Начинаем планирование...');
      
      if (!_isInitialized) {
        print('[NotificationService] Плагин не инициализирован, пропускаем');
        return;
      }

      // Отменяем все предыдущие уведомления
      await _cancelAllNotifications();

      // Используем НЕТОЧНЫЙ режим для Android 14 (без ошибок)
      const AndroidScheduleMode scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      
      print('[NotificationService] Используем режим: $scheduleMode');

      // Планируем основные уведомления
      final reminders = [
        {
          'id': 1, 
          'hour': 9, 
          'minute': 0, 
          'title': 'PhotoMood 🌅', 
          'body': 'Доброе утро! Как ваше настроение сегодня? Сделайте запись в дневнике.'
        },
        {
          'id': 2, 
          'hour': 13, 
          'minute': 0, 
          'title': 'PhotoMood ☀️', 
          'body': 'Не забудьте сделать запись в дневнике настроения! Запечатлейте день.'
        },
        {
          'id': 3, 
          'hour': 19, 
          'minute': 0, 
          'title': 'PhotoMood 🌙', 
          'body': 'Завершите день записью в дневнике настроения! Как прошел ваш день?'
        },
      ];

      for (var reminder in reminders) {
        try {
          final scheduledDate = _calculateScheduledTime(
            reminder['hour'] as int, 
            reminder['minute'] as int
          );
          
          await _notificationsPlugin.zonedSchedule(
            reminder['id'] as int,
            reminder['title'] as String,
            reminder['body'] as String,
            scheduledDate,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'daily_mood_channel',
                'Напоминания о записи настроения',
                channelDescription: 'Напоминания сделать запись в дневнике настроения',
                importance: Importance.high,
                priority: Priority.high,
                enableVibration: true,
                playSound: true,
                //sound: RawResourceAndroidNotificationSound('notification'),
                sound: const RawResourceAndroidNotificationSound('slow_spring_board'), // Или любой другой стандартный
                channelShowBadge: true,
              ),
              iOS: DarwinNotificationDetails(
                sound: 'default.wav',
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: scheduleMode,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
          
          print('[NotificationService] Уведомление ${reminder['id']} запланировано на ${scheduledDate.hour}:${scheduledDate.minute}');
          
        } catch (e) {
          print('[NotificationService] Ошибка планирования уведомления ${reminder['id']}: $e');
        }
      }

      print('[NotificationService] ✅ Все уведомления запланированы');
      
    } catch (e) {
      print('[NotificationService] Критическая ошибка при планировании: $e');
    }
  }

  // 🔹 Вспомогательный метод для расчета времени
  tz.TZDateTime _calculateScheduledTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    // Если время уже прошло сегодня, планируем на завтра
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  // 🔹 Отмена всех уведомлений
  Future<void> _cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      print('[NotificationService] Все предыдущие уведомления отменены');
    } catch (e) {
      print('[NotificationService] Ошибка при отмене уведомлений: $e');
    }
  }

  // 🔹 Проверка, включены ли уведомления
  Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) return false;
    
    try {
      final bool? result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      
      return result ?? false;
    } catch (e) {
      print('[NotificationService] Ошибка проверки статуса уведомлений: $e');
      return false;
    }
  }

  // 🔹 Очистка всех уведомлений (для отладки)
  Future<void> clearAllNotifications() async {
    await _cancelAllNotifications();
    print('[NotificationService] Все уведомления очищены');
  }
}