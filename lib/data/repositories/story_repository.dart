import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../data/db/app_database.dart';

class StoryRepository {
  final AppDatabase _db;
  StoryRepository(this._db);

  Future<Database> get _database async => _db.database;

  // ==== STORIES ==============================================================
  Future<List<Map<String, dynamic>>> fetchStories() async {
    final db = await _database;
    return db.rawQuery('''
      SELECT id, slug, title, synopsis, cover_asset, page_count
      FROM v_story_with_counts
      ORDER BY title COLLATE NOCASE;
    ''');
  }

  Future<List<Map<String, dynamic>>> fetchPages(int storyId) async {
    final db = await _database;
    return db.rawQuery(
      '''
    SELECT
      id,
      page_no,
      text_plain,
      text_rich_html,
      image_asset,
      image_asset AS image,  -- alias utk kompatibel dgn reader_page lama
      tts_ssml,
      word_timing_json,
      duration_ms
    FROM pages
    WHERE story_id = ?
    ORDER BY page_no ASC;
    ''',
      [storyId],
    );
  }

  Future<List<Map<String, dynamic>>> searchStories(String q) async {
    final db = await _database;
    final query = q.trim();
    if (query.isEmpty) return [];

    try {
      // Versi FTS (kalau tersedia)
      return db.rawQuery(
        '''
        WITH results AS (
          SELECT s.id, s.slug, s.title, s.synopsis, s.cover_asset, s.page_count
          FROM stories_fts f
          JOIN stories s ON s.id = f.rowid
          WHERE stories_fts MATCH ?
          UNION
          SELECT s.id, s.slug, s.title, s.synopsis, s.cover_asset, s.page_count
          FROM pages_fts pf
          JOIN pages p ON p.id = pf.rowid
          JOIN stories s ON s.id = p.story_id
          WHERE pages_fts MATCH ?
          GROUP BY s.id
        )
        SELECT * FROM results
        ORDER BY title COLLATE NOCASE;
      ''',
        [query, query],
      );
    } catch (_) {
      // Fallback LIKE
      return db.rawQuery(
        '''
        SELECT id, slug, title, synopsis, cover_asset, page_count
        FROM stories
        WHERE title LIKE '%' || ? || '%' OR synopsis LIKE '%' || ? || '%'
        UNION
        SELECT s.id, s.slug, s.title, s.synopsis, s.cover_asset, s.page_count
        FROM pages p
        JOIN stories s ON s.id = p.story_id
        WHERE p.text_plain LIKE '%' || ? || '%'
        GROUP BY id
        ORDER BY title COLLATE NOCASE;
      ''',
        [query, query, query],
      );
    }
  }

  // ==== PROVINCES / PINS =====================================================

  /// Aggregat jumlah cerita per provinsi (dipakai di layar lain).
  Future<List<Map<String, dynamic>>> fetchProvinceCounts() async {
    final db = await _database;
    return db.rawQuery('SELECT * FROM v_province_counts;');
  }

  /// Pin untuk SATU cerita (dipakai di home agar hanya tampil pin cerita yang disorot).
  Future<List<Map<String, Object?>>> fetchProvincesForStory(int storyId) async {
    final d = await _database;
    return d.rawQuery(
      '''
      SELECT p.id, p.name, p.x_rel, p.y_rel
      FROM provinces p
      JOIN story_province sp ON sp.province_id = p.id
      WHERE sp.story_id = ?
      ''',
      [storyId],
    );
  }

  /// Daftar cerita per provinsi (popup).
  Future<List<Map<String, dynamic>>> fetchStoriesByProvinceId(
    int provinceId,
  ) async {
    final db = await _database;
    return db.rawQuery(
      '''
      SELECT s.id, s.slug, s.title, s.synopsis, s.cover_asset, s.page_count
      FROM story_province sp
      JOIN stories s ON s.id = sp.story_id
      WHERE sp.province_id = ?
      ORDER BY s.title COLLATE NOCASE;
      ''',
      [provinceId],
    );
  }

  /// Buat relasi story<->province (abaikan jika sudah ada).
  Future<int> upsertStoryProvince({
    required int storyId,
    required int provinceId,
  }) async {
    final db = await _database;
    return db.insert('story_province', {
      'story_id': storyId,
      'province_id': provinceId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Cari ID provinsi berdasarkan nama (case-insensitive).
  Future<int?> findProvinceIdByName(String name) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT id FROM provinces WHERE LOWER(name) = LOWER(?) LIMIT 1',
      [name],
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  /// Buat/Update provinsi berdasarkan nama. Jika x/y diberikan akan di-set.
  Future<int> upsertProvinceByName({
    required String name,
    double? xRel,
    double? yRel,
  }) async {
    final db = await _database;
    final existing = await db.query(
      'provinces',
      columns: ['id', 'x_rel', 'y_rel'],
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [name],
      limit: 1,
    );
    if (existing.isEmpty) {
      return db.insert('provinces', {
        'name': name,
        'x_rel': xRel ?? 0.5,
        'y_rel': yRel ?? 0.5,
      });
    } else {
      final id = existing.first['id'] as int;
      if (xRel != null || yRel != null) {
        await db.update(
          'provinces',
          {if (xRel != null) 'x_rel': xRel, if (yRel != null) 'y_rel': yRel},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      return id;
    }
  }

  /// Update koordinat provinsi (opsional).
  Future<void> updateProvinceCoords({
    required int id,
    double? xRel,
    double? yRel,
  }) async {
    final db = await _database;
    await db.update(
      'provinces',
      {if (xRel != null) 'x_rel': xRel, if (yRel != null) 'y_rel': yRel},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Normalisasi koordinat kalau ada yang > 1 (mis. diinput 56 → 0.56).
  Future<void> normalizeProvinceCoords() async {
    final db = await _database;
    await db.rawUpdate(
      'UPDATE provinces SET x_rel = x_rel / 100.0 WHERE x_rel > 1.0;',
    );
    await db.rawUpdate(
      'UPDATE provinces SET y_rel = y_rel / 100.0 WHERE y_rel > 1.0;',
    );
  }

  // ==== UTIL DASAR UNTUK SEED ================================================

  Future<int> countStories() async {
    final db = await _db.database;
    final res = await db.rawQuery('SELECT COUNT(*) AS c FROM stories');
    return (res.first['c'] as int?) ?? 0;
  }

  /// Insert batch kasar (dipakai beberapa util).
  Future<void> bulkInsertStoriesWithPages(
    List<dynamic> stories,
    List<dynamic> pages,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      for (final s in stories) {
        final m = Map<String, Object?>.from(s as Map);
        await txn.insert(
          'stories',
          m,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final p in pages) {
        final m = Map<String, Object?>.from(p as Map);
        await txn.insert(
          'pages',
          m,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  /// Opsional: hapus dummy berdasarkan pola judul (dipanggil saat migrasi)
  Future<void> deleteStoriesByTitlePatterns(List<String> pats) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      for (final p in pats) {
        await txn.delete(
          'stories',
          where: 'LOWER(title) LIKE ?',
          whereArgs: ['%${p.toLowerCase()}%'],
        );
      }
    });
  }

  // === Tambahan BARU: khusus format JSON top-level LIST (story berisi pages) =
  Future<void> bulkInsertStoriesWithNestedPagesFromTopLevelList(
    List<dynamic> items,
  ) async {
    final db = await _db.database;

    // helper: pilih hanya kolom yang ada di tabel STORIES
    Map<String, Object?> selectStoryCols(
      Map<String, dynamic> src, {
      required int pageCount,
    }) {
      final out = <String, Object?>{};
      // id (opsional, jika ada & int)
      if (src['id'] is int) out['id'] = src['id'];
      // slug, title, synopsis
      if (src['slug'] != null) out['slug'] = src['slug'];
      if (src['title'] != null) out['title'] = src['title'];
      if (src['synopsis'] != null) out['synopsis'] = src['synopsis'];
      // cover / cover_asset
      if (src['cover_asset'] != null) {
        out['cover_asset'] = src['cover_asset'];
      } else if (src['cover'] != null) {
        out['cover_asset'] = src['cover'];
      }
      // page_count TIDAK diset (skema kamu tidak punya kolom ini)
      return out;
    }

    // helper: pilih hanya kolom yang ada di tabel PAGES
    Map<String, Object?> selectPageCols(
      Map<String, dynamic> src, {
      required int storyId,
    }) {
      final out = <String, Object?>{};
      out['story_id'] = storyId;

      // page_no
      final pn = src['page_no'];
      if (pn is int) {
        out['page_no'] = pn;
      } else if (pn is String) {
        final n = int.tryParse(pn);
        if (n != null) out['page_no'] = n;
      }

      // image / image_asset
      if (src['image_asset'] != null) {
        out['image_asset'] = src['image_asset'];
      } else if (src['image'] != null) {
        out['image_asset'] = src['image'];
      }

      // text_plain priority:
      // 1) text_plain
      // 2) text
      // 3) paragraphs (join with \n)
      if (src['text_plain'] != null) {
        out['text_plain'] = src['text_plain'];
      } else if (src['text'] != null) {
        out['text_plain'] = src['text'];
      } else if (src['paragraphs'] is List) {
        final paras = (src['paragraphs'] as List)
            .whereType<String>()
            .toList()
            .join('\n');
        out['text_plain'] = paras;
      }

      // Optional extras jika ada (biarkan null kalau tidak ada):
      if (src['text_rich_html'] != null) {
        out['text_rich_html'] = src['text_rich_html'];
      }
      if (src['tts_ssml'] != null) {
        out['tts_ssml'] = src['tts_ssml'];
      }
      if (src['word_timing_json'] != null) {
        out['word_timing_json'] = (src['word_timing_json'] is String)
            ? src['word_timing_json']
            : jsonEncode(src['word_timing_json']);
      }
      if (src['duration_ms'] != null) {
        final d = src['duration_ms'];
        if (d is int) {
          out['duration_ms'] = d;
        } else if (d is String) {
          final n = int.tryParse(d);
          if (n != null) out['duration_ms'] = n;
        }
      }
      return out;
    }

    await db.transaction((txn) async {
      for (final it in items) {
        if (it is! Map) continue;

        final storyRaw = Map<String, dynamic>.from(it);
        final pagesRaw = (storyRaw['pages'] is List)
            ? List<Map<String, dynamic>>.from(
                (storyRaw['pages'] as List).map(
                  (e) => Map<String, dynamic>.from(e as Map),
                ),
              )
            : <Map<String, dynamic>>[];

        // hitung pageCount (tidak disimpan ke tabel, tapi mungkin berguna)
        final pageCount = pagesRaw.length;

        // siapkan map story sesuai kolom tabel
        final storyForDb = selectStoryCols(storyRaw, pageCount: pageCount);

        // insert story
        final insertedId = await txn.insert(
          'stories',
          storyForDb,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // dapatkan storyId efektif (untuk kasus conflict ignore)
        var effectiveStoryId = insertedId;
        if (effectiveStoryId == 0) {
          // coba cari via slug (jika unik)
          if (storyForDb.containsKey('slug')) {
            final slug = storyForDb['slug'] as String?;
            if (slug != null && slug.isNotEmpty) {
              final cur = await txn.query(
                'stories',
                columns: ['id'],
                where: 'slug = ?',
                whereArgs: [slug],
                limit: 1,
              );
              if (cur.isNotEmpty) {
                effectiveStoryId = (cur.first['id'] as int?) ?? 0;
              }
            }
          }
        }

        if (effectiveStoryId == 0) {
          // fallback cari by title kalau slug tidak ada
          if (storyForDb.containsKey('title')) {
            final title = storyForDb['title'] as String?;
            if (title != null && title.isNotEmpty) {
              final cur = await txn.query(
                'stories',
                columns: ['id'],
                where: 'title = ?',
                whereArgs: [title],
                limit: 1,
              );
              if (cur.isNotEmpty) {
                effectiveStoryId = (cur.first['id'] as int?) ?? 0;
              }
            }
          }
        }

        // insert pages
        if (effectiveStoryId != 0) {
          for (final p in pagesRaw) {
            final pageForDb = selectPageCols(p, storyId: effectiveStoryId);
            if (!pageForDb.containsKey('page_no')) {
              // lewati page tanpa page_no valid
              continue;
            }
            await txn.insert(
              'pages',
              pageForDb,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      }
    });
  }

  // === BARU: PRIVATE HELPERS pakai DatabaseExecutor (db/txn) ================

  Future<int?> _findStoryIdBySlugOrTitleExec(
    DatabaseExecutor exec, {
    String? slug,
    String? title,
  }) async {
    if (slug != null && slug.isNotEmpty) {
      final r = await exec.query(
        'stories',
        columns: ['id'],
        where: 'slug = ?',
        whereArgs: [slug],
        limit: 1,
      );
      if (r.isNotEmpty) return r.first['id'] as int?;
    }
    if (title != null && title.isNotEmpty) {
      final r = await exec.query(
        'stories',
        columns: ['id'],
        where: 'title = ?',
        whereArgs: [title],
        limit: 1,
      );
      if (r.isNotEmpty) return r.first['id'] as int?;
    }
    return null;
  }

  Future<int> _upsertProvinceByNameExec(
    DatabaseExecutor exec, {
    required String name,
    double? xRel,
    double? yRel,
  }) async {
    final existing = await exec.query(
      'provinces',
      columns: ['id', 'x_rel', 'y_rel'],
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [name],
      limit: 1,
    );
    if (existing.isEmpty) {
      return exec.insert('provinces', {
        'name': name,
        'x_rel': xRel ?? 0.5,
        'y_rel': yRel ?? 0.5,
      });
    } else {
      final id = existing.first['id'] as int;
      if (xRel != null || yRel != null) {
        await exec.update(
          'provinces',
          {if (xRel != null) 'x_rel': xRel, if (yRel != null) 'y_rel': yRel},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      return id;
    }
  }

  Future<int> _upsertStoryProvinceExec(
    DatabaseExecutor exec, {
    required int storyId,
    required int provinceId,
  }) {
    return exec.insert('story_province', {
      'story_id': storyId,
      'province_id': provinceId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // === BARU: PUBLIC UTILS ====================================================

  /// Cari story.id via slug dulu, kalau tidak ada pakai title.
  Future<int?> findStoryIdBySlugOrTitle({String? slug, String? title}) async {
    final db = await _db.database;
    return _findStoryIdBySlugOrTitleExec(db, slug: slug, title: title);
  }

  /// Backfill relasi provinces untuk data yang sudah ada di `stories`.
  /// `items` adalah List dari JSON top-level (tiap story bisa punya `provinces`):
  /// - Bentuk 1: [{ "name": "Sumatera Barat", "x_rel": 0.15, "y_rel": 0.42 }, ...]
  /// - Bentuk 2: ["Sumatera Barat", "Jawa Barat", ...]
  Future<void> linkProvincesForExistingStoriesFromJsonTopLevelList(
    List<dynamic> items,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      for (final it in items) {
        if (it is! Map) continue;
        final m = Map<String, dynamic>.from(it);

        final slug = (m['slug'] ?? '') as String?;
        final title = (m['title'] ?? '') as String?;
        final storyId = await _findStoryIdBySlugOrTitleExec(
          txn,
          slug: slug,
          title: title,
        );
        if (storyId == null) continue;

        final provRaw = m['provinces'];
        if (provRaw is List) {
          for (final p in provRaw) {
            // Bisa objek {name, x_rel, y_rel} atau string nama saja
            String? name;
            double? xRel;
            double? yRel;

            if (p is String) {
              name = p;
            } else if (p is Map) {
              final pm = Map<String, dynamic>.from(p);
              name = (pm['name'] ?? pm['province'] ?? pm['title'])?.toString();
              // x_rel / y_rel bisa int/string → konversi ke double bila ada
              final xr = pm['x_rel'];
              final yr = pm['y_rel'];
              if (xr is num) xRel = xr.toDouble();
              if (yr is num) yRel = yr.toDouble();
              if (xr is String) xRel = double.tryParse(xr);
              if (yr is String) yRel = double.tryParse(yr);
            }

            if (name == null || name.trim().isEmpty) continue;

            final provId = await _upsertProvinceByNameExec(
              txn,
              name: name,
              xRel: xRel,
              yRel: yRel,
            );

            await _upsertStoryProvinceExec(
              txn,
              storyId: storyId,
              provinceId: provId,
            );
          }
        }
      }

      // Normalisasi koordinat di dalam transaksi (aman)
      await txn.rawUpdate(
        'UPDATE provinces SET x_rel = x_rel / 100.0 WHERE x_rel > 1.0;',
      );
      await txn.rawUpdate(
        'UPDATE provinces SET y_rel = y_rel / 100.0 WHERE y_rel > 1.0;',
      );
    });
  }
}
