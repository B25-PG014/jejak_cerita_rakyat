import 'package:flutter/material.dart';
import 'package:jejak_cerita_rakyat/features/reader/reader_screen.dart';
import 'package:jejak_cerita_rakyat/providers/story_provider.dart';
import 'package:jejak_cerita_rakyat/providers/tts_provider.dart';
import 'package:provider/provider.dart';

class DetailScreen extends StatelessWidget {
  final StoryItem data;
  const DetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    width: 5,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Stack(
                  children: [
                    // ✅ flexible height + fitHeight
                    Image.asset(
                      data.coverAsset.isNotEmpty == true
                          ? data.coverAsset
                          : "assets/images/placeholder.png",
                      fit: BoxFit.fitHeight,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image,
                            size: 300,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    width: 5,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Jumlah Halaman: ${data.pageCount}",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ReaderScreen(id: data.id),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Icon(Icons.menu_book_sharp),
                              SizedBox(width: 5),
                              Text(
                                "Mulai Membaca",
                                style: Theme.of(context).textTheme.bodySmall!
                                    .copyWith(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                        Consumer<TtsProvider>(
                          builder: (context, value, child) {
                            return ElevatedButton(
                              onPressed: () {
                                if (value.speaking) {
                                  value.stop();
                                } else {
                                  value.speak(data.synopsis!);
                                }
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    value.speaking
                                        ? Icons.stop
                                        : Icons.play_arrow,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    value.speaking
                                        ? "Berhenti Dengarkan"
                                        : "Dengarkan Narasi",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                    softWrap: true,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          width: 1,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Synopsis:",
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          SizedBox(height: 8),
                          Text(
                            data.synopsis!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
