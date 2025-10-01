import 'package:flutter/material.dart';
import 'package:jejak_cerita_rakyat/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:jejak_cerita_rakyat/features/admin/admin_upload_page.dart';
import 'package:jejak_cerita_rakyat/features/tts_demo/tts_demo_screen.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    List<String> listFont = ['Atkinson', 'OpenDyslexic'];
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.only(
                  right: 16,
                  left: 16,
                  top: MediaQuery.of(context).size.height * 0.02,
                ),
                height: MediaQuery.of(context).size.height * 0.12,
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.arrow_back),
                    ),
                    Text(
                      'Pengaturan',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.file_upload_outlined),
                      tooltip: 'Upload Data Cerita (JSON)',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminUploadPage(),
                        ),
                      ),
                    ),
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
              ),
              SizedBox(height: 30),
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                          width: 3,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -10,
                            left: 12,
                            child: Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Text(
                                "Tampilan",
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Mode Gelap
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Mode Gelap",
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium!
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Switch(
                                      value:
                                          settings.themeMode == ThemeMode.dark ? true : false,
                                      onChanged: (value) {
                                        settings.setThemeMode(
                                          value
                                              ? ThemeMode.dark
                                              : ThemeMode.light,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Jenis Huruf
                                Text(
                                  "Jenis Huruf",
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium!
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        int index = listFont.indexOf(
                                          settings.fontFamily,
                                        );
                                        index -= 1;
                                        if (index < 0)
                                          index = listFont.length - 1;
                                        settings.setFontFamily(listFont[index]);
                                      },
                                      icon: const Icon(Icons.arrow_back_ios),
                                    ),
                                    Text(
                                      settings.fontFamily,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        int index = listFont.indexOf(
                                          settings.fontFamily,
                                        );
                                        index += 1;
                                        if (index >= listFont.length) index = 0;
                                        settings.setFontFamily(listFont[index]);
                                      },
                                      icon: const Icon(Icons.arrow_forward_ios),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Skala Huruf
                                Text(
                                  "Skala Huruf",
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium!
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: () {
                                        double newValue =
                                            (settings.textScale - 0.1).clamp(
                                              0.8,
                                              1.6,
                                            );
                                        settings.setTextScale(
                                          double.parse(
                                            newValue.toStringAsFixed(1),
                                          ),
                                        );
                                      },
                                    ),
                                    Text(
                                      settings.textScale.toStringAsFixed(1),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () {
                                        double newValue =
                                            (settings.textScale + 0.1).clamp(
                                              0.8,
                                              1.6,
                                            );
                                        settings.setTextScale(
                                          double.parse(
                                            newValue.toStringAsFixed(1),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
