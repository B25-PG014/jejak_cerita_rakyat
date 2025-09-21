import 'package:flutter/material.dart';
import 'package:jejak_cerita_rakyat/features/home/widget/home_gridview_item.dart';
import 'package:jejak_cerita_rakyat/providers/story_provider.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: EdgeInsets.only(right: 16, left: 16, top: 32),
        child: SingleChildScrollView(
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
                          onPressed: () {},
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
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: value.stories.length,
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
      ),
    );
  }
}
