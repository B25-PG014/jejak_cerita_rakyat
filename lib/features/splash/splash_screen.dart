import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  initState() {
    super.initState();
    // Simulate some initialization work
    Future.delayed(const Duration(seconds: 2), () {
      // After initialization, navigate to the main app screen
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset(
          'assets/images/splash/splash.png', // pastikan ada di folder assets
          width: 120,
          height: 120,
        ),
      ),
    );
  }
}