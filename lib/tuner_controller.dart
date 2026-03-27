import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';

class TunerController extends ChangeNotifier {
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();
  bool _isListening = false;
  double _pitch = 0.0;
  String _note = "--";
  String _targetNote = "";
  double _cents = 0.0;
  bool _isSignalLocked = false;
  double _volume = 0.0;

  bool _isBassMode = true;
  String _debugStatus = "Initialized";
  double _sensitivity = 0.5;
  double _smoothingFactor = 0.15; // RESTORED

  final List<double> _pitchHistory = [];
  static const int _historyDepth = 7;

  static const List<String> _noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  // Getters
  double get pitch => _pitch;
  String get note => _note;
  String get targetNote => _targetNote;
  double get cents => _cents;
  bool get isSignalLocked => _isSignalLocked;
  double get sensitivity => _sensitivity;
  bool get isBassMode => _isBassMode;
  double get smoothingFactor => _smoothingFactor; // RESTORED
  String get debugStatus => _debugStatus; // RESTORED

  set sensitivity(double val) { _sensitivity = val.clamp(0.0, 1.0); notifyListeners(); }
  set isBassMode(bool val) { _isBassMode = val; notifyListeners(); }
  set smoothingFactor(double val) { _smoothingFactor = val.clamp(0.01, 1.0); notifyListeners(); } // RESTORED

  final List<double> _buffer = [];
  static const int _bufferSize = 4096;

  void _setDebug(String msg) {
    _debugStatus = msg;
    notifyListeners();
  }

  Future<void> start() async {
    _setDebug("Checking Permissions...");
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _setDebug("Mic Permission Denied");
      return;
    }
    try {
      _setDebug("Initializing...");
      await _audioCapture.init();
      await _audioCapture.start(listener, (e) => {}, sampleRate: 44100, bufferSize: 4096);
      _isListening = true;
      _setDebug("Listening...");
      notifyListeners();
    } catch (e) { _setDebug("Error: $e"); }
  }

  // RESTORED: Stop method
  Future<void> stop() async {
    await _audioCapture.stop();
    _isListening = false;
    _isSignalLocked = false;
    _note = "--";
    _targetNote = "";
    _cents = 0.0;
    _pitchHistory.clear();
    _setDebug("Stopped");
    notifyListeners();
  }

  void listener(dynamic obj) {
    if (obj is Float32List) { _buffer.addAll(obj); }
    else if (obj is List) { _buffer.addAll(obj.map((e) => (e as num).toDouble())); }

    if (_buffer.length >= _bufferSize) {
      _processAudioYIN(_buffer.sublist(0, _bufferSize));
      _buffer.removeRange(0, 1024);
    }
    if (_buffer.length > 8192) _buffer.clear();
  }

  void _processAudioYIN(List<double> samples) {
    double sumSq = 0;
    for (var s in samples) {
      sumSq += s * s;
    }
    _volume = sqrt(sumSq / samples.length);
    if (_volume < (0.01 * (1.1 - _sensitivity))) {
      _isSignalLocked = false;
      _pitchHistory.clear();
      notifyListeners();
      return;
    }

    int minTau = (44100 / 4000).floor();
    int maxTau = (44100 / 20).floor();
    if (maxTau > samples.length / 2) maxTau = (samples.length / 2).floor();

    List<double> yinBuffer = List.filled(maxTau, 0.0);
    for (int tau = 1; tau < maxTau; tau++) {
      for (int i = 0; i < maxTau; i++) {
        double delta = samples[i] - samples[i + tau];
        yinBuffer[tau] += delta * delta;
      }
    }

    yinBuffer[0] = 1.0;
    double runningSum = 0;
    for (int tau = 1; tau < maxTau; tau++) {
      runningSum += yinBuffer[tau];
      yinBuffer[tau] *= (tau / runningSum);
    }

    int bestTau = -1;
    double threshold = 0.15;
    for (int tau = minTau; tau < maxTau; tau++) {
      if (yinBuffer[tau] < threshold) {
        bestTau = tau;
        while (tau + 1 < maxTau && yinBuffer[tau + 1] < yinBuffer[tau]) {
          tau++;
          bestTau = tau;
        }
        break;
      }
    }

    if (bestTau > 0) {
      double freq = 44100 / bestTau;
      if (_isBassMode && freq > 180) {
        _isSignalLocked = false;
      } else {
        _pitchHistory.add(freq);
        if (_pitchHistory.length > _historyDepth) _pitchHistory.removeAt(0);

        List<double> sorted = List.from(_pitchHistory)..sort();
        _pitch = sorted[sorted.length ~/ 2];
        _matchNote(_pitch);
        _isSignalLocked = true;
      }
    } else { _isSignalLocked = false; }
    notifyListeners();
  }

  void _matchNote(double freq) {
    double midi = 12.0 * (log(freq / 440.0) / log(2.0)) + 69.0;
    int roundedMidi = midi.round();
    _cents = (midi - roundedMidi) * 100.0;
    int noteIdx = roundedMidi % 12;
    if (noteIdx < 0) noteIdx += 12;
    _note = _noteNames[noteIdx];
    _targetNote = _note;
  }
}