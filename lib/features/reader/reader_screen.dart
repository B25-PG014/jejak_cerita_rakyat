import 'package:flutter/material.dart';
import 'package:jejak_cerita_rakyat/providers/reader_provider.dart';
import 'package:jejak_cerita_rakyat/providers/tts_provider.dart';
import 'package:provider/provider.dart';

class ReaderScreen extends StatefulWidget {
  final int id;
  const ReaderScreen({super.key, required this.id});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<ReaderProvider>().openStory(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              height: deviceSize.height,
              width: deviceSize.width,
              padding: EdgeInsets.all(8),
              child: Consumer<ReaderProvider>(
                builder: (context, value, child) {
                  if (value.isBusy) {
                    return Center(child: CircularProgressIndicator());
                  } else if (value.pages.isNotEmpty) {
                    return ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      child: Image.asset(
                        value.pages[value.index].imageAsset!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    );
                  } else {
                    return Center(
                      child: Text(
                        "Tidak Ada Halaman di Cerita ini",
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    );
                  }
                },
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton.filled(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.arrow_back),
                      ),
                      Container(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton.filled(
                              onPressed: () {
                                Navigator.of(context).pushNamed('/settings');
                              },
                              icon: Icon(Icons.settings),
                            ),
                            Consumer<TtsProvider>(
                              builder: (context, value, child) {
                                return IconButton.filled(
                                  onPressed: () {
                                    if (value.volume <= 0.0) {
                                      value.setVolume(1.0);
                                    } else if (value.volume >= 1.0) {
                                      value.setVolume(0.0);
                                    } else {
                                      value.setVolume(1.0);
                                    }
                                  },
                                  icon: Icon(
                                    value.volume <= 0.0
                                        ? Icons.volume_off
                                        : value.volume >= 1.0
                                        ? Icons.volume_up
                                        : Icons.volume_down,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: deviceSize.width * 0.7,
                  height: deviceSize.height * 0.1,
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(125),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Consumer<ReaderProvider>(
                    builder: (context, value, child) {
                      final story = value.pages[value.index];
                      if (value.isBusy) {
                        return Center(child: CircularProgressIndicator());
                      } else if (value.pages.isNotEmpty) {
                        return Consumer<TtsProvider>(
                          builder: (context, value2, child) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton.outlined(
                                  onPressed: () {
                                    value2.stop();
                                    value.prevPage();
                                  },
                                  iconSize: deviceSize.height * 0.7 * 0.07,
                                  icon: Icon(Icons.skip_previous_rounded),
                                ),
                                IconButton.outlined(
                                  onPressed: () {
                                    if (value2.ready) {
                                      value2.speak(story.textPlain!);
                                    } else {
                                      value2.stop();
                                    } 
                                  },
                                  iconSize: deviceSize.height * 0.7 * 0.07,
                                  icon: Icon(
                                    value2.ready
                                        ? Icons.play_arrow
                                        : Icons.stop,
                                  ),
                                ),
                                IconButton.outlined(
                                  onPressed: () {
                                    value2.stop();
                                    value.nextPage();
                                  },
                                  iconSize: deviceSize.height * 0.7 * 0.07,
                                  icon: Icon(Icons.skip_next_rounded),
                                ),
                              ],
                            );
                          },
                        );
                      } else {
                        return Center(
                          child: Text(
                            "Tidak Ada Halaman di Cerita ini",
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
