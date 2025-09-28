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
  List<StoryItem> _searchResults = [];
  bool _isSearch = false;
  bool _loading = false;
  String? _error;
  String? _searchError;

  List<StoryItem> get stories => _stories;
  List<StoryItem> get searchResults => _searchResults;
  bool get isLoading => _loading;
  bool get isSearch => _isSearch;
  String? get error => _error;
  String? get searchError => _searchError;

  void attachRepo(StoryRepository repo) {
    _repo = repo;
  }

  /// Load the list from SQLite and notify listeners.
  Future<void> loadStories() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _repo
          .fetchStories(); // SELECT from v_story_with_counts
      _stories = rows.map((e) => StoryItem.fromMap(e)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Public alias you can call after importing JSON to refresh the Home grid.
  Future<void> refresh() => loadStories();

  Future<List<PageItem>> getPages(int storyId) async {
    final rows = await _repo.fetchPages(storyId);
    return rows.map(PageItem.fromMap).toList();
  }

  Future<void> setSearchMode() async {
    _isSearch = !_isSearch;
    if(!_isSearch) {
      _searchResults = [];
      _searchError = null;
    }
    notifyListeners();
  }

  Future<void> search(String query) async {
    try {
      final rows = await _repo.searchStories(query);
      _searchResults = rows.map((e) => StoryItem.fromMap(e)).toList();
      notifyListeners();
    } catch (e) {
      _searchError = e.toString();
    } finally {
      notifyListeners();
    }
  }
}
