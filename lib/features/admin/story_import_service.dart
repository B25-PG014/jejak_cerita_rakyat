// lib/features/admin/story_import_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/story_repository.dart';

class StoryImportService {
  final _db = AppDatabase.instance;
  final StoryRepository _repo;

  /// Boleh di-inject; jika null pakai instance default.
  StoryImportService({StoryRepository? repo})
    : _repo = repo ?? StoryRepository(AppDatabase.instance);

  // =========================
  // === SINGLE IMPORT API ===
  // =========================

  /// Import 1 cerita dari file JSON (path).
  /// Jika file berisi banyak cerita, gunakan [importManyFromJsonFile].
  Future<int> importFromJsonFile(
    String jsonFilePath, {
    bool replacePages = true,
    Future<void> Function()? onProvinceChanged, // <-- PATCH
  }) async {
    final raw = await File(jsonFilePath).readAsString();
    final sanitized = _escapeControlCharsInsideStrings(raw);
    final dynamic root = jsonDecode(sanitized);

    final baseDir = p.dirname(jsonFilePath);
    final ids = await _importJsonRoot(
      root,
      baseDirForRelativeImages: baseDir,
      assetsMode: false,
      replacePages: replacePages,
      onProvinceChanged: onProvinceChanged, // <-- PATCH
    );
    if (ids.isEmpty) {
      throw StateError('Tidak ada cerita yang berhasil diimpor dari file.');
    }
    return ids.first;
  }

  /// Import 1 cerita dari asset JSON.
  /// Jika asset berisi banyak cerita, gunakan [importManyFromJsonAsset].
  Future<int> importFromJsonAsset(
    String assetJsonPath, {
    bool replacePages = true,
    Future<void> Function()? onProvinceChanged, // <-- PATCH
  }) async {
    final raw = await rootBundle.loadString(assetJsonPath);
    final sanitized = _escapeControlCharsInsideStrings(raw);
    final dynamic root = jsonDecode(sanitized);

    final baseDir = p.dirname(assetJsonPath); // e.g. assets/stories
    final ids = await _importJsonRoot(
      root,
      baseDirForRelativeImages: baseDir,
      assetsMode: true,
      replacePages: replacePages,
      onProvinceChanged: onProvinceChanged, // <-- PATCH
    );
    if (ids.isEmpty) {
      throw StateError('Tidak ada cerita yang berhasil diimpor dari asset.');
    }
    return ids.first;
  }

  // ========================
  // === MULTI IMPORT API ===
  // ========================

  /// Import BANYAK cerita dari 1 file JSON.
  /// Mendeteksi otomatis format:
  /// - Array: [ {story1}, {story2}, ... ]
  /// - Objek: { "stories": [ {story1}, ... ] }
  /// - Objek single: { ... } → dianggap 1 cerita
  Future<List<int>> importManyFromJsonFile(
    String jsonFilePath, {
    bool replacePages = true,
    Future<void> Function()? onProvinceChanged, // <-- PATCH
  }) async {
    final raw = await File(jsonFilePath).readAsString();
    final sanitized = _escapeControlCharsInsideStrings(raw);
    final dynamic root = jsonDecode(sanitized);

    final baseDir = p.dirname(jsonFilePath);
    return _importJsonRoot(
      root,
      baseDirForRelativeImages: baseDir,
      assetsMode: false,
      replacePages: replacePages,
      onProvinceChanged: onProvinceChanged, // <-- PATCH
    );
  }

  /// Import BANYAK cerita dari 1 asset JSON (lihat format di atas).
  Future<List<int>> importManyFromJsonAsset(
    String assetJsonPath, {
    bool replacePages = true,
    Future<void> Function()? onProvinceChanged, // <-- PATCH
  }) async {
    final raw = await rootBundle.loadString(assetJsonPath);
    final sanitized = _escapeControlCharsInsideStrings(raw);
    final dynamic root = jsonDecode(sanitized);

    final baseDir = p.dirname(assetJsonPath);
    return _importJsonRoot(
      root,
      baseDirForRelativeImages: baseDir,
      assetsMode: true,
      replacePages: replacePages,
      onProvinceChanged: onProvinceChanged, // <-- PATCH
    );
  }

  // ============================
  // === IMPORT CORE (PRIVATE)===
  // ============================

  /// Menerima root JSON apa pun (single / array / object with "stories") dan
  /// mengembalikan daftar ID cerita yang berhasil diimpor.
  Future<List<int>> _importJsonRoot(
    dynamic root, {
    required String baseDirForRelativeImages,
    required bool assetsMode,
    required bool replacePages,
    Future<void> Function()? onProvinceChanged, // <-- PATCH
  }) async {
    final ids = <int>[];

    if (root is List) {
      // Root langsung array: [ {...}, {...} ]
      for (final item in root) {
        if (item is Map<String, dynamic>) {
          final id = await importFromJsonMap(
            item,
            baseDirForRelativeImages: baseDirForRelativeImages,
            assetsMode: assetsMode,
            replacePages: replacePages,
            onProvinceChanged: onProvinceChanged, // <-- PATCH
          );
          ids.add(id);
        }
      }
      return ids;
    }

    if (root is Map<String, dynamic>) {
      // Bentuk { "stories": [ {...}, {...} ] }
      if (root['stories'] is List) {
        final list = root['stories'] as List;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final id = await importFromJsonMap(
              item,
              baseDirForRelativeImages: baseDirForRelativeImages,
              assetsMode: assetsMode,
              replacePages: replacePages,
              onProvinceChanged: onProvinceChanged, // <-- PATCH
            );
            ids.add(id);
          }
        }
        return ids;
      }

      // Bentuk single: { ... }
      final id = await importFromJsonMap(
        root,
        baseDirForRelativeImages: baseDirForRelativeImages,
        assetsMode: assetsMode,
        replacePages: replacePages,
        onProvinceChanged: onProvinceChanged, // <-- PATCH
      );
      ids.add(id);
      return ids;
    }

    throw ArgumentError('Format JSON tidak dikenali. Harus Map atau List.');
  }

  /// Import dari Map JSON (satu cerita).
  Future<int> importFromJsonMap(
    Map<String, dynamic> j, {
    required String baseDirForRelativeImages,
    required bool assetsMode,
    bool replacePages = true,
    Future<void> Function()? onProvinceChanged, // <-- PATCH
  }) async {
    final slug = (j['slug'] as String?)?.trim();
    if (slug == null || slug.isEmpty) {
      throw ArgumentError('Field "slug" wajib ada dan tidak boleh kosong.');
    }

    // --- Kumpulkan pages terlebih dahulu (agar bisa fallback cover & synopsis) ---
    final List pagesRaw = (j['pages'] ?? []) as List;
    pagesRaw.sort((a, b) {
      final an = (a['page_no'] as num?)?.toInt() ?? 0;
      final bn = (b['page_no'] as num?)?.toInt() ?? 0;
      return an.compareTo(bn);
    });

    final pages = <Map<String, dynamic>>[];
    for (final raw in pagesRaw) {
      final Map<String, dynamic> pg = Map<String, dynamic>.from(raw as Map);

      final imgResolved = await _resolvePath(
        inputPath: (pg['image'] ?? '').toString(),
        slug: slug,
        baseDir: baseDirForRelativeImages,
        assetsMode: assetsMode,
        pageNo: (pg['page_no'] as num?)?.toInt(),
      );

      // paragraphs -> text (opsional)
      final paragraphs = (pg['paragraphs'] as List?)
          ?.map((e) => e.toString())
          .toList();
      final textVal =
          (pg['text']?.toString()) ??
          (paragraphs != null ? paragraphs.join('\n') : '');

      // word_timing_json selalu string
      final wt = pg['word_timing_json'];
      final wtString = (wt is Map || wt is List)
          ? jsonEncode(wt)
          : (wt?.toString());

      pages.add({
        'page_no': (pg['page_no'] as num?)?.toInt() ?? 1,
        'text': textVal,
        'text_rich_html': pg['text_rich_html'],
        'image': imgResolved ?? '',
        'tts_ssml': pg['tts_ssml'],
        'duration_ms': (pg['duration_ms'] as num?)?.toInt(),
        'word_timing_json': wtString,
      });
    }

    // --- Cover: pakai cover explisit, kalau kosong ambil dari halaman pertama yg punya image ---
    final resolvedCover = await _resolvePath(
      inputPath: (j['cover'] ?? '').toString(),
      slug: slug,
      baseDir: baseDirForRelativeImages,
      assetsMode: assetsMode,
      pageNo: null,
    );
    String? coverToUse = resolvedCover;
    if (coverToUse == null || coverToUse.isEmpty) {
      final firstWithImage = pages.firstWhere(
        (e) => (e['image'] as String?)?.isNotEmpty == true,
        orElse: () => const {},
      );
      if (firstWithImage.isNotEmpty) {
        coverToUse = firstWithImage['image'] as String;
      }
    }

    // --- Synopsis: jika kosong, ambil kalimat pertama dari halaman 1 ---
    String synopsis = (j['synopsis'] ?? '').toString().trim();
    if (synopsis.isEmpty && pages.isNotEmpty) {
      final firstText = (pages.first['text'] as String? ?? '').trim();
      if (firstText.isNotEmpty) {
        synopsis = firstText.split(RegExp(r'[.!?]')).first.trim();
      }
    }

    final storyMap = {
      'title': (j['title'] ?? '').toString(),
      'subtitle': (j['subtitle'] ?? '').toString(),
      'synopsis': synopsis,
      'cover_asset': coverToUse ?? '',
      'age_min': (j['age_min'] as num?)?.toInt() ?? 6,
      'age_max': (j['age_max'] as num?)?.toInt(),
      'locale': (j['locale'] ?? 'id').toString(),
      'author': (j['author'] ?? '').toString(),
      'source': (j['source'] ?? '').toString(),
    };

    final storyId = await _db.upsertStoryWithPages(
      slug: slug,
      story: storyMap,
      pages: pages,
      replacePages: replacePages,
    );

    // --- provinces (opsional) ---
    bool touchedProvince = false; // <-- PATCH: flag untuk callback
    final provRaw = j['provinces'];
    if (provRaw is List) {
      for (final item in provRaw) {
        int? provinceId;
        if (item is String) {
          provinceId =
              await _repo.findProvinceIdByName(item) ??
              await _repo.upsertProvinceByName(name: item);
          if (provinceId != null) touchedProvince = true;
        } else if (item is Map) {
          final name = (item['name'] ?? '').toString().trim();
          final idVal = item['id'];
          final xr = (item['x_rel'] as num?)?.toDouble();
          final yr = (item['y_rel'] as num?)?.toDouble();
          if (idVal != null) {
            provinceId = (idVal as num).toInt();
            if (xr != null || yr != null) {
              await _repo.updateProvinceCoords(
                id: provinceId,
                xRel: xr,
                yRel: yr,
              );
              touchedProvince = true;
            }
          } else if (name.isNotEmpty) {
            provinceId = await _repo.upsertProvinceByName(
              name: name,
              xRel: xr,
              yRel: yr,
            );
            if (provinceId != null) touchedProvince = true;
          }
        }
        if (provinceId != null) {
          await _repo.upsertStoryProvince(
            storyId: storyId,
            provinceId: provinceId,
          );
          touchedProvince = true;
        }
      }
    }

    // panggil callback sekali jika ada perubahan provinsi
    if (touchedProvince && onProvinceChanged != null) {
      await onProvinceChanged();
    }

    return storyId;
  }

  /// Resolve path gambar:
  /// - 'assets/...': kembalikan apa adanya jika ada di bundle; jika tidak dan import dari storage,
  ///   coba cari file fisik di sebelah JSON (basename maupun subfolder).
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

    // Path assets: kalau ada di bundle, langsung pakai.
    if (lower.startsWith('assets/')) {
      try {
        await rootBundle.load(pth); // valid di bundle?
        return pth;
      } catch (_) {
        // Jika import dari storage & path di JSON 'assets/...'
        // coba cari file fisik di sebelah JSON (basename maupun subfolder)
        if (!assetsMode) {
          final candidate1 = File(p.join(baseDir, p.basename(pth)));
          if (await candidate1.exists()) {
            final appDocs = await getApplicationDocumentsDirectory();
            final storyDir = Directory(p.join(appDocs.path, 'stories', slug));
            if (!await storyDir.exists())
              await storyDir.create(recursive: true);
            final dstName = pageNo == null
                ? 'cover${p.extension(candidate1.path)}'
                : 'page_$pageNo${p.extension(candidate1.path)}';
            final dstPath = p.join(storyDir.path, dstName);
            await candidate1.copy(dstPath);
            return dstPath;
          }
          final candidate2 = File(p.join(baseDir, pth)); // hormati subfolder
          if (await candidate2.exists()) {
            final appDocs = await getApplicationDocumentsDirectory();
            final storyDir = Directory(p.join(appDocs.path, 'stories', slug));
            if (!await storyDir.exists())
              await storyDir.create(recursive: true);
            final dstName = pageNo == null
                ? 'cover${p.extension(candidate2.path)}'
                : 'page_$pageNo${p.extension(candidate2.path)}';
            final dstPath = p.join(storyDir.path, dstName);
            await candidate2.copy(dstPath);
            return dstPath;
          }
        }
        return null; // biar fallback cover jalan
      }
    }

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return pth;
    }

    if (p.isAbsolute(pth)) return pth;

    // Relative
    if (assetsMode) {
      // Asumsi struktur: assets/stories/<slug>/<image>
      return p.join(baseDir, slug, pth).replaceAll('\\', '/');
    } else {
      final src = File(p.join(baseDir, pth));
      if (!await src.exists()) return null;
      final appDocs = await getApplicationDocumentsDirectory();
      final storyDir = Directory(p.join(appDocs.path, 'stories', slug));
      if (!await storyDir.exists()) await storyDir.create(recursive: true);
      final dstName = pageNo == null
          ? 'cover${p.extension(src.path)}'
          : 'page_$pageNo${p.extension(src.path)}';
      final dstPath = p.join(storyDir.path, dstName);
      await src.copy(dstPath);
      return dstPath;
    }
  }

  // ===========================================
  // Sanitizer untuk JSON (newline/tab mentah)
  // ===========================================
  /// Meng-escape \n, \r, \t **di dalam string JSON** supaya Notepad/Editor
  /// yang memasukkan ENTER mentah tidak menyebabkan FormatException.
  String _escapeControlCharsInsideStrings(String raw) {
    final b = StringBuffer();
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (inString) {
        if (escaped) {
          b.write(ch);
          escaped = false;
        } else if (ch == '\\') {
          b.write(ch);
          escaped = true;
        } else if (ch == '"') {
          b.write(ch);
          inString = false;
        } else if (ch == '\n') {
          b.write(r'\n');
        } else if (ch == '\r') {
          b.write(r'\r');
        } else if (ch == '\t') {
          b.write(r'\t');
        } else {
          b.write(ch);
        }
      } else {
        if (ch == '"') {
          b.write(ch);
          inString = true;
        } else {
          b.write(ch);
        }
      }
    }
    return b.toString();
  }
}
