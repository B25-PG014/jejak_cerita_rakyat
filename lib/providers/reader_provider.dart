import 'package:flutter/foundation.dart';
import '../data/repositories/story_repository.dart';
import 'story_provider.dart';

class ReaderProvider extends ChangeNotifier {
  final StoryRepository _repo;

  ReaderProvider({required StoryRepository repo}) : _repo = repo;

  int? _storyId;
  List<PageItem> _pages = [];
  int _index = 0;
  bool _busy = false;

  int? get storyId => _storyId;
  List<PageItem> get pages => _pages;
  int get index => _index;
  bool get isBusy => _busy;

  Future<void> openStory(int storyId) async {
    _busy = true;
    notifyListeners();
    try {
      _storyId = storyId;
      final rows = await _repo.fetchPages(storyId);
      _pages = rows.map(PageItem.fromMap).toList();
      _index = 0;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void nextPage() {
    if (_index + 1 < _pages.length) {
      _index++;
      notifyListeners();
    }
  }

  void prevPage() {
    if (_index > 0) {
      _index--;
      notifyListeners();
    }
  }
}
