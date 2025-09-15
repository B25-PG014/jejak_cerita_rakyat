// lib/data/db/app_database.dart
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'jejak_cerita_rakyat.db';
  static const _dbVersion = 2; // v1: tabel dasar; v2: FTS

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // foreign key ON
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createV1(db);
        // Seed 5 cerita dummy
        await _seedDummy(db);
        // Tambah FTS di v2
        await _createV2Fts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 1) {
          await _createV1(db);
        }
        if (oldVersion < 2) {
          await _createV2Fts(db);
        }
      },
    );
  }

  // -------------------- SCHEMA V1 --------------------

  Future<void> _createV1(Database db) async {
    // STORIES
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stories (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        slug         TEXT    NOT NULL UNIQUE,
        title        TEXT    NOT NULL,
        subtitle     TEXT,
        synopsis     TEXT,
        cover_asset  TEXT    NOT NULL,
        age_min      INTEGER NOT NULL DEFAULT 5 CHECK (age_min >= 0),
        age_max      INTEGER CHECK (age_max IS NULL OR age_max >= age_min),
        locale       TEXT    NOT NULL DEFAULT 'id' CHECK (length(locale) BETWEEN 2 AND 5),
        author       TEXT,
        source       TEXT,
        created_at   INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at   INTEGER NOT NULL DEFAULT (strftime('%s','now'))
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_stories_title ON stories(title);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stories_locale ON stories(locale);');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_stories_touch
      AFTER UPDATE ON stories
      WHEN NEW.updated_at = OLD.updated_at
      BEGIN
        UPDATE stories SET updated_at = strftime('%s','now') WHERE id = NEW.id;
      END;
    ''');

    // PAGES
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pages (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        story_id         INTEGER NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
        page_no          INTEGER NOT NULL CHECK (page_no >= 1),
        text_plain       TEXT,
        text_rich_html   TEXT,
        image_asset      TEXT,
        tts_ssml         TEXT,
        word_timing_json TEXT,
        duration_ms      INTEGER,
        created_at       INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at       INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        UNIQUE(story_id, page_no)
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_pages_story ON pages(story_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pages_story_order ON pages(story_id, page_no);');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_pages_touch
      AFTER UPDATE ON pages
      WHEN NEW.updated_at = OLD.updated_at
      BEGIN
        UPDATE pages SET updated_at = strftime('%s','now') WHERE id = NEW.id;
      END;
    ''');

    // VIEW
    await db.execute('''
      CREATE VIEW IF NOT EXISTS v_story_with_counts AS
      SELECT s.*,
             (SELECT COUNT(*) FROM pages p WHERE p.story_id = s.id) AS page_count
      FROM stories s;
    ''');
  }

  // -------------------- SCHEMA V2 (FTS) --------------------

  Future<void> _createV2Fts(Database db) async {
    try {
      // STORIES FTS
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS stories_fts
        USING fts5(title, synopsis, content='stories', content_rowid='id');
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_stories_fts_ai
        AFTER INSERT ON stories BEGIN
          INSERT INTO stories_fts(rowid, title, synopsis)
          VALUES (NEW.id, NEW.title, NEW.synopsis);
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_stories_fts_ad
        AFTER DELETE ON stories BEGIN
          INSERT INTO stories_fts(stories_fts, rowid, title, synopsis)
          VALUES('delete', OLD.id, OLD.title, OLD.synopsis);
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_stories_fts_au
        AFTER UPDATE ON stories BEGIN
          INSERT INTO stories_fts(stories_fts) VALUES('rebuild');
        END;
      ''');

      // PAGES FTS
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS pages_fts
        USING fts5(text_plain, content='pages', content_rowid='id', tokenize='unicode61');
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_pages_fts_ai
        AFTER INSERT ON pages BEGIN
          INSERT INTO pages_fts(rowid, text_plain) VALUES (NEW.id, NEW.text_plain);
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_pages_fts_ad
        AFTER DELETE ON pages BEGIN
          INSERT INTO pages_fts(pages_fts, rowid, text_plain)
          VALUES('delete', OLD.id, OLD.text_plain);
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_pages_fts_au
        AFTER UPDATE ON pages BEGIN
          INSERT INTO pages_fts(pages_fts) VALUES('rebuild');
        END;
      ''');

      // Build awal isi FTS dari content table
      await db.execute('INSERT INTO stories_fts(stories_fts) VALUES (\'rebuild\');');
      await db.execute('INSERT INTO pages_fts(pages_fts) VALUES (\'rebuild\');');
    } catch (e) {
      // Jika device tidak mendukung FTS5, abaikan—nanti search() pakai LIKE fallback
      // print('FTS not available: $e');
    }
  }

  // -------------------- SEED DUMMY (5 cerita, 2 halaman) --------------------

  Future<void> _seedDummy(Database db) async {
    // Hindari seed dobel
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM stories')) ?? 0;
    if (count > 0) return;

    Future<int> addStory({
      required String slug,
      required String title,
      String? synopsis,
      required String coverAsset,
      int ageMin = 6,
      String locale = 'id',
      List<Map<String, dynamic>> pages = const [],
    }) async {
      final storyId = await db.insert('stories', {
        'slug': slug,
        'title': title,
        'synopsis': synopsis ?? '',
        'cover_asset': coverAsset,
        'age_min': ageMin,
        'locale': locale,
      });
      for (final pg in pages) {
        await db.insert('pages', {
          'story_id': storyId,
          'page_no': pg['page_no'],
          'text_plain': pg['text_plain'],
          'image_asset': pg['image_asset'],
        });
      }
      return storyId;
    }

    await db.transaction((txn) async {
      // 1. Bawang Merah & Bawang Putih
      await addStory(
        slug: 'bawang-merah-bawang-putih',
        title: 'Bawang Merah & Bawang Putih',
        synopsis: 'Kisah klasik tentang kebaikan, kerja keras, dan kejujuran.',
        coverAsset: 'assets/images/covers/bawang.png',
        pages: [
          {
            'page_no': 1,
            'text_plain': 'Alkisah, Bawang Putih gadis rajin dan baik hati tinggal bersama ibu tiri dan Bawang Merah.',
            'image_asset': 'assets/images/ui/page1.png',
          },
          {
            'page_no': 2,
            'text_plain': 'Kebaikan Bawang Putih berbuah kebahagiaan; iri hati Bawang Merah berakhir penyesalan.',
            'image_asset': 'assets/images/ui/page2.png',
          },
        ],
      );

      // 2. Malin Kundang
      await addStory(
        slug: 'malin-kundang',
        title: 'Malin Kundang',
        synopsis: 'Anak durhaka yang melupakan ibunya hingga mendapat hukuman.',
        coverAsset: 'assets/images/covers/malin.png',
        pages: [
          {
            'page_no': 1,
            'text_plain': 'Malin berlayar merantau dan menjadi kaya, namun malu mengakui ibunya.',
            'image_asset': 'assets/images/ui/page1.png',
          },
          {
            'page_no': 2,
            'text_plain': 'Doa sang ibu membuat Malin mendapat pelajaran berharga tentang hormat.',
            'image_asset': 'assets/images/ui/page2.png',
          },
        ],
      );

      // 3. Timun Mas
      await addStory(
        slug: 'timun-mas',
        title: 'Timun Mas',
        synopsis: 'Gadis pemberani yang cerdas melawan raksasa dengan siasat.',
        coverAsset: 'assets/images/covers/timunmas.png',
        pages: [
          {
            'page_no': 1,
            'text_plain': 'Timun Mas berlari sambil menebar biji, garam, dan terasi untuk mengelabui raksasa.',
            'image_asset': 'assets/images/ui/page1.png',
          },
          {
            'page_no': 2,
            'text_plain': 'Dengan kecerdikan, Timun Mas selamat dan berkumpul kembali dengan ibunya.',
            'image_asset': 'assets/images/ui/page2.png',
          },
        ],
      );

      // 4. Sangkuriang
      await addStory(
        slug: 'sangkuriang',
        title: 'Sangkuriang',
        synopsis: 'Asal-usul Tangkuban Perahu—sebuah perahu terbalik menjadi gunung.',
        coverAsset: 'assets/images/covers/sangkuriang.png',
        pages: [
          {
            'page_no': 1,
            'text_plain': 'Sangkuriang berusaha membuat perahu raksasa dalam semalam.',
            'image_asset': 'assets/images/ui/page1.png',
          },
          {
            'page_no': 2,
            'text_plain': 'Ketika gagal, perahu ditendang hingga terbalik menjadi gunung.',
            'image_asset': 'assets/images/ui/page2.png',
          },
        ],
      );

      // 5. Kancil dan Buaya
      await addStory(
        slug: 'kancil-dan-buaya',
        title: 'Kancil dan Buaya',
        synopsis: 'Kancil yang cerdik menyeberangi sungai dengan akal.',
        coverAsset: 'assets/images/covers/kancil.png',
        pages: [
          {
            'page_no': 1,
            'text_plain': 'Kancil menipu buaya untuk berbaris agar bisa menyeberang sungai.',
            'image_asset': 'assets/images/ui/page1.png',
          },
          {
            'page_no': 2,
            'text_plain': 'Dengan sopan dan cerdas, Kancil berhasil melewati sungai dengan selamat.',
            'image_asset': 'assets/images/ui/page2.png',
          },
        ],
      );
    });
  }

  // -------------------- PUBLIC QUERIES --------------------

  /// List cerita untuk Library (dengan jumlah halaman).
  Future<List<Map<String, dynamic>>> getStoryList() async {
    final db = await database;
    return db.rawQuery('''
      SELECT id, slug, title, synopsis, cover_asset, page_count
      FROM v_story_with_counts
      ORDER BY title COLLATE NOCASE;
    ''');
  }

  /// Halaman-halaman untuk Reader.
  Future<List<Map<String, dynamic>>> getPages(int storyId) async {
    final db = await database;
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
        'duration_ms'
      ],
      where: 'story_id = ?',
      whereArgs: [storyId],
      orderBy: 'page_no ASC',
    );
  }

  /// Pencarian: coba FTS (stories_fts + pages_fts), jika gagal → LIKE fallback.
  Future<List<Map<String, dynamic>>> search(String rawQuery) async {
    final db = await database;
    final q = rawQuery.trim();
    if (q.isEmpty) return [];

    try {
      // UNION FTS: judul/sinopsis + isi halaman → list unik story
      final rows = await db.rawQuery('''
        WITH results AS (
          SELECT s.id, s.title, s.synopsis, s.cover_asset
          FROM stories_fts f
          JOIN stories s ON s.id = f.rowid
          WHERE stories_fts MATCH ?
          UNION
          SELECT s.id, s.title, s.synopsis, s.cover_asset
          FROM pages_fts pf
          JOIN pages p ON p.id = pf.rowid
          JOIN stories s ON s.id = p.story_id
          WHERE pages_fts MATCH ?
          GROUP BY s.id
        )
        SELECT * FROM results
        ORDER BY title COLLATE NOCASE;
      ''', [q, q]);

      // Jika FTS tabel ada tapi kosong dan hasil nol → tetap kembalikan nol (tidak melempar).
      return rows;
    } catch (_) {
      // FTS tidak tersedia → fallback LIKE
      return db.rawQuery('''
        SELECT id, title, synopsis, cover_asset
        FROM stories
        WHERE title LIKE '%' || ? || '%' OR synopsis LIKE '%' || ? || '%'
        UNION
        SELECT s.id, s.title, s.synopsis, s.cover_asset
        FROM pages p
        JOIN stories s ON s.id = p.story_id
        WHERE p.text_plain LIKE '%' || ? || '%'
        GROUP BY id
        ORDER BY title COLLATE NOCASE;
      ''', [q, q, q]);
    }
  }

  // -------------------- Utilities --------------------

  /// Hapus database (untuk pengujian/development).
  Future<void> deleteDb() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    await deleteDatabase(path);
    _db = null;
  }
}
