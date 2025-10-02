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
    return db.query(
      'pages',
      columns: [
        'id',
        'page_no',
        'text_plain',
        'text_rich_html',
        'image_asset',
        'tts_ssml',
        'word_timing_json',
        'duration_ms',
      ],
      where: 'story_id = ?',
      whereArgs: [storyId],
      orderBy: 'page_no ASC',
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
}
