import 'package:flutter/foundation.dart';
import '../data/repositories/story_repository.dart';

class StoryItem {
  final int id;
  final String slug;
  final String title;
  final String? synopsis;
  final String coverAsset;
  final int pageCount;

  StoryItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.synopsis,
    required this.coverAsset,
    required this.pageCount,
  });

  factory StoryItem.fromMap(Map<String, dynamic> m) => StoryItem(
    id: m['id'] as int,
    slug: m['slug'] as String,
    title: m['title'] as String,
    synopsis: m['synopsis'] as String?,
    coverAsset: m['cover_asset'] as String,
    pageCount: (m['page_count'] as num?)?.toInt() ?? 0,
  );
}

class PageItem {
  final int id;
  final int pageNo;
  final String? textPlain;
  final String? imageAsset;

  PageItem({
    required this.id,
    required this.pageNo,
    this.textPlain,
    this.imageAsset,
  });

  factory PageItem.fromMap(Map<String, dynamic> m) => PageItem(
    id: m['id'] as int,
    pageNo: (m['page_no'] as num).toInt(),
    textPlain: m['text_plain'] as String?,
    imageAsset: m['image_asset'] as String?,
  );
}

class StoryProvider extends ChangeNotifier {
  StoryProvider({required StoryRepository repo}) : _repo = repo;

  StoryRepository _repo;
  List<StoryItem> _stories = [];
  bool _loading = false;
  String? _error;

  List<StoryItem> get stories => _stories;
  bool get isLoading => _loading;
  String? get error => _error;

  void attachRepo(StoryRepository repo) {
    _repo = repo;
  }

  Future<void> loadStories() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _repo.fetchStories();
      _stories = rows.map((e) => StoryItem.fromMap(e)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<PageItem>> getPages(int storyId) async {
    final rows = await _repo.fetchPages(storyId);
    return rows.map(PageItem.fromMap).toList();
  }

  Future<List<StoryItem>> search(String query) async {
    final rows = await _repo.searchStories(query);
    return rows
        .map(
          (e) => StoryItem(
            id: e['id'] as int,
            slug: e['slug']?.toString() ?? '',
            title: e['title']?.toString() ?? '',
            synopsis: e['synopsis']?.toString(),
            coverAsset: e['cover_asset']?.toString() ?? '',
            pageCount: (e['page_count'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }
}
