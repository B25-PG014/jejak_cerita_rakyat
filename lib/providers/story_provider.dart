import 'package:flutter/foundation.dart';
import '../data/repositories/story_repository.dart';

/// ====================
/// Data models
/// ====================

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

/// Pin provinsi (untuk agregat & per-story)
class ProvincePin {
  final int id; // province_id (agregat) / id (per-story)
  final String name; // province_name / name
  final double xRel; // 0..1
  final double yRel; // 0..1
  final int storyCount; // agregat: >=1, per-story: 1

  ProvincePin({
    required this.id,
    required this.name,
    required this.xRel,
    required this.yRel,
    required this.storyCount,
  });

  /// Dari view agregat v_province_counts
  factory ProvincePin.fromMap(Map<String, dynamic> m) => ProvincePin(
    id: m['province_id'] as int,
    name: m['province_name'] as String,
    xRel: (m['x_rel'] as num).toDouble(),
    yRel: (m['y_rel'] as num).toDouble(),
    storyCount: (m['story_count'] as num?)?.toInt() ?? 0,
  );

  /// Dari query per-story (SELECT p.id, p.name, p.x_rel, p.y_rel ...)
  factory ProvincePin.fromStoryRow(Map<String, dynamic> r) => ProvincePin(
    id: r['id'] as int,
    name: r['name'] as String,
    xRel: (r['x_rel'] as num?)?.toDouble() ?? .5,
    yRel: (r['y_rel'] as num?)?.toDouble() ?? .5,
    storyCount: 1,
  );
}

/// ====================
/// Provider
/// ====================

class StoryProvider extends ChangeNotifier {
  StoryProvider({required StoryRepository repo}) : _repo = repo;

  StoryRepository _repo;

  // ---- Stories & search ----
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

  /// Refresh semua (cerita + pin agregat). Useful setelah import JSON.
  Future<void> reloadAll() async {
    await Future.wait([loadStories(), loadProvincePins()]);
  }

  /// Load list cerita dari SQLite (v_story_with_counts)
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

  /// Refresh (alias)
  Future<void> refresh() => loadStories();

  Future<List<PageItem>> getPages(int storyId) async {
    final rows = await _repo.fetchPages(storyId);
    return rows.map(PageItem.fromMap).toList();
  }

  Future<void> setSearchMode() async {
    _isSearch = !_isSearch;
    if (!_isSearch) {
      _searchResults = [];
      _searchError = null;
    }
    notifyListeners();
  }

  Future<void> search(String query) async {
    try {
      final rows = await _repo.searchStories(query);
      _searchResults = rows.map((e) => StoryItem.fromMap(e)).toList();
    } catch (e) {
      _searchError = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // ====================
  // ===== FAVORIT =====
  // ====================

  final Set<int> _favoriteIds = <int>{};
  Set<int> get favoriteIds => _favoriteIds;

  bool isFavorite(int id) => _favoriteIds.contains(id);

  void toggleFavorite(int id) {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    notifyListeners();
  }

  // ====================
  // ===== HAPUS CERITA =====
  // ====================

  /// Hapus cerita dari list saat ini.
  /// NOTE: kalau kamu juga simpan di storage/DB, panggil repo delete di sini.
  Future<void> deleteStory(int id) async {
    // Contoh kalau kamu punya endpoint di repository:
    // try { await _repo.deleteStory(id); } catch (_) {}
    _favoriteIds.remove(id); // cabut dari favorit kalau ada
    _stories.removeWhere((s) => s.id == id);
    // kalau kamu juga pakai hasil pencarian:
    _searchResults.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  // ====================
  // Peta / Provinsi
  // ====================

  List<ProvincePin> _pins = [];
  List<ProvincePin> get pins => _pins;

  /// Muat agregat pin dari v_province_counts
  Future<void> loadProvincePins() async {
    final rows = await _repo.fetchProvinceCounts();
    _pins = rows.map((e) => ProvincePin.fromMap(e)).toList();
    notifyListeners();
  }

  /// Pin untuk satu cerita (dipakai di Home - hanya show yang disorot)
  Future<List<ProvincePin>> pinsForStoryId(int storyId) async {
    final rows = await _repo.fetchProvincesForStory(storyId);
    return rows
        .map((r) => ProvincePin.fromStoryRow(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Ambil daftar cerita per provinceId (popup)
  Future<List<StoryItem>> storiesByProvinceId(int provinceId) async {
    final rows = await _repo.fetchStoriesByProvinceId(provinceId);
    return rows.map((e) => StoryItem.fromMap(e)).toList();
  }

  /// Seed mapping (opsional, untuk admin)
  Future<void> mapStoryToProvince({
    required int storyId,
    required int provinceId,
  }) async {
    await _repo.upsertStoryProvince(storyId: storyId, provinceId: provinceId);
    await loadProvincePins();
  }
}
