import 'package:flutter/material.dart';
import 'package:jejak_cerita_rakyat/features/library/widgets/library_gridview.dart';
import 'package:jejak_cerita_rakyat/providers/story_provider.dart';
import 'package:provider/provider.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 32),
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
                    IconButton.outlined(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.arrow_back),
                    ),
                    Text(
                      'Library Cerita',
                      style: Theme.of(context).textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    IconButton.outlined(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.search_outlined),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
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
                      mainAxisSpacing: 5,
                      childAspectRatio: 2 / 3,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    itemCount: value.stories.length,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      return LibraryGridview(data: value.stories[index]);
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
