import 'package:flutter/material.dart';
import 'package:jejak_cerita_rakyat/features/home/home_screen.dart';
import 'package:jejak_cerita_rakyat/features/settings/setting_screen.dart';
import 'package:jejak_cerita_rakyat/features/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Jejak Cerita Rakyat',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        textTheme: _textTheme(settings),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        textTheme: _textTheme(settings),

      ),
      routes: {
        '/': (ctx) => const SplashScreen(),
        '/home': (ctx) => const HomeScreen(),
        // '/detail': (ctx) => DetailScreen(),
        '/settings': (ctx) => const SettingScreen(),
      },
    );
  }

  TextTheme _textTheme(SettingsProvider s) {
    final base = s.themeMode == ThemeMode.light
        ? Typography.material2021().black
        : Typography.material2021().white;

    return base.copyWith(
      headlineSmall: TextStyle(
        fontFamily: s.fontFamily,
        fontSize: 20 * s.textScale,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        fontFamily: s.fontFamily,
        fontSize: 18 * s.textScale,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        fontFamily: s.fontFamily,
        fontSize: 16 * s.textScale,
      ),
      bodyMedium: TextStyle(
        fontFamily: s.fontFamily,
        fontSize: 14 * s.textScale,
      ),
      labelLarge: TextStyle(
        fontFamily: s.fontFamily,
        fontSize: 14 * s.textScale,
        fontWeight: FontWeight.bold,
      ),
      labelMedium: TextStyle(
        fontFamily: s.fontFamily,
        fontSize: 12 * s.textScale,
      ),
    );
  }

}