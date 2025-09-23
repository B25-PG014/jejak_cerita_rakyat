import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/db/app_database.dart';

class StoryImportService {
  final _db = AppDatabase.instance;

  /// Import dari file JSON di storage (pakai path).
  /// - Gambar relatif (p1.png) akan dicopy dari folder JSON ke appDocs/stories/<slug>/
  Future<int> importFromJsonFile(
    String jsonFilePath, {
    bool replacePages = true,
  }) async {
    final jsonStr = await File(jsonFilePath).readAsString();
    final Map<String, dynamic> j = jsonDecode(jsonStr);

    final baseDir = p.dirname(jsonFilePath);
    return importFromJsonMap(
      j,
      baseDirForRelativeImages: baseDir,
      assetsMode: false,
      replacePages: replacePages,
    );
  }

  /// Import dari asset JSON (tanpa file picker).
  /// - Gambar relatif (p1.png) akan di-resolve menjadi asset path: <baseDir>/<slug>/p1.png
  ///   (asumsi struktur: assets/stories/<slug>.json dan gambar di assets/stories/<slug>/ )
  Future<int> importFromJsonAsset(
    String assetJsonPath, {
    bool replacePages = true,
  }) async {
    final jsonStr = await rootBundle.loadString(assetJsonPath);
    final Map<String, dynamic> j = jsonDecode(jsonStr);

    final baseDir = p.dirname(assetJsonPath); // e.g. assets/stories
    return importFromJsonMap(
      j,
      baseDirForRelativeImages: baseDir,
      assetsMode: true,
      replacePages: replacePages,
    );
  }

  /// Import dari Map JSON (umum).
  Future<int> importFromJsonMap(
    Map<String, dynamic> j, {
    required String baseDirForRelativeImages,
    required bool assetsMode,
    bool replacePages = true,
  }) async {
    final slug = (j['slug'] as String?)?.trim();
    if (slug == null || slug.isEmpty) {
      throw ArgumentError('Field "slug" wajib ada dan tidak boleh kosong.');
    }

    final resolvedCover = await _resolvePath(
      inputPath: (j['cover'] ?? '').toString(),
      slug: slug,
      baseDir: baseDirForRelativeImages,
      assetsMode: assetsMode,
      pageNo: null,
    );

    final storyMap = {
      'title': j['title'] ?? '',
      'subtitle': j['subtitle'] ?? '',
      'synopsis': j['synopsis'] ?? '',
      'cover_asset': resolvedCover ?? '',
      'age_min': j['age_min'] ?? 6,
      'age_max': j['age_max'],
      'locale': j['locale'] ?? 'id',
      'author': j['author'] ?? '',
      'source': j['source'] ?? '',
    };

    final List pagesRaw = (j['pages'] ?? []) as List;
    pagesRaw.sort((a, b) => (a['page_no'] ?? 0).compareTo(b['page_no'] ?? 0));

    final pages = <Map<String, dynamic>>[];
    for (final raw in pagesRaw) {
      final Map<String, dynamic> pg = Map<String, dynamic>.from(raw as Map);

      final imgResolved = await _resolvePath(
        inputPath: (pg['image'] ?? '').toString(),
        slug: slug,
        baseDir: baseDirForRelativeImages,
        assetsMode: assetsMode,
        pageNo: pg['page_no'],
      );

      // word_timing_json disimpan TEXT → pastikan string
      final wt = pg['word_timing_json'];
      final wtString = (wt is Map || wt is List)
          ? jsonEncode(wt)
          : (wt?.toString());

      pages.add({
        'page_no': pg['page_no'] ?? 1,
        'text': pg['text'] ?? '',
        'text_rich_html': pg['text_rich_html'],
        'image': imgResolved ?? '',
        'tts_ssml': pg['tts_ssml'],
        'duration_ms': pg['duration_ms'],
        'word_timing_json': wtString,
      });
    }

    final id = await _db.upsertStoryWithPages(
      slug: slug,
      story: storyMap,
      pages: pages,
      replacePages: replacePages,
    );
    return id;
  }

  /// Resolve path gambar:
  /// - 'assets/...': kembalikan apa adanya.
  /// - 'http(s)://...': kembalikan apa adanya.
  /// - absolute path: kembalikan apa adanya.
  /// - relative:
  ///   - assetsMode=true  → jadikan 'baseDir/slug/<name>' (asset path).
  ///   - assetsMode=false → copy dari baseDir ke appDocs/stories/<slug>/ (return absolute path).
  Future<String?> _resolvePath({
    required String inputPath,
    required String slug,
    required String baseDir,
    required bool assetsMode,
    int? pageNo,
  }) async {
    final pth = inputPath.trim();
    if (pth.isEmpty) return null;

    final lower = pth.toLowerCase();
    if (lower.startsWith('assets/')) return pth;
    if (lower.startsWith('http://') || lower.startsWith('https://')) return pth;
    if (p.isAbsolute(pth)) return pth;

    // relative
    if (assetsMode) {
      // Asumsi: gambar ada di assets/stories/<slug>/
      return p
          .join(baseDir, slug, pth)
          .replaceAll('\\', '/'); // asset path pakai forward slash
    } else {
      // storage mode → copy ke documents
      final src = File(p.join(baseDir, pth));
      if (!await src.exists()) {
        // kalau file tidak ada, return null → UI akan pakai placeholder
        return null;
      }
      final appDocs = await getApplicationDocumentsDirectory();
      final storyDir = Directory(p.join(appDocs.path, 'stories', slug));
      if (!await storyDir.exists()) await storyDir.create(recursive: true);

      final String dstName;
      if (pageNo == null) {
        dstName = 'cover${p.extension(src.path)}';
      } else {
        dstName = 'page_$pageNo${p.extension(src.path)}';
      }
      final dstPath = p.join(storyDir.path, dstName);
      await src.copy(dstPath);
      return dstPath;
    }
  }
}
