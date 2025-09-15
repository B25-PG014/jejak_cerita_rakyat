import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

typedef TtsErrorHandler = void Function(String message);

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> init({String language = 'id-ID', double rate = 0.5, double pitch = 1.0, double volume = 1.0}) async {
    if (_initialized) return;
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);   // 0.0 .. 1.0 (plugin maps per platform)
    await _tts.setPitch(pitch);       // 0.5 .. 2.0
    await _tts.setVolume(volume);     // 0.0 .. 1.0

    // Ensure completion awaits so UI can react to done event
    await _tts.awaitSpeakCompletion(true);

    // Optional platform tuning
    if (Platform.isAndroid) {
      // You can try to set audioCategory on iOS only; Android doesn't need extra config
    }

    _initialized = true;
  }

  Future<void> setLanguage(String value) => _tts.setLanguage(value);
  Future<void> setRate(double value) => _tts.setSpeechRate(value);
  Future<void> setPitch(double value) => _tts.setPitch(value);
  Future<void> setVolume(double value) => _tts.setVolume(value);

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
  Future<void> pause() => _tts.pause();

  void setHandlers({
    void Function()? onStart,
    void Function()? onCompletion,
    void Function()? onPause,
    void Function()? onContinue,
    TtsErrorHandler? onError,
  }) {
    _tts.setStartHandler(() => onStart?.call());
    _tts.setCompletionHandler(() => onCompletion?.call());
    _tts.setPauseHandler(() => onPause?.call());
    _tts.setContinueHandler(() => onContinue?.call());
    _tts.setErrorHandler((msg) => onError?.call(msg));
  }

  Future<List<String>> languages() async {
    final langs = await _tts.getLanguages as List?; // some platforms return List<dynamic>
    return langs?.map((e) => e.toString()).toList() ?? <String>[];
  }

  void dispose() {
    // No explicit dispose in plugin, but you can stop speaking
    _tts.stop();
  }
}
