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
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createV1(db);
        await _seedInitialStories(db);
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

  Future<void> _createV1(Database db) async {
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

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stories_title ON stories(title);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stories_locale ON stories(locale);',
    );

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_stories_touch
      AFTER UPDATE ON stories
      WHEN NEW.updated_at = OLD.updated_at
      BEGIN
        UPDATE stories SET updated_at = strftime('%s','now') WHERE id = NEW.id;
      END;
    ''');

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

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pages_story ON pages(story_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pages_story_order ON pages(story_id, page_no);',
    );

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_pages_touch
      AFTER UPDATE ON pages
      WHEN NEW.updated_at = OLD.updated_at
      BEGIN
        UPDATE pages SET updated_at = strftime('%s','now') WHERE id = NEW.id;
      END;
    ''');

    await db.execute('''
      CREATE VIEW IF NOT EXISTS v_story_with_counts AS
      SELECT s.*,
             (SELECT COUNT(*) FROM pages p WHERE p.story_id = s.id) AS page_count
      FROM stories s;
    ''');
  }

  Future<void> _createV2Fts(Database db) async {
    try {
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

      await db.execute(
        "INSERT INTO stories_fts(stories_fts) VALUES ('rebuild');",
      );
      await db.execute("INSERT INTO pages_fts(pages_fts) VALUES ('rebuild');");
    } catch (_) {
    }
  }

  /// Mengisi 2 cerita awal (Malin Kundang, Nenek Tua & Ikan Gabus)
  /// memakai schema pertama: data inti ke `stories`, isi teks jadi `pages`.
  Future<void> _seedInitialStories(Database db) async {
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM stories'),
        ) ??
        0;
    if (count > 0) return;

    Future<int> addStoryFromSimple({
      required String slug,
      required String title,
      String subtitle = '',
      String synopsis = '',
      String author = 'Cerita Rakyat Indonesia',
      String coverAsset = '',
      String locale = 'id',

      required String content,
    }) async {
      final id = await db.insert('stories', {
        'slug': slug,
        'title': title,
        'subtitle': subtitle,
        'synopsis': synopsis.isNotEmpty ? synopsis : subtitle,
        'cover_asset': coverAsset,
        'author': author,
        'locale': locale,
      });


      final parts = _splitToTwoPages(content);
      await db.insert('pages', {
        'story_id': id,
        'page_no': 1,
        'text_plain': parts.$1,
        'image_asset': _page1ImageFor(coverAsset),
      });
      await db.insert('pages', {
        'story_id': id,
        'page_no': 2,
        'text_plain': parts.$2,
        'image_asset': _page2ImageFor(coverAsset),
      });
      return id;
    }

    await db.transaction((txn) async {

      await addStoryFromSimple(
        slug: 'malin-kundang',
        title: 'Malin Kundang',
        subtitle: 'Legenda anak durhaka dari Minangkabau',
        synopsis:
            'Anak yang merantau dan lupa pada ibunya hingga mendapat kutukan.',
        coverAsset: 'assets/images/covers/malin.png',
        content: _malinText,
      );


      await addStoryFromSimple(
        slug: 'nenek-tua-dan-ikan-gabus',
        title: 'Nenek Tua dan Ikan Gabus',
        subtitle: 'Kebaikan yang dibalas keajaiban',
        synopsis:
            'Seorang nenek menolong ikan gabus—kebaikan hati membawa berkah.',
        coverAsset: 'assets/images/covers/nenek_ikan_gabus.png',
        content: _nenekText,
      );
    });
  }

  Future<List<Map<String, dynamic>>> getStoryList() async {
    final db = await database;
    return db.rawQuery('''
      SELECT id, slug, title, synopsis, cover_asset, page_count
      FROM v_story_with_counts
      ORDER BY title COLLATE NOCASE;
    ''');
  }

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
        'duration_ms',
      ],
      where: 'story_id = ?',
      whereArgs: [storyId],
      orderBy: 'page_no ASC',
    );
  }

  Future<List<Map<String, dynamic>>> search(String rawQuery) async {
    final db = await database;
    final q = rawQuery.trim();
    if (q.isEmpty) return [];
    try {
      return await db.rawQuery(
        '''
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
      ''',
        [q, q],
      );
    } catch (_) {
      return db.rawQuery(
        '''
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
      ''',
        [q, q, q],
      );
    }
  }

 Future<int> upsertStoryWithPages({
    required String slug,
    required Map<String, dynamic> story,
    required List<Map<String, dynamic>> pages,
    bool replacePages = true,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      // cek existing story
      final existing = await txn.query(
        'stories',
        columns: ['id'],
        where: 'slug = ?',
        whereArgs: [slug],
        limit: 1,
      );

      if ((story['cover_asset'] as String?)?.isEmpty ?? true) {
        story['cover_asset'] = 'assets/images/covers/placeholder.png';
      }
      story['slug'] = slug;

      late final int storyId;
      if (existing.isEmpty) {
        storyId = await txn.insert('stories', story);
      } else {
        storyId = existing.first['id'] as int;
        await txn.update(
          'stories',
          story,
          where: 'id = ?',
          whereArgs: [storyId],
        );
        if (replacePages) {
          await txn.delete(
            'pages',
            where: 'story_id = ?',
            whereArgs: [storyId],
          );
        }
      }

      pages.sort((a, b) => (a['page_no'] ?? 0).compareTo(b['page_no'] ?? 0));

      if (replacePages) {
        for (final p in pages) {
          await txn.insert('pages', {
            'story_id': storyId,
            'page_no': p['page_no'] ?? 1,
            'text_plain': p['text'] ?? '',
            'text_rich_html': p['text_rich_html'],
            'image_asset': p['image'] ?? '',
            'tts_ssml': p['tts_ssml'],
            'duration_ms': p['duration_ms'],
            'word_timing_json': p['word_timing_json'],
          });
        }
      } else {
        for (final p in pages) {
          await txn.rawInsert(
            '''
            INSERT INTO pages(
              story_id, page_no, text_plain, text_rich_html, image_asset, tts_ssml, duration_ms, word_timing_json
            ) VALUES(?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(story_id, page_no) DO UPDATE SET
              text_plain       = excluded.text_plain,
              text_rich_html   = excluded.text_rich_html,
              image_asset      = excluded.image_asset,
              tts_ssml         = excluded.tts_ssml,
              duration_ms      = excluded.duration_ms,
              word_timing_json = excluded.word_timing_json
          ''',
            [
              storyId,
              p['page_no'] ?? 1,
              p['text'] ?? '',
              p['text_rich_html'],
              p['image'] ?? '',
              p['tts_ssml'],
              p['duration_ms'],
              p['word_timing_json'],
            ],
          );
        }
      }

      try {
        await txn.execute(
          "INSERT INTO stories_fts(stories_fts) VALUES('rebuild');",
        );
        await txn.execute(
          "INSERT INTO pages_fts(pages_fts) VALUES('rebuild');",
        );
      } catch (_) {}

      return storyId;
    });
  }

  Future<void> deleteDb() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    await deleteDatabase(path);
    _db = null;
  }
}

(String, String) _splitToTwoPages(String content) {
  final parts = content.trim().split(RegExp(r'\n\s*\n'));
  if (parts.length <= 1) {
    final mid = (content.length / 2).floor();
    return (content.substring(0, mid).trim(), content.substring(mid).trim());
  }
  final first = parts.first.trim();
  final rest = parts.skip(1).join('\n\n').trim();
  return (first, rest.isEmpty ? '...' : rest);
}

String _page1ImageFor(String coverAsset) => 'assets/images/ui/page1.png';
String _page2ImageFor(String coverAsset) => 'assets/images/ui/page2.png';

// -------------------- Konten gaya “kode kedua” --------------------
const String _malinText =
    'Alkisah, Malin Kundang merantau dan lupa pada ibunya... '
    'Pada akhirnya ia dikutuk menjadi batu di tepi pantai.';

const String _nenekText =
    'Seorang nenek menolong seekor ikan gabus yang ternyata jelmaan... '
    'Kebaikan hati membawa berkah bagi sang nenek.';
