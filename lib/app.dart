import 'package:flutter/material.dart';
import 'package:jejak_cerita_rakyat/features/home/home_screen.dart';
import 'package:jejak_cerita_rakyat/features/library/library_screen.dart';
import 'package:jejak_cerita_rakyat/features/settings/setting_screen.dart';
import 'package:jejak_cerita_rakyat/features/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'package:jejak_cerita_rakyat/features/reader/reader_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Jejak Cerita Rakyat',
      debugShowCheckedModeBanner: false,
      // ==== Penting: Clamp text scale agar tidak memicu overflow di layout ====
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        // Rentang aman 0.8–1.6; bisa disesuaikan jika perlu
        final clampedScaler = mq.textScaler.clamp(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.6,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: clampedScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
      themeMode: settings.themeMode,
      theme: ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
            ),
            backgroundColor: WidgetStatePropertyAll(Colors.blueAccent.shade400),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
          ),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        textTheme: _textTheme(settings),
        colorScheme: _colorScheme(settings),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: ZoomPageTransitionsBuilder(),
            TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
            ),
            backgroundColor: WidgetStatePropertyAll(Colors.blueAccent.shade400),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
          ),
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        textTheme: _textTheme(settings),
        colorScheme: _colorScheme(settings),
      ),
      routes: {
        '/': (ctx) => const SplashScreen(),
        '/home': (ctx) => const HomeScreen(),
        '/settings': (ctx) => const SettingScreen(),
        '/library': (ctx) => const LibraryScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/reader') {
          final arg = settings.arguments;
          final storyId = (arg is int) ? arg : null;

          if (storyId == null) {
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Reader membutuhkan storyId (int).')),
              ),
              settings: settings,
            );
          }

          return MaterialPageRoute(
            builder: (_) => ReaderScreen(id: storyId),
            settings: settings,
          );
        }

        // kembalikan null agar fallback ke behavior default (atau tambahkan handler lain)
        return null;
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

  ColorScheme _colorScheme(SettingsProvider s) {
    return ColorScheme(
      brightness: s.themeMode == ThemeMode.light
          ? Brightness.light
          : Brightness.dark,
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
