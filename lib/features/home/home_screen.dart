import 'package:flutter/material.dart';
import 'package:jejak_cerita_rakyat/features/home/widget/home_gridview_item.dart';
import 'package:jejak_cerita_rakyat/providers/story_provider.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: EdgeInsets.only(right: 16, left: 16, top: 32),
        child: Stack(
          alignment: AlignmentGeometry.topCenter,
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                        width: 5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Jejak Cerita',
                              style: Theme.of(context).textTheme.headlineSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Rakyat',
                              style: Theme.of(context).textTheme.headlineSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton.outlined(
                              onPressed: () {
                                Navigator.of(context).pushNamed('/settings');
                              },
                              icon: Icon(Icons.settings_outlined),
                            ),
                            IconButton.outlined(
                              onPressed: () {
                                context.read<StoryProvider>().setSearchMode();
                              },
                              icon: Icon(Icons.search_outlined),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Koleksi Cerita Ralayat",
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/library');
                      },
                      child: Text(
                        'See All...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  Consumer<StoryProvider>(
                    builder: (context, value, child) {
                      if (value.isLoading) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (value.error != null) {
                        // Tampilkan snackbar
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: ${value.error}")),
                          );
                        });
                      }
                      if (value.stories.isEmpty) {
                        return Center(
                          child: Text("Sayang Sekali Tidak Ada Cerita Rakyat"),
                        );
                      }
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 5,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2 / 3,
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        itemCount: value.stories.take(6).length,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          return HomeGridviewItem(data: value.stories[index]);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: Consumer<StoryProvider>(
                builder: (context, value, child) {
                  if (value.isSearch) {
                    return Container(
                      height: double.infinity,
                      color: Theme.of(context).cardColor.withAlpha(125),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.only(
                            top: 16,
                            left: 16,
                            right: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: 'Cari Cerita',
                                        border: OutlineInputBorder(),
                                      ),
                                      onSubmitted: (query) {
                                        value.search(query);
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      value.setSearchMode();
                                    },
                                    icon: Icon(Icons.close),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Divider(),
                              if (value.searchError != null)
                                Text(
                                  "Error: ${value.searchError}",
                                  style: TextStyle(color: Colors.red),
                                ),
                              if (value.searchResults.isNotEmpty)
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.6,
                                  child: ListView.builder(
                                    itemCount: value.searchResults.length,
                                    itemBuilder: (context, index) {
                                      final story = value.searchResults[index];
                                      return ListTile(
                                        title: Text(story.title),
                                        onTap: () {
                                          Navigator.of(context).pushNamed(
                                            '/story',
                                            arguments: story.id,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
