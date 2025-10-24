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

  // --- NEW / PATCH: base folder untuk gambar per-cerita
  // contoh: "assets/stories/malin-kundang/"
  String _storyDir = 'assets/stories/';
  String get storyDir => _storyDir;

  int? get storyId => _storyId;
  List<PageItem> get pages => _pages;
  int get index => _index;
  bool get isBusy => _busy;

  // --- Helpers ----------------------------------------------------------------

  /// Normalisasi path asset:
  /// - Pastikan diawali 'assets/' agar Image.asset bisa menemukan file
  /// - Jika path relatif (mis. 'stories/..' atau hanya 'p1.png'), prefiks sesuai folder default
  String? _normalizeAssetPath(dynamic raw) {
    if (raw == null) return null;
    String p = raw.toString().trim();
    if (p.isEmpty) return null;

    // URL? langsung pakai
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    // Sudah absolut dalam assets?
    if (p.startsWith('assets/')) return p;

    // Mulai dengan 'stories/' -> jadikan absolut ke assets
    if (p.startsWith('stories/')) return 'assets/$p';

    // Fallback: path relatif -> prefix pakai base dir cerita yang sudah dihitung
    final base = _storyDir.endsWith('/') ? _storyDir : '$_storyDir/';
    return '$base$p';
  }

  /// Normalisasi satu row dari DB sebelum di-parse ke PageItem:
  /// - Gabungkan varian kunci gambar: image_asset / image / imagePath / image_url
  /// - Set semua alias agar PageItem.fromMap apapun tetap dapat (snake_case & camelCase)
  /// - Pastikan ada textPlain (dari text_plain / text / paragraphs)
  Map<String, dynamic> _normalizePageRow(Map<String, dynamic> row) {
    final m = Map<String, dynamic>.from(row);

    // ---- IMAGE ----
    final rawImg =
        m['image_asset'] ??
        m['image'] ??
        m['imagePath'] ??
        m['image_url'] ??
        m['imageURL'];
    final normalized = _normalizeAssetPath(rawImg);

    // Set semua alias agar model yang berbeda tetap dapat:
    if (normalized != null) {
      m['image_asset'] = normalized; // snake_case
      m['image'] = normalized; // alias umum
      m['imageAsset'] = normalized; // camelCase (kalau model pakai ini)
    }

    // ---- TEXT ----
    // text_plain > text > paragraphs(join)
    if (m['text_plain'] == null ||
        (m['text_plain'] as String?)?.isEmpty == true) {
      if (m['text'] != null) {
        m['text_plain'] = m['text'];
      } else if (m['paragraphs'] is List) {
        final paras = (m['paragraphs'] as List).whereType<String>().join('\n');
        if (paras.isNotEmpty) m['text_plain'] = paras;
      }
    }
    // Alias camelCase untuk beberapa model
    m['textPlain'] ??= m['text_plain'];

    // ---- PAGE NUMBER ----
    final pn = m['page_no'];
    if (pn is String) {
      final n = int.tryParse(pn);
      if (n != null) m['page_no'] = n;
    }
    // camelCase alias
    m['pageNo'] ??= m['page_no'];

    return m;
  }

  // --- NEW / PATCH: util kecil untuk slugify judul jika slug tidak ada -------
  String _slugify(String? title) {
    final t = (title ?? '').toLowerCase().trim();
    if (t.isEmpty) return '';
    // ganti spasi & underscore jadi dash, hapus non-alfanumerik (kecuali dash)
    final s1 = t.replaceAll(RegExp(r'[\s_]+'), '-');
    final s2 = s1.replaceAll(RegExp(r'[^a-z0-9\-]+'), '');
    // rapikan dash beruntun
    final s3 = s2.replaceAll(RegExp(r'-{2,}'), '-');
    return s3.trim().replaceAll(RegExp(r'^-+|-+$'), '');
  }

  // --- NEW / PATCH: tentukan _storyDir dari meta stories (cover_asset/slug/title)
  Future<void> _computeStoryDirFromMeta(int storyId) async {
    try {
      final all = await _repo.fetchStories(); // sudah ada di repo-mu
      final meta = all.firstWhere(
        (e) => (e['id'] is int) && (e['id'] as int) == storyId,
        orElse: () => const {},
      );

      String dir = 'assets/stories/';

      // 1) cover_asset → ambil foldernya
      final cover = (meta['cover_asset'] ?? meta['cover'])?.toString() ?? '';
      if (cover.startsWith('assets/stories/')) {
        final i = cover.lastIndexOf('/');
        if (i > 'assets/stories/'.length) {
          dir = cover.substring(0, i + 1); // termasuk trailing slash
          _storyDir = dir;
          return;
        }
      }

      // 2) slug → assets/stories/<slug>/
      final slug = (meta['slug'] ?? '').toString().trim();
      if (slug.isNotEmpty) {
        _storyDir = 'assets/stories/$slug/';
        return;
      }

      // 3) title → slugify
      final title = (meta['title'] ?? '').toString().trim();
      final slugFromTitle = _slugify(title);
      if (slugFromTitle.isNotEmpty) {
        _storyDir = 'assets/stories/$slugFromTitle/';
        return;
      }

      // fallback sudah default 'assets/stories/'
      _storyDir = 'assets/stories/';
    } catch (_) {
      // kalau ada error, jangan ganggu flow
      _storyDir = 'assets/stories/';
    }
  }

  // ----------------------------------------------------------------------------

  Future<void> openStory(int storyId) async {
    _busy = true;
    notifyListeners();
    try {
      _storyId = storyId;

      // --- NEW / PATCH: hitung base-dir berdasar metadata cerita
      await _computeStoryDirFromMeta(storyId);

      final rows = await _repo.fetchPages(storyId);

      // Normalisasi SEMUA baris sebelum ke PageItem
      final normalizedRows = rows
          .map((r) => _normalizePageRow(Map<String, dynamic>.from(r)))
          .toList();

      _pages = normalizedRows.map(PageItem.fromMap).toList();
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
