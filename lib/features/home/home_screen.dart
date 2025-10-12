// ignore_for_file: unnecessary_import
import 'dart:async';
import 'dart:io' show File;
import 'dart:ui' show Offset;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';

// >>> Map package
import 'package:countries_world_map/countries_world_map.dart';

import 'package:jejak_cerita_rakyat/features/detail/detail_screen.dart';
import 'package:jejak_cerita_rakyat/features/library/library_screen.dart';
import 'package:jejak_cerita_rakyat/providers/story_provider.dart';

import 'package:jejak_cerita_rakyat/features/settings/setting_screen.dart';

import 'widget/home_header_chip.dart';
import 'widget/fluid_story_card.dart';
import 'widget/section_title.dart';

const Map<String, Offset> kProvinceCenters = {
  // Sumatera
  'Aceh': Offset(0.060, 0.375),
  'Sumatera Utara': Offset(0.102, 0.395),
  'Sumatera Barat': Offset(0.152, 0.425),
  'Riau': Offset(0.180, 0.445),
  'Kepulauan Riau': Offset(0.195, 0.485),
  'Jambi': Offset(0.195, 0.475),
  'Sumatera Selatan': Offset(0.205, 0.515),
  'Bengkulu': Offset(0.170, 0.505),
  'Lampung': Offset(0.215, 0.565),
  'Bangka Belitung': Offset(0.230, 0.520),

  // Jawa
  'Banten': Offset(0.270, 0.585),
  'DKI Jakarta': Offset(0.290, 0.585),
  'Jawa Barat': Offset(0.305, 0.595),
  'Jawa Tengah': Offset(0.345, 0.600),
  'DI Yogyakarta': Offset(0.355, 0.615),
  'Jawa Timur': Offset(0.385, 0.605),

  // Bali & Nusa
  'Bali': Offset(0.4458, 0.7070),
  'Nusa Tenggara Barat': Offset(0.445, 0.625),
  'Nusa Tenggara Timur': Offset(0.495, 0.640),

  // Kalimantan
  'Kalimantan Barat': Offset(0.305, 0.475),
  'Kalimantan Tengah': Offset(0.350, 0.495),
  'Kalimantan Selatan': Offset(0.365, 0.535),
  'Kalimantan Timur': Offset(0.405, 0.485),
  'Kalimantan Utara': Offset(0.385, 0.455),

  // Sulawesi
  'Sulawesi Utara': Offset(0.515, 0.505),
  'Gorontalo': Offset(0.505, 0.520),
  'Sulawesi Tengah': Offset(0.505, 0.540),
  'Sulawesi Barat': Offset(0.490, 0.560),
  'Sulawesi Selatan': Offset(0.505, 0.575),
  'Sulawesi Tenggara': Offset(0.535, 0.585),

  // Maluku & Papua
  'Maluku': Offset(0.600, 0.610),
  'Maluku Utara': Offset(0.600, 0.560),
  'Papua Barat': Offset(0.670, 0.545),
  'Papua': Offset(0.735, 0.545),
};

/// =======================
/// Normalizer nama → id map
/// =======================

const Map<String, String> _aliasToCanonical = {
  'ntb': 'nusa tenggara barat',
  'ntt': 'nusa tenggara timur',
  'dki jakarta': 'dki jakarta',
  'di yogyakarta': 'di yogyakarta',
};

String _normalizeName(String raw) {
  var s = raw.toLowerCase().trim();
  if (s.startsWith('provinsi ')) {
    s = s.substring('provinsi '.length);
  }
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  if (_aliasToCanonical.containsKey(s)) s = _aliasToCanonical[s]!;
  return s;
}

// === PENTING: gunakan ISO-3166-2 (ID-XX) sesuai callback SimpleMap ===
const Map<String, String> _canonicalToMapId = {
  // Sumatera
  'aceh': 'ID-AC',
  'sumatera utara': 'ID-SU',
  'sumatera barat': 'ID-SB',
  'riau': 'ID-RI',
  'kepulauan riau': 'ID-KR',
  'jambi': 'ID-JA',
  'sumatera selatan': 'ID-SS',
  'bengkulu': 'ID-BE',
  'lampung': 'ID-LA',
  'bangka belitung': 'ID-BB',

  // Jawa
  'banten': 'ID-BT',
  'dki jakarta': 'ID-JK',
  'jawa barat': 'ID-JB',
  'jawa tengah': 'ID-JT',
  'di yogyakarta': 'ID-YO',
  'jawa timur': 'ID-JI',

  // Bali & Nusa
  'bali': 'ID-BA',
  'nusa tenggara barat': 'ID-NB',
  'nusa tenggara timur': 'ID-NT',

  // Kalimantan
  'kalimantan barat': 'ID-KB',
  'kalimantan tengah': 'ID-KT',
  'kalimantan selatan': 'ID-KS',
  'kalimantan timur': 'ID-KI',
  'kalimantan utara': 'ID-KU',

  // Sulawesi
  'sulawesi utara': 'ID-SA',
  'gorontalo': 'ID-GO',
  'sulawesi tengah': 'ID-ST',
  'sulawesi barat': 'ID-SR',
  'sulawesi selatan': 'ID-SN',
  'sulawesi tenggara': 'ID-SG',

  // Maluku & Papua (versi baru)
  'maluku utara': 'ID-MU',
  'maluku': 'ID-MA',
  'papua barat daya': 'ID-PD',
  'papua barat': 'ID-PB',
  'papua tengah': 'ID-PT',
  'papua selatan': 'ID-PS',
  'papua pegunungan': 'ID-PP',

  // Papua (fallback peta lama)
  'papua': 'ID-PA',
};

String? _mapIdForName(String nameFromData) {
  final canon = _normalizeName(nameFromData);
  return _canonicalToMapId[canon];
}

/// Map nama provinsi (dipakai di beberapa tempat) → ISO-3166-2
const Map<String, String> kIndoNameToMapId = {
  // Sumatera
  'Aceh': 'ID-AC',
  'Sumatera Utara': 'ID-SU',
  'Sumatera Barat': 'ID-SB',
  'Riau': 'ID-RI',
  'Kepulauan Riau': 'ID-KR',
  'Jambi': 'ID-JA',
  'Sumatera Selatan': 'ID-SS',
  'Bengkulu': 'ID-BE',
  'Lampung': 'ID-LA',
  'Bangka Belitung': 'ID-BB',

  // Jawa
  'Banten': 'ID-BT',
  'DKI Jakarta': 'ID-JK',
  'Jawa Barat': 'ID-JB',
  'Jawa Tengah': 'ID-JT',
  'DI Yogyakarta': 'ID-YO',
  'Jawa Timur': 'ID-JI',

  // Bali & Nusa
  'Bali': 'ID-BA',
  'Nusa Tenggara Barat': 'ID-NB',
  'Nusa Tenggara Timur': 'ID-NT',

  // Kalimantan
  'Kalimantan Barat': 'ID-KB',
  'Kalimantan Tengah': 'ID-KT',
  'Kalimantan Selatan': 'ID-KS',
  'Kalimantan Timur': 'ID-KI',
  'Kalimantan Utara': 'ID-KU',

  // Sulawesi
  'Sulawesi Utara': 'ID-SA',
  'Gorontalo': 'ID-GO',
  'Sulawesi Tengah': 'ID-ST',
  'Sulawesi Barat': 'ID-SR',
  'Sulawesi Selatan': 'ID-SN',
  'Sulawesi Tenggara': 'ID-SG',

  // Maluku & Papua
  'Maluku Utara': 'ID-MU',
  'Maluku': 'ID-MA',
  'Papua Barat Daya': 'ID-PD',
  'Papua Barat': 'ID-PB',
  'Papua Tengah': 'ID-PT',
  'Papua Selatan': 'ID-PS',
  'Papua Pegunungan': 'ID-PP',
  'Papua': 'ID-PA',
};

/// =======================
/// Konten info provinsi (opsional)
/// =======================
const Map<String, String> kProvinceInfo = {
  'Jawa Timur':
      '🌋 **Jawa Timur — Tanah Legenda dan Petualangan!**\n\n'
      'Dari puncak Gunung Bromo yang gagah hingga ombak Pantai Papuma yang memesona, Jawa Timur menyimpan sejuta cerita!\n'
      'Di sinilah lahir kisah *Roro Anteng dan Joko Seger*, *Jaka Tarub*, hingga *Ande-Ande Lumut*—cerita rakyat penuh keajaiban dan pesan moral.\n\n'
      'Anak-anak bisa belajar tentang keberanian, kejujuran, dan kasih sayang.\n'
      'Orang dewasa pun bisa bernostalgia dengan budaya dan sejarah Nusantara yang masih hidup hingga kini.\n\n'
      '✨ *Jelajahi Jawa Timur, temukan jejak cerita yang menunggu untuk dibaca dan didengar!*',
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _current = 0;
  static const double _cardHeight = 340;
  static const double _cardRadiusMask = 22;

  // -> atur tinggi peta di sini
  static const double _mapScale = 1.00;
  static const double _mapContentVPad = 70; // tambah = peta lebih tinggi
  static const double _mapExtraHeight = 30;

  static const String _defaultCoverPath =
      'assets/images/covers/default_cover.png';

  double? _svgAspect;
  bool _debugTap = false;
  bool _didKick = false;

  // Data & filter
  List<StoryItem> _featuredValid = [];
  List<StoryItem> _visibleStories = [];
  Map<String, List<StoryItem>> _provIndex = {};
  String? _selectedProvince;

  String _storiesKey = '';
  int _validateEpoch = 0;
  bool _validating = false;

  // === Simple search (ditoggle dari ikon di header)
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  String _searchQuery = '';
  List<StoryItem> _searchResults = [];
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Hindari use_build_context_synchronously: ambil provider dulu
      final sp = context.read<StoryProvider>();
      await sp.loadProvincePins();
      await _loadSvgAspect();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSvgAspect() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/svg/map_indonesia_simplified.svg',
      );

      final vb = RegExp(
        r'''viewBox\s*=\s*["']\s*[-\d.]+\s+[-\d.]+\s+([\d.]+)\s+([\d.]+)\s*["']''',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(raw);

      if (vb != null) {
        final w = double.tryParse(vb.group(1)!);
        final h = double.tryParse(vb.group(2)!);
        if (w != null && h != null && w > 0 && h > 0) {
          setState(() => _svgAspect = w / h);
          return;
        }
      }
      final wAttr = RegExp(
        r'''width\s*=\s*["']\s*([\d.]+)\s*["']''',
        caseSensitive: false,
      ).firstMatch(raw);
      final hAttr = RegExp(
        r'''height\s*=\s*["']\s*([\d.]+)\s*["']''',
        caseSensitive: false,
      ).firstMatch(raw);
      if (wAttr != null && hAttr != null) {
        final w = double.tryParse(wAttr.group(1)!);
        final h = double.tryParse(hAttr.group(1)!);
        if (w != null && h != null && w > 0 && h > 0) {
          setState(() => _svgAspect = w / h);
          return;
        }
      }
      setState(() => _svgAspect = 16 / 9);
    } catch (_) {
      setState(() => _svgAspect = 16 / 9);
    }
  }

  // -------- Validasi cover + bangun index provinsi --------
  bool _hasCoverString(StoryItem s) {
    final p = (s.coverAsset).trim(); // <— aman & tidak perlu cek null
    if (p.isEmpty) return false;
    if ((p.startsWith('"') && p.endsWith('"')) ||
        (p.startsWith("'") && p.endsWith("'"))) {
      final content = p.substring(1, p.length - 1).trim();
      if (content.isEmpty) return false;
      if (content == _defaultCoverPath) return false;
      return true;
    }
    if (p == _defaultCoverPath) return false;
    return true;
  }

  Future<bool> _coverLoads(BuildContext ctx, String rawPath) async {
    String path = rawPath.trim();
    if ((path.startsWith('"') && path.endsWith('"')) ||
        (path.startsWith("'") && path.endsWith("'"))) {
      path = path.substring(1, path.length - 1).trim();
    }
    if (path.isEmpty || path == _defaultCoverPath) return false;

    final lower = path.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      bool failed = false;
      try {
        await precacheImage(
          NetworkImage(path),
          ctx,
          onError: (Object _, StackTrace? __) {
            failed = true;
          },
        );
        return !failed;
      } catch (_) {
        return false;
      }
    }
    if (lower.startsWith('assets/')) {
      try {
        await rootBundle.load(path);
        return true;
      } catch (_) {
        return false;
      }
    }
    try {
      final f = File(path);
      return f.existsSync();
    } catch (_) {
      return false;
    }
  }

  String _makeStoriesKey(List<StoryItem> stories) =>
      stories.map((s) => '${s.id}:${s.coverAsset}').join('|');

  void _scheduleValidateFeatured(BuildContext ctx, List<StoryItem> allStories) {
    final candidates = allStories.where(_hasCoverString).toList();
    final key = _makeStoriesKey(candidates);
    if (key == _storiesKey && _featuredValid.isNotEmpty) return;
    _storiesKey = key;

    if (_validating) return;
    _validating = true;
    final myEpoch = ++_validateEpoch;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = <StoryItem>[];
      final limit = candidates.length.clamp(0, 50);
      for (int i = 0; i < limit; i++) {
        final s = candidates[i];
        final p = s.coverAsset.trim();
        final good = await _coverLoads(ctx, p);
        if (good) ok.add(s);
      }

      final provIndex = <String, List<StoryItem>>{};
      final sp = context.read<StoryProvider>();
      for (final s in ok) {
        final pins = await sp.pinsForStoryId(s.id);
        for (final p in pins) {
          (provIndex[p.name] ??= <StoryItem>[]).add(s);
        }
      }

      if (!mounted) return;
      if (myEpoch != _validateEpoch) return;

      final visible = _selectedProvince == null
          ? ok.take(10).toList()
          : (provIndex[_selectedProvince] ?? const <StoryItem>[]);

      setState(() {
        _featuredValid = ok.take(10).toList();
        _visibleStories = visible;
        _provIndex = provIndex;
        _validating = false;
      });
    });
  }

  void _clearProvinceFilter() {
    setState(() {
      _selectedProvince = null;
      _visibleStories = _featuredValid;
      _current = 0;
    });
  }

  // ===== Simple search logic (filter judul) =====
  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      final all = context.read<StoryProvider>().stories;
      final qq = q.trim().toLowerCase();

      List<StoryItem> res = [];
      if (qq.isNotEmpty) {
        res = all.where((s) {
          final title = (s.title).toLowerCase();
          return title.contains(qq);
        }).toList();

        res.sort((a, b) {
          final ta = (a.title).toLowerCase();
          final tb = (b.title).toLowerCase();
          final aStarts = ta.startsWith(qq) ? 0 : 1;
          final bStarts = tb.startsWith(qq) ? 0 : 1;
          if (aStarts != bStarts) return aStarts - bStarts;
          return ta.compareTo(tb);
        });
      }

      setState(() {
        _searchQuery = q;
        _searchResults = res;
        _current = 0;
      });
    });
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
    });
    if (_showSearchBar) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _searchFocus.requestFocus();
      });
    } else {
      _searchCtrl.clear();
      _onSearchChanged('');
      _searchFocus.unfocus();
    }
  }

  Future<void> _showProvincePicker() async {
    final entries = _provIndex.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Belum ada cerita ber-cover untuk ditampilkan per wilayah.',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final h = MediaQuery.of(ctx).size.height * 0.60;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            Center(
              child: Container(
                height: h,
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Pilih Wilayah',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (_selectedProvince != null)
                              TextButton.icon(
                                onPressed: () => Navigator.of(ctx).pop(''),
                                icon: const Icon(Icons.close),
                                label: const Text('Hapus filter'),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: entries.length,
                          itemBuilder: (_, i) {
                            final name = entries[i].key;
                            final count = entries[i].value.length;
                            final selected = _selectedProvince == name;

                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Material(
                                color: selected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.08,
                                      )
                                    : theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.of(ctx).pop(name),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.place_rounded,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text('$count'),
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: theme
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.10),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        if (selected) ...[
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.check_rounded,
                                            size: 18,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || selected == null) return;
    if (selected.isEmpty) {
      _clearProvinceFilter();
      return;
    }

    final list = _provIndex[selected] ?? const <StoryItem>[];
    setState(() {
      _selectedProvince = selected;
      _visibleStories = list;
      _current = 0;
    });

    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Belum ada cerita untuk $selected'),
        ),
      );
    }
  }

  // === Helper: warna highlight untuk SimpleMap (MERAH) ===
  Map<String, Color> _buildRegionColorsForPins(
    BuildContext context,
    List<ProvincePin> pins,
  ) {
    const Color highlight = Colors.red;
    final Map<String, Color> out = {};
    for (final p in pins) {
      final id = _mapIdForName(p.name) ?? kIndoNameToMapId[p.name];
      if (id != null) {
        out[id] = highlight;
      } else {
        // ignore: avoid_print
        print(
          'MapId NOT FOUND for "${p.name}" (normalized: "${_normalizeName(p.name)}")',
        );
      }
    }
    return out;
  }

  // === Bottom sheet: daftar cerita per provinsi ===
  Future<void> _showProvinceStoriesSheet(String provinceName) async {
    final list = _provIndex[provinceName] ?? const <StoryItem>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final h = MediaQuery.of(ctx).size.height * 0.70;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            Center(
              child: Container(
                height: h,
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Cerita di $provinceName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Tutup',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: list.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Belum ada cerita ber-cover untuk provinsi ini.',
                                    style: theme.textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  16,
                                ),
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final s = list[i];
                                  final String p = (s.coverAsset).trim();
                                  Widget thumb;
                                  if (p.toLowerCase().startsWith('assets/')) {
                                    thumb = Image.asset(p, fit: BoxFit.cover);
                                  } else if (p.toLowerCase().startsWith(
                                    'http',
                                  )) {
                                    thumb = Image.network(p, fit: BoxFit.cover);
                                  } else {
                                    thumb = const ColoredBox(
                                      color: Colors.black12,
                                    );
                                  }

                                  return Material(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        Navigator.of(ctx).pop();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                DetailScreen(data: s),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: SizedBox(
                                                width: 64,
                                                height: 90,
                                                child: thumb,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                s.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoryProvider>();
    final stories = provider.stories;

    _scheduleValidateFeatured(context, stories);

    final featured = _searchQuery.trim().isNotEmpty
        ? _searchResults
        : _visibleStories;
    final currentStory = (featured.isNotEmpty)
        ? featured[_current.clamp(0, featured.length - 1)]
        : null;

    if (_svgAspect != null && !_didKick) {
      _didKick = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }

    final mapKey = ValueKey(
      'map-${_selectedProvince ?? currentStory?.id}-${_svgAspect?.toStringAsFixed(6) ?? 'null'}',
    );
    final aspect = _svgAspect ?? (16 / 9);

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_showSearchBar) {
          _toggleSearchBar();
          return;
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/splash/splash.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                opacity: const AlwaysStoppedAnimation(0.35),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: HomeHeaderChip(
                      onTapSearch: _toggleSearchBar,
                      onTapSettings: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: !_showSearchBar
                        ? const SizedBox.shrink()
                        : Padding(
                            key: const ValueKey('searchbar'),
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                            child: _SearchField(
                              controller: _searchCtrl,
                              focusNode: _searchFocus,
                              onChanged: _onSearchChanged,
                              onClear: () {
                                _searchCtrl.clear();
                                _onSearchChanged('');
                                _searchFocus.requestFocus();
                              },
                              onClose: _toggleSearchBar,
                            ),
                          ),
                  ),

                  const SizedBox(height: 8),
                  SectionTitle(
                    title: _searchQuery.trim().isNotEmpty
                        ? 'Hasil Pencarian'
                        : 'Cerita Pilihan',
                    showUnderline: false,
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        if (featured.isNotEmpty)
                          SizedBox(
                            height: _cardHeight,
                            child: CarouselSlider.builder(
                              itemCount: featured.length,
                              options: CarouselOptions(
                                height: _cardHeight,
                                viewportFraction: 0.68,
                                padEnds: true,
                                enlargeCenterPage: true,
                                enlargeStrategy:
                                    CenterPageEnlargeStrategy.height,
                                enlargeFactor: 0.42,
                                onPageChanged: (i, _) {
                                  setState(() {
                                    _current = i;
                                  });
                                },
                              ),
                              itemBuilder: (ctx, i, _) {
                                final it = featured[i];
                                final isSelected = i == _current;
                                return AnimatedPadding(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: isSelected ? 0 : 18,
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      FluidStoryCard(story: it),
                                      if (!isSelected)
                                        const _GoldBorderMask(
                                          radius: _cardRadiusMask,
                                        ),
                                      Positioned.fill(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      DetailScreen(data: it),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        else if (_searchQuery.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 24,
                            ),
                            child: Center(
                              child: Text(
                                'Tidak ada hasil untuk "${_searchQuery.trim()}".',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),

                        const SizedBox(height: 16),

                        // MAP (pin sesuai card yang sedang dipilih)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Builder(
                            builder: (context) {
                              final double baseWidth =
                                  MediaQuery.of(context).size.width - 32;

                              final double desiredWidth = baseWidth * _mapScale;
                              final double desiredHeight =
                                  desiredWidth / aspect;
                              final double cardHeight =
                                  desiredHeight + (2 * _mapContentVPad);
                              final double totalHeight =
                                  cardHeight + _mapExtraHeight;

                              return SizedBox(
                                width: double.infinity,
                                height: totalHeight,
                                child: Center(
                                  child: OverflowBox(
                                    alignment: Alignment.center,
                                    minWidth: 0,
                                    maxWidth: desiredWidth,
                                    minHeight: 0,
                                    maxHeight: cardHeight,
                                    child: SizedBox(
                                      width: desiredWidth,
                                      height: cardHeight,
                                      child: Stack(
                                        children: [
                                          KeyedSubtree(
                                            key: mapKey,
                                            child: _MapCard(
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    vertical: _mapContentVPad,
                                                  ),
                                              builder: (context) => Stack(
                                                children: [
                                                  if (currentStory != null)
                                                    Positioned.fill(
                                                      child: FutureBuilder<List<ProvincePin>>(
                                                        key: ValueKey<int>(
                                                          currentStory.id,
                                                        ),
                                                        future: context
                                                            .read<
                                                              StoryProvider
                                                            >()
                                                            .pinsForStoryId(
                                                              currentStory.id,
                                                            ),
                                                        builder: (context, snap) {
                                                          final pins =
                                                              snap.data ??
                                                              const <
                                                                ProvincePin
                                                              >[];
                                                          final regionColors =
                                                              _buildRegionColorsForPins(
                                                                context,
                                                                pins,
                                                              );

                                                          final Set<String>
                                                          highlightedIds = {
                                                            for (final p
                                                                in pins)
                                                              (_mapIdForName(
                                                                        p.name,
                                                                      ) ??
                                                                      kIndoNameToMapId[p
                                                                          .name]) ??
                                                                  '',
                                                          }..removeWhere((e) => e.isEmpty);

                                                          return Stack(
                                                            children: [
                                                              Positioned.fill(
                                                                child: SimpleMap(
                                                                  instructions:
                                                                      SMapIndonesia
                                                                          .instructions,
                                                                  defaultColor:
                                                                      Colors
                                                                          .green,
                                                                  colors:
                                                                      regionColors,
                                                                  callback:
                                                                      (
                                                                        id,
                                                                        name,
                                                                        details,
                                                                      ) {
                                                                        if (highlightedIds
                                                                            .contains(
                                                                              id,
                                                                            )) {
                                                                          _showProvinceStoriesSheet(
                                                                            name,
                                                                          );
                                                                        }
                                                                      },
                                                                ),
                                                              ),
                                                              if (pins
                                                                  .isNotEmpty)
                                                                Positioned.fill(
                                                                  child: _ProvinceLabelsOverlay(
                                                                    contentAspect:
                                                                        aspect,
                                                                    labels: [
                                                                      for (final p
                                                                          in pins)
                                                                        if (kProvinceCenters[p.name] !=
                                                                            null)
                                                                          (
                                                                            p.name,
                                                                            kProvinceCenters[p.name]!.dx,
                                                                            kProvinceCenters[p.name]!.dy,
                                                                          ),
                                                                    ],
                                                                    onTap: (nm) {
                                                                      final id =
                                                                          _mapIdForName(
                                                                            nm,
                                                                          ) ??
                                                                          kIndoNameToMapId[nm];
                                                                      if (id !=
                                                                              null &&
                                                                          highlightedIds.contains(
                                                                            id,
                                                                          )) {
                                                                        _showProvinceStoriesSheet(
                                                                          nm,
                                                                        );
                                                                      }
                                                                    },
                                                                  ),
                                                                ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                    )
                                                  else
                                                    Positioned.fill(
                                                      child: SimpleMap(
                                                        instructions:
                                                            SMapIndonesia
                                                                .instructions,
                                                        defaultColor:
                                                            Colors.green,
                                                        colors: const {},
                                                        callback:
                                                            (
                                                              id,
                                                              name,
                                                              details,
                                                            ) {},
                                                      ),
                                                    ),

                                                  Positioned.fill(
                                                    child: GestureDetector(
                                                      behavior: HitTestBehavior
                                                          .translucent,
                                                      onLongPress: () =>
                                                          setState(
                                                            () => _debugTap =
                                                                !_debugTap,
                                                          ),
                                                    ),
                                                  ),
                                                  if (_debugTap)
                                                    Positioned.fill(
                                                      child:
                                                          _TapToRelOverlayAdaptive(
                                                            contentAspect:
                                                                aspect,
                                                            onRelTap: (xr, yr) =>
                                                                _copyAndToast(
                                                                  xr,
                                                                  yr,
                                                                ),
                                                          ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          if (_selectedProvince != null)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: ActionChip(
                                                label: const Text(
                                                  'Hapus filter',
                                                ),
                                                avatar: const Icon(
                                                  Icons.close,
                                                  size: 18,
                                                ),
                                                onPressed: _clearProvinceFilter,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: _BottomBarWithRegion(
                      onTapRegion: _showProvincePicker,
                      onTapList: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LibraryScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyAndToast(double x, double y) {
    final txt =
        '"x_rel": ${x.toStringAsFixed(4)}, "y_rel": ${y.toStringAsFixed(4)}';
    Clipboard.setData(ClipboardData(text: txt));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $txt'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// --- UI helpers ---

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onClose,
    this.focusNode,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari judul cerita...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: onClear,
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: cs.outline.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: cs.outline.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Tutup',
          onPressed: onClose,
          icon: const Icon(Icons.expand_less_rounded),
        ),
      ],
    );
  }
}

class _GoldBorderMask extends StatelessWidget {
  const _GoldBorderMask({this.radius = 22});
  final double radius;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: surface, width: 2.0),
          ),
        ),
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.builder,
    this.contentPadding = EdgeInsets.zero,
  });
  final WidgetBuilder builder;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  cs.surfaceContainerHighest.withValues(alpha: 0.10),
                ],
              ),
            ),
          ),
          Container(color: cs.surface.withValues(alpha: 0.08)),
          Positioned.fill(
            child: Padding(padding: contentPadding, child: builder(context)),
          ),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TapToRelOverlayAdaptive extends StatelessWidget {
  final double contentAspect;
  final void Function(double xRel, double yRel) onRelTap;

  const _TapToRelOverlayAdaptive({
    required this.contentAspect,
    required this.onRelTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final W = c.maxWidth, H = c.maxHeight;
        final boxAspect = W / H;
        double innerW = W, innerH = H, offX = 0, offY = 0;

        if (boxAspect > contentAspect) {
          innerH = H;
          innerW = H * contentAspect;
          offX = (W - innerW) / 2;
        } else if (boxAspect < contentAspect) {
          innerW = W;
          innerH = W / contentAspect;
          offY = (H - innerH) / 2;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final lx = (d.localPosition.dx - offX).clamp(0.0, innerW);
            final ly = (d.localPosition.dy - offY).clamp(0.0, innerH);
            final xr = (lx / innerW).clamp(0.0, 1.0);
            final yr = (ly / innerH).clamp(0.0, 1.0);
            onRelTap(xr, yr);
          },
          child: Container(color: Colors.transparent),
        );
      },
    );
  }
}

class _ProvinceLabelsOverlay extends StatelessWidget {
  final double contentAspect;
  final List<(String name, double x, double y)> labels;
  final void Function(String name)? onTap;

  const _ProvinceLabelsOverlay({
    required this.contentAspect,
    required this.labels,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final W = c.maxWidth, H = c.maxHeight;
        final boxAspect = W / H;
        double innerW = W, innerH = H, offX = 0, offY = 0;

        if (boxAspect > contentAspect) {
          innerH = H;
          innerW = H * contentAspect;
          offX = (W - innerW) / 2;
        } else if (boxAspect < contentAspect) {
          innerW = W;
          innerH = W / contentAspect;
          offY = (H - innerH) / 2;
        }

        return Stack(
          children: [
            for (final (name, xr, yr) in labels)
              Positioned(
                left: offX + xr * innerW - 40,
                top: offY + yr * innerH - 28,
                child: GestureDetector(
                  onTap: onTap == null ? null : () => onTap!(name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BottomBarWithRegion extends StatelessWidget {
  const _BottomBarWithRegion({
    required this.onTapRegion,
    required this.onTapList,
  });

  final VoidCallback onTapRegion;
  final VoidCallback onTapList;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Material(
            color: cs.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTapRegion,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map_rounded),
                    const SizedBox(width: 8),
                    Text(
                      'Wilayah',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Material(
            color: cs.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTapList,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.menu_book_rounded),
                    const SizedBox(width: 8),
                    Text(
                      'Daftar Cerita',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
