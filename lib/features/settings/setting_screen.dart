import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jejak_cerita_rakyat/providers/settings_provider.dart';
// import 'package:jejak_cerita_rakyat/features/admin/admin_upload_page.dart';
// import 'package:jejak_cerita_rakyat/features/tts_demo/tts_demo_screen.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const listFont = ['Atkinson', 'OpenDyslexic'];
    const double kFontChipWidth = 170; // lebar seragam untuk kotak pilihan font

    // ==== Clamp text scale khusus halaman Setting ====
    // OpenDyslexic di 1.6 bisa bikin layout kontrol padat; kita batasi lokal ke 1.55.
    final mq = MediaQuery.of(context);
    final clampedScaler = mq.textScaler.clamp(
      minScaleFactor: 0.8,
      maxScaleFactor: 1.55,
    );

    return MediaQuery(
      data: mq.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: cs.surface,
        body: Stack(
          children: [
            // background biar nyatu dengan home/detail
            Positioned.fill(
              child: Image.asset(
                'assets/images/splash/splash.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                opacity: const AlwaysStoppedAnimation(0.35),
              ),
            ),

            SafeArea(
              child: Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  return CustomScrollView(
                    slivers: [
                      // ===== Header glass =====
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: _GlassBar(
                            title: 'Pengaturan',
                            leading: _GlassCircleButton(
                              icon: Icons.arrow_back_rounded,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            actions: [
                              // tempat action lain jika diperlukan
                            ],
                          ),
                        ),
                      ),

                      // ===== Section: Tampilan =====
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _LabeledGlassCard(
                            label: 'Tampilan',
                            child: Column(
                              children: [
                                // Mode gelap (switch dirapatkan ke kanan via _SettingRow)
                                _SettingRow(
                                  label: 'Mode Gelap',
                                  trailing: Builder(
                                    builder: (ctx) {
                                      // Baca tema efektif yang sedang terpakai, supaya switch selalu sinkron.
                                      final isDarkNow =
                                          Theme.of(ctx).brightness ==
                                          Brightness.dark;
                                      return Switch(
                                        value: isDarkNow,
                                        onChanged: (v) => settings.setThemeMode(
                                          v ? ThemeMode.dark : ThemeMode.light,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const Divider(height: 24, thickness: 0.6),

                                // Jenis huruf (DITUMPUK atas–bawah, kotak seragam ukuran)
                                _SettingRow(
                                  label: 'Jenis Huruf',
                                  trailing: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      for (
                                        int i = 0;
                                        i < listFont.length;
                                        i++
                                      ) ...[
                                        SizedBox(
                                          width: kFontChipWidth,
                                          child: ChoiceChip(
                                            label: Center(
                                              child: Text(
                                                listFont[i],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            selected:
                                                settings.fontFamily ==
                                                listFont[i],
                                            onSelected: (_) => settings
                                                .setFontFamily(listFont[i]),
                                            labelStyle: TextStyle(
                                              fontWeight:
                                                  (settings.fontFamily ==
                                                      listFont[i])
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (i != listFont.length - 1)
                                          const SizedBox(height: 8),
                                      ],
                                    ],
                                  ),
                                ),
                                const Divider(height: 24, thickness: 0.6),

                                // Skala huruf
                                _SettingRow(
                                  label: 'Skala Huruf',
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _MiniGlassIcon(
                                        icon: Icons.remove,
                                        onTap: () {
                                          final v = (settings.textScale - 0.1)
                                              .clamp(0.8, 1.6);
                                          settings.setTextScale(
                                            double.parse(v.toStringAsFixed(1)),
                                          );
                                        },
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          settings.textScale.toStringAsFixed(1),
                                        ),
                                      ),
                                      _MiniGlassIcon(
                                        icon: Icons.add,
                                        onTap: () {
                                          final v = (settings.textScale + 0.1)
                                              .clamp(0.8, 1.6);
                                          settings.setTextScale(
                                            double.parse(v.toStringAsFixed(1)),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Slider(
                                  value: settings.textScale,
                                  onChanged: (v) => settings.setTextScale(
                                    double.parse(v.toStringAsFixed(1)),
                                  ),
                                  min: 0.8,
                                  max: 1.6,
                                  divisions: 8,
                                ),

                                // Preview
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: cs.surfaceContainerHighest
                                        .withValues(alpha: .25),
                                  ),
                                  child: Text(
                                    'Contoh pratayang — “Jejak Cerita Rakyat”. '
                                    'Ubah jenis & skala huruf untuk melihat perbedaan tampilan.',
                                    textScaleFactor: settings.textScale,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ===== Section: Alat & Bantuan =====
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _LabeledGlassCard(
                            label: 'Alat & Bantuan',
                            child: Column(
                              children: [
                                _LinkRow(
                                  icon: Icons.info_outline_rounded,
                                  label: 'Tentang Aplikasi',
                                  onTap: () => showAboutDialog(
                                    context: context,
                                    applicationName: 'Jejak Cerita Rakyat',
                                    applicationVersion: 'v1.0',
                                    children: const [
                                      Text(
                                        'Koleksi cerita rakyat Nusantara dengan peta interaktif dan narasi suara.',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _LinkRow(
                                  icon: Icons.restore_rounded,
                                  label: 'Reset ke Default',
                                  onTap: () {
                                    settings
                                      ..setThemeMode(ThemeMode.system)
                                      ..setFontFamily(listFont.first)
                                      ..setTextScale(1.0);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Pengaturan dikembalikan ke default',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ===== Fill remaining to avoid big empty space =====
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: Column(
                            children: [
                              const Spacer(),
                              _Footer(cs: cs),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ========================= Shared widgets ========================= */

class _GlassBar extends StatelessWidget {
  const _GlassBar({required this.title, this.leading, this.actions});
  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: .65),
              border: Border.all(
                color: Colors.white.withValues(alpha: .22),
                width: 1.1,
              ),
            ),
            child: Row(
              children: [
                if (leading != null) leading!,
                if (leading != null) const SizedBox(width: 8),
                // === Anti-overflow untuk judul bar ===
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textWidthBasis: TextWidthBasis.parent,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ...?actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass card dengan label “melayang” yang TIDAK kepotong.
/// Menambahkan margin top otomatis saat ada label.
class _LabeledGlassCard extends StatelessWidget {
  const _LabeledGlassCard({required this.child, this.label});
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasLabel = label != null && label!.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // jarak top ekstra untuk label agar tidak terpotong
        Container(
          margin: EdgeInsets.only(top: hasLabel ? 14 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.surface.withValues(alpha: .75),
                      cs.surface.withValues(alpha: .50),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .20),
                    width: 1,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
        if (hasLabel)
          Positioned(
            top: 0,
            left: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .22),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .12),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  label!,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.trailing});
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textWidthBasis: TextWidthBasis.parent,
              softWrap: true,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          // Trailing dirapatkan ke kanan
          Expanded(
            flex: 0,
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}

class _MiniGlassIcon extends StatelessWidget {
  const _MiniGlassIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Material(
          color: cs.surface.withValues(alpha: .55),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .22),
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 18, color: cs.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.onTap, // <-- PATCH: inisialisasi field final tooltip via constructor
    this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final btn = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Material(
          color: cs.surface.withValues(alpha: .55),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: .22),
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 22, color: cs.onSurface),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: cs.surface.withValues(alpha: .45),
          border: Border.all(
            color: Colors.white.withValues(alpha: .18),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurface),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurface),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: .75,
      child: Column(
        children: [
          Divider(color: cs.onSurface.withValues(alpha: .2)),
          const SizedBox(height: 8),
          Text(
            'Jejak Cerita Rakyat · v1.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: .7),
            ),
          ),
        ],
      ),
    );
  }
}
