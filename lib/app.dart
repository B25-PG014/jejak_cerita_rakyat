import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/story_provider.dart';
import 'package:jejak_cerita_rakyat/features/tts_demo/tts_demo_screen.dart';

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
        useMaterial3: true,
        textTheme: _textTheme(settings),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        textTheme: _textTheme(settings),
      ),
      home: const _HomeScaffold(),
    );
  }

  TextTheme _textTheme(SettingsProvider s) {
    final base = Typography.material2021().black;
    return base.apply(fontFamily: s.fontFamily, fontSizeFactor: s.textScale);
  }
}

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold();

  @override
  Widget build(BuildContext context) {
    final stories = context.watch<StoryProvider>().stories;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library (Provider demo)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.record_voice_over),
            tooltip: 'TTS Demo',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TtsDemoScreen()));
            },
          ),
        ],
      ),
      body: stories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: stories.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final s = stories[i];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(s.title.isNotEmpty ? s.title[0] : '?'),
                  ),
                  title: Text(s.title),
                  subtitle: Text(s.synopsis ?? ''),
                  trailing: Text('${s.pageCount}p'),
                  onTap: () async {
                    // Minimal demo: open pages count in a dialog
                    final pages = await context.read<StoryProvider>().getPages(
                      s.id,
                    );
                    if (!ctx.mounted) return;
                    showDialog(
                      context: ctx,
                      builder: (_) => AlertDialog(
                        title: Text(s.title),
                        content: Text('Halaman: ${pages.length}'),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
