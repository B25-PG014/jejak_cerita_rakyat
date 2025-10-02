import 'dart:async';
import 'dart:ui' as ui show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  // Ganti ke path gambar 9:16-mu
  static const _asset = 'assets/images/splash/splash.png';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scale = Tween<double>(
      begin: 1.04,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeIn);
    _goNext();
  }

  Future<void> _runInit() async {
    await Future.wait(<Future<void>>[
      Future.delayed(const Duration(milliseconds: 900)),
      // TODO: tambahkan init nyata (DB/prefs/dll)
    ]);
  }

  Future<void> _goNext() async {
    await Future.wait<void>([_c.forward(), _runInit()]);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    precacheImage(const AssetImage(_asset), context);
    final size = MediaQuery.sizeOf(context);
    final screenAR = size.width / size.height;
    const imgAR = 9 / 16;
    // kalau beda > ~1.5% dari 9:16, aktifkan mode no-crop (blur bg + contain)
    final needsContain = (screenAR - imgAR).abs() > 0.015;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              if (!needsContain) {
                // Rasio dekat 9:16 → full cover tanpa crop berarti
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    FadeTransition(
                      opacity: _fade,
                      child: Transform.scale(
                        scale: _scale.value,
                        child: Image.asset(_asset, fit: BoxFit.cover),
                      ),
                    ),
                    _buildProgress(),
                  ],
                );
              }

              // Mode aman: background cover blur + foreground contain (tidak terpotong)
              return Stack(
                fit: StackFit.expand,
                children: [
                  // BACKGROUND: cover & blur supaya tetap full-bleed
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.10),
                        BlendMode.darken,
                      ),
                      child: Image.asset(_asset, fit: BoxFit.cover),
                    ),
                  ),
                  // FOREGROUND: gambar asli tanpa crop
                  Center(
                    child: FadeTransition(
                      opacity: _fade,
                      child: ScaleTransition(
                        scale: _scale,
                        child: AspectRatio(
                          aspectRatio: imgAR,
                          child: Image.asset(_asset, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                  _buildProgress(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() => Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: _c.value,
          minHeight: 6,
          backgroundColor: Colors.white.withValues(alpha: 0.25),
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.white.withValues(alpha: 0.95),
          ),
        ),
      ),
    ),
  );
}
