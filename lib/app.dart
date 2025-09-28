import 'package:flutter/material.dart';
import 'package:jejak_cerita_rakyat/features/detail/detail_screen.dart';
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
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            padding: WidgetStatePropertyAll(EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2)),
            backgroundColor: WidgetStatePropertyAll(Colors.blueAccent.shade400),
            foregroundColor: WidgetStatePropertyAll(Colors.white),
          )
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        textTheme: _textTheme(settings),
        colorScheme: _colorScheme(settings)
      ),
      darkTheme: ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            padding: WidgetStatePropertyAll(
              EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
            ),
            backgroundColor: WidgetStatePropertyAll(Colors.blueAccent.shade400),
            foregroundColor: WidgetStatePropertyAll(Colors.white),
          ),
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        textTheme: _textTheme(settings),
        colorScheme: _colorScheme(settings)
      ),
      routes: {
        '/': (ctx) => const SplashScreen(),
        '/home': (ctx) => const HomeScreen(),
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
      headlineMedium: TextStyle(
        fontFamily: s.fontFamily,
        fontSize: 28 * s.textScale,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        fontFamily: s.fontFamily,
        fontSize: 26 * s.textScale,
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

  ColorScheme _colorScheme(SettingsProvider s){
    return ColorScheme(
      brightness: s.themeMode == ThemeMode.light ? Brightness.light : Brightness.dark,
      primary: Colors.redAccent,
      onPrimary: Colors.white,
      secondary: Colors.blueAccent,
      onSecondary: Colors.white,
      tertiary: Colors.amberAccent,
      onTertiary: Colors.black,
      error: Colors.red.shade500,
      onError: Colors.black,
      surface: s.themeMode == ThemeMode.light ? Colors.white : Colors.black,
      onSurface: s.themeMode == ThemeMode.light ? Colors.black : Colors.white,
      outline: s.themeMode == ThemeMode.light ? Colors.black : Colors.white,
      
    );
  }

}
