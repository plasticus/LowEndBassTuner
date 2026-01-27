import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';

class TunerController extends ChangeNotifier {
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();
  bool _isListening = false;
  double _pitch = 0.0;
  String _note = "--";
  String _targetNote = ""; // The intended note (e.g. "E")
  double _cents = 0.0;
  bool _isSignalLocked = false;
  double _volume = 0.0;
  
  // Tuning Mode
  bool _isBassMode = true; // True = Bass (B E A D G C), False = Chromatic
  
  // Debug State
  String _debugStatus = "Initialized";
  DateTime _lastDebugPrint = DateTime.now();

  // Control Parameters
  double _sensitivity = 0.5; 
  double _smoothingFactor = 0.15; 

  // Standard Bass Frequencies (6-String: B0 to C3)
  static const Map<String, double> _bassTunings = {
    'B': 30.87, // B0
    'E': 41.20, // E1
    'A': 55.00, // A1
    'D': 73.42, // D2
    'G': 98.00, // G2
    'C': 130.81 // C3
  };

  double get pitch => _pitch;
  String get note => _note;
  String get targetNote => _targetNote;
  double get cents => _cents;
  bool get isSignalLocked => _isSignalLocked;
  bool get isListening => _isListening;
  double get volume => _volume;
  String get debugStatus => _debugStatus;

  double get sensitivity => _sensitivity;
  set sensitivity(double val) {
    _sensitivity = val.clamp(0.0, 1.0);
    notifyListeners();
  }
  
  bool get isBassMode => _isBassMode;
  set isBassMode(bool val) {
    _isBassMode = val;
    notifyListeners();
  }

  double get smoothingFactor => _smoothingFactor;
  set smoothingFactor(double val) {
    _smoothingFactor = val.clamp(0.01, 1.0);
    notifyListeners();
  }

  final List<double> _buffer = [];
  static const int _processSize = 4096; 

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
      await _audioCapture.start(
        listener, 
        onError, 
        sampleRate: 44100, 
        bufferSize: 4096
      );
      _isListening = true;
      _setDebug("Listening...");
      notifyListeners();
    } catch (e) {
      _setDebug("Start Error: $e");
    }
  }

  Future<void> stop() async {
    await _audioCapture.stop();
    _isListening = false;
    _isSignalLocked = false;
    _note = "--";
    _targetNote = "";
    _cents = 0.0;
    _volume = 0.0;
    _setDebug("Stopped");
    notifyListeners();
  }

  void onError(Object e) {
    _setDebug("Stream Error: $e");
  }

  void listener(dynamic obj) {
    List<double> samples = [];
    if (obj is Float32List) {
      samples = obj.map((e) => e.toDouble()).toList();
    } else if (obj is List) {
       samples = obj.map((e) => (e as num).toDouble()).toList();
    } else {
        return; 
    }

    _buffer.addAll(samples);

    if (_buffer.length >= _processSize) {
      _processAudio(_buffer.sublist(_buffer.length - _processSize));
      _buffer.clear(); 
    }
  }

  void _processAudio(List<double> rawSamples) {
    // 0. Normalize
    double maxVal = 0.0;
    for(var s in rawSamples) {
      if (s.abs() > maxVal) maxVal = s.abs();
    }
    if (maxVal > 1.0) {
      for(int i=0; i<rawSamples.length; i++) {
        rawSamples[i] /= 32768.0;
      }
    }

    // 1. Noise Gate
    double rms = 0;
    for (var s in rawSamples) rms += s * s;
    rms = sqrt(rms / rawSamples.length);
    _volume = rms; 
    
    // Threshold
    double threshold = 0.02 * (1.0 - _sensitivity) + 0.0005; 
    if (rms < threshold) {
      _isSignalLocked = false;
      notifyListeners();
      return; 
    }

    // 2. LPF (44100 / 4 = 11025Hz)
    int ds = 4;
    double fs = 44100 / ds; 
    List<double> downsampled = [];
    double alpha = 0.05; 
    double last = 0;
    
    for (int i = 0; i < rawSamples.length; i++) {
      last = last + alpha * (rawSamples[i] - last);
      if (i % ds == 0) {
        downsampled.add(last);
      }
    }

    // 3. Autocorrelation
    int minPeriod = (fs / 400).floor();
    int maxPeriod = (fs / 20).floor(); 
    int N = downsampled.length - maxPeriod; 
    if (N < 100) return; 

    double bestCorr = -1.0;
    int bestLag = -1;

    for (int lag = minPeriod; lag <= maxPeriod; lag++) {
       double sum = 0;
       for (int i = 0; i < N; i++) {
         sum += downsampled[i] * downsampled[i + lag];
       }
       if (sum > bestCorr) {
         bestCorr = sum;
         bestLag = lag;
       }
    }

    if (bestLag > 0) {
      // Parabolic Interpolation
      double y2 = bestCorr;
      double y1 = 0;
      for(int i=0; i<N; i++) y1 += downsampled[i] * downsampled[i + bestLag - 1];
      double y3 = 0;
      for(int i=0; i<N; i++) y3 += downsampled[i] * downsampled[i + bestLag + 1];

      double d = (y1 - y3) / (2 * (y1 - 2 * y2 + y3));
      double preciseLag = bestLag + d;
      double freq = fs / preciseLag;
      
      if (freq > 20 && freq < 400) {
          _pitch = freq;
          _matchNote(freq);
          _isSignalLocked = true;
      } else {
        _isSignalLocked = false;
      }
    } else {
      _isSignalLocked = false;
    }
    
    notifyListeners();
  }

  void _matchNote(double freq) {
    if (freq <= 0) return;

    if (_isBassMode) {
      // Bass Logic: Find closest STANDARD bass note
      String closestNote = "";
      double minDiff = double.infinity;
      double closestTargetFreq = 0.0;

      _bassTunings.forEach((name, targetFreq) {
        // Check simple difference first, but we need to handle octave errors?
        // Actually, autocorrelation usually finds the fundamental or 2nd harmonic.
        // Let's assume fundamental for now.
        double diff = (freq - targetFreq).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestNote = name;
          closestTargetFreq = targetFreq;
        }
      });
      
      // If we are closer to a harmonic, we might be wrong, but let's trust the pitch detector for now.
      // Calculate cents relative to this target
      _targetNote = closestNote;
      _note = closestNote;
      _cents = 1200 * (log(freq / closestTargetFreq) / log(2));
      
    } else {
      // Chromatic Logic (Standard A440)
      double n = 12.0 * (log(freq / 440.0) / log(2.0));
      int semitone = n.round();
      _cents = (n - semitone) * 100.0;

      const List<String> noteNames = [
        'A', 'A#', 'B', 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#'
      ];
      int index = semitone % 12;
      if (index < 0) index += 12;
      
      _targetNote = noteNames[index];
      _note = noteNames[index];
    }
  }
}
