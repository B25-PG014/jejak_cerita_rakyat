import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/db/app_database.dart';
import 'data/repositories/story_repository.dart';
import 'providers/settings_provider.dart';
import 'providers/story_provider.dart';
import 'providers/reader_provider.dart';
import 'providers/tts_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 250; // default 1000
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20; // ~60MB
  // Ensure DB ready before runApp (not strictly required, but nice to warmup)
  await AppDatabase.instance.database;

  runApp(
    MultiProvider(
      providers: [
        // Low-level singletons/repositories
        Provider<StoryRepository>(
          create: (_) => StoryRepository(AppDatabase.instance),
        ),
        // App-level settings/state
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider()..loadFromPrefs(),
        ),
        // Stories (library/list)
        ChangeNotifierProxyProvider<StoryRepository, StoryProvider>(
          create: (ctx) =>
              StoryProvider(repo: ctx.read<StoryRepository>())..loadStories(),
          update: (ctx, repo, prev) =>
              (prev ?? StoryProvider(repo: repo))..attachRepo(repo),
        ),
        // Reader (depends on Settings for TTS prefs if you integrate later)
        ChangeNotifierProvider<ReaderProvider>(
          create: (ctx) => ReaderProvider(repo: ctx.read<StoryRepository>()),
        ),
        ChangeNotifierProvider<TtsProvider>(create: (_) => TtsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}
