import 'package:flutter/foundation.dart';
import '../services/tts_service.dart';

class TtsProvider extends ChangeNotifier {
  final TtsService _service;

  TtsProvider(this._service) {
    _init();
  }

  bool _ready = false;
  bool _speaking = false;
  bool _paused = false;

  double _rate = 0.5; // 0.0 .. 1.0
  double _pitch = 1.0; // 0.5 .. 2.0
  double _volume = 1.0; // 0.0 .. 1.0
  String _language = 'id-ID';

  bool get ready => _ready;
  bool get speaking => _speaking;
  bool get paused => _paused;
  double get rate => _rate;
  double get pitch => _pitch;
  double get volume => _volume;
  String get language => _language;

  Future<void> _init() async {
    await _service.init(
      language: _language,
      rate: _rate,
      pitch: _pitch,
      volume: _volume,
    );
    _service.setHandlers(
      onStart: () {
        _speaking = true;
        _paused = false;
        notifyListeners();
      },
      onCompletion: () {
        _speaking = false;
        _paused = false;
        notifyListeners();
      },
      onPause: () {
        _paused = true;
        notifyListeners();
      },
      onContinue: () {
        _paused = false;
        notifyListeners();
      },
      onError: (msg) {
        _speaking = false;
        _paused = false;
        notifyListeners();
      },
    );
    _ready = true;
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    await _service.setLanguage(value);
    notifyListeners();
  }

  Future<void> setRate(double v) async {
    _rate = v.clamp(0.0, 1.0);
    await _service.setRate(_rate);
    notifyListeners();
  }

  Future<void> setPitch(double v) async {
    _pitch = v.clamp(0.5, 2.0);
    await _service.setPitch(_pitch);
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    await _service.setVolume(_volume);
    notifyListeners();
  }

  Future<void> speak(String text) async {
    await _service.speak(text);
  }

  Future<void> stop() async {
    await _service.stop();
    _speaking = false;
    _paused = false;
    notifyListeners();
  }

  Future<void> pause() async {
    await _service.pause();
    _paused = true;
    notifyListeners();
  }
}
