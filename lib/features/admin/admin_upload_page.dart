// lib/features/admin/admin_upload_page.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:jejak_cerita_rakyat/providers/story_provider.dart';

import 'story_import_service.dart';

/// Daftar asset JSON yang tersedia (update sesuai file kamu).
const kStoryAssetJsons = <String>[
  'assets/stories/petualangan_garuda.json',
  'assets/stories/F1_story.json',
  'assets/stories/F2_story.json',
];

class AdminUploadPage extends StatefulWidget {
  const AdminUploadPage({super.key});

  @override
  State<AdminUploadPage> createState() => _AdminUploadPageState();
}

class _AdminUploadPageState extends State<AdminUploadPage> {
  bool _busy = false;
  String? _log;
  String? _selectedAsset = kStoryAssetJsons.isNotEmpty
      ? kStoryAssetJsons.first
      : null;

  Future<void> _importFromStorage() async {
    final svc = StoryImportService();
    try {
      setState(() {
        _busy = true;
        _log = null;
      });
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) {
        setState(() {
          _log = 'Dibatalkan.';
          _busy = false;
        });
        return;
      }
      final f = result.files.single;
      if (f.path == null) {
        setState(() {
          _log = 'Tidak ada path file (coba pilih lagi).';
          _busy = false;
        });
        return;
      }

      final id = await svc.importFromJsonFile(f.path!);

      await context.read<StoryProvider>().refresh();

      setState(() {
        _log =
            'Berhasil import dari storage: storyId=$id (${p.basename(f.path!)})';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil import: ${p.basename(f.path!)}')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _log = 'Gagal import: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _importFromAsset() async {
    if (_selectedAsset == null) return;
    final svc = StoryImportService();
    try {
      setState(() {
        _busy = true;
        _log = null;
      });
      final id = await svc.importFromJsonAsset(_selectedAsset!);

      await context.read<StoryProvider>().refresh();

      setState(() {
        _log = 'Berhasil import dari asset: storyId=$id ($_selectedAsset)';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil import asset: $_selectedAsset')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _log = 'Gagal import: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Data Cerita')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Opsi 1: Storage
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: outline, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dari Storage',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Pilih file .json dari penyimpanan perangkat.'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _importFromStorage,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_busy ? 'Memproses...' : 'Pilih JSON & Import'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Opsi 2: Assets
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: outline, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dari Assets',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (kStoryAssetJsons.isEmpty)
                    const Text(
                      'Tidak ada daftar asset JSON. Tambahkan di kStoryAssetJsons.',
                    )
                  else ...[
                    DropdownButton<String>(
                      value: _selectedAsset,
                      isExpanded: true,
                      items: kStoryAssetJsons
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _selectedAsset = v),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _busy ? null : _importFromAsset,
                      icon: const Icon(Icons.library_add_check_outlined),
                      label: Text(_busy ? 'Memproses...' : 'Import dari Asset'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_log != null)
              Text(_log!, style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}
