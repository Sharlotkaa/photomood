import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_feed_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/day_screen.dart';
import 'screens/add_edit_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/answers_screen.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'services/notification_service.dart';
import 'screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  
  print('[Main] Инициализируем уведомления...');
  
  // 1. Инициализируем сервис уведомлений
  final notificationService = NotificationService();
  await notificationService.init();
  
  // 2. Даем время на инициализацию
  await Future.delayed(const Duration(milliseconds: 500));
  
  // 3. Запрашиваем разрешения (еще не планируем)
  await notificationService.requestPermissions();
  
  // 4. Даем время на обработку разрешений
  await Future.delayed(const Duration(milliseconds: 300));
  
  // 5. Планируем уведомления
  await notificationService.scheduleDailyReminders();
  // После scheduleDailyReminders();
  await Future.delayed(const Duration(seconds: 3));
  await notificationService.showTestNotification();

  
  print('[Main] Уведомления инициализированы');
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeService(),
      child: const PhotoMoodApp(),
    ),
  );
}
class PhotoMoodApp extends StatelessWidget {
  const PhotoMoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    return MaterialApp(
      title: 'PhotoMood',
      theme: ThemeData.light().copyWith(
        primaryColor: themeService.accentColor,
        colorScheme: ColorScheme.light(
          primary: themeService.accentColor,
          secondary: themeService.accentColor.withOpacity(0.8),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: themeService.accentColor,
        colorScheme: ColorScheme.dark(
          primary: themeService.accentColor,
          secondary: themeService.accentColor.withOpacity(0.8),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          elevation: 1,
        ),
      ),
      themeMode: themeService.themeMode,
      locale: const Locale('ru', 'RU'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      home: FutureBuilder<bool>(
        future: _checkFirstLaunch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          
          return snapshot.data == true 
              ? const OnboardingScreen()
              : FutureBuilder<bool>(
                  future: AuthService().isLoggedIn(),
                  builder: (context, authSnapshot) {
                    if (authSnapshot.connectionState == ConnectionState.waiting) {
                      return const SplashScreen();
                    }
                    return authSnapshot.data == true 
                        ? const MainFeedScreen()
                        : const WelcomeScreen();
                  },
                );
        },
      ),
      
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/feed': (context) => const MainFeedScreen(),
        '/calendar': (context) => const CalendarScreen(),
        '/day': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return DayScreen(entry: args['entry']);
        },
        '/add': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          return AddEditScreen(arguments: args);
        },
        '/statistics': (context) => const StatisticsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/answers': (context) => const AnswersScreen(),
        '/home': (context) => const MainFeedScreen(),
      },
    );

    
  }
  Future<bool> _checkFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('onboarding_completed') ?? false;
  return !isFirstLaunch; // true = показываем onboarding
}
}

// Добавьте этот класс SplashScreen в конец файла (перед закрывающей фигурной скобкой файла)
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_camera,
              size: 80,
              color: Colors.blue,
            ),
            SizedBox(height: 20),
            Text(
              'PhotoMood',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Загрузка...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
