import 'package:flutter/material.dart';
import 'tuner_controller.dart';
import 'tuner_painter.dart';

void main() {
  runApp(const BassTunerApp());
}

class BassTunerApp extends StatefulWidget {
  const BassTunerApp({super.key});

  @override
  State<BassTunerApp> createState() => _BassTunerAppState();
}

class _BassTunerAppState extends State<BassTunerApp> {
  // Global Theme State
  bool _isLightMode = false;

  @override
  Widget build(BuildContext context) {
    // Define Themes
    final darkTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF050510),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Color(0xFF00FFFF),
        inactiveTrackColor: Colors.white10,
        thumbColor: Color(0xFF00FFFF),
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
      ),
    );

    final lightTheme = ThemeData.light().copyWith(
      scaffoldBackgroundColor: const Color(0xFFEEEEEE),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Color(0xFF0055FF),
        inactiveTrackColor: Colors.black12,
        thumbColor: Color(0xFF0055FF),
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
      ),
    );

    return MaterialApp(
      title: 'LowEnd Bass Tuner',
      debugShowCheckedModeBanner: false,
      theme: _isLightMode ? lightTheme : darkTheme,
      home: TunerScreen(
        isLightMode: _isLightMode,
        onThemeChanged: (v) => setState(() => _isLightMode = v),
      ),
    );
  }
}

class TunerScreen extends StatefulWidget {
  final bool isLightMode;
  final ValueChanged<bool> onThemeChanged;
  
  const TunerScreen({super.key, required this.isLightMode, required this.onThemeChanged});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> with TickerProviderStateMixin {
  final TunerController _controller = TunerController();
  
  double _displayedCents = 0.0;
  
  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTunerUpdate);
    _controller.start();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTunerUpdate);
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  void _onTunerUpdate() {
    setState(() {});
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isLightMode ? const Color(0xFFEEEEEE) : const Color(0xFF050510),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: widget.isLightMode ? Colors.black26 : Colors.white24, width: 2)
        ),
        title: Text("MANUAL OVERRIDE",
            style: TextStyle(
                color: widget.isLightMode ? Colors.black87 : Colors.white,
                fontFamily: 'Courier', fontWeight: FontWeight.bold, letterSpacing: 2)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpRow("MODE", "BASS: Locks to standard 6-string bass frequencies (B0-C3).\nCHROM: Detects any semitone."),
            const SizedBox(height: 12),
            _buildHelpRow("SENS", "Sensitivity. Slide RIGHT to detect quieter notes. Slide LEFT to block background noise."),
            const SizedBox(height: 12),
            _buildHelpRow("SPEED", "Needle Speed. Slide RIGHT for stable/slow response. Slide LEFT for fast/twitchy response."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("ACKNOWLEDGE", style: TextStyle(
                color: widget.isLightMode ? const Color(0xFF0055FF) : const Color(0xFF00FFFF),
                fontWeight: FontWeight.bold, fontFamily: 'Courier')),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpRow(String label, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(
            color: widget.isLightMode ? const Color(0xFF0055FF) : const Color(0xFF00FFFF),
            fontWeight: FontWeight.bold, fontFamily: 'Courier')),
        const SizedBox(height: 4),
        Text(description, style: TextStyle(
            color: widget.isLightMode ? Colors.black54 : Colors.white70,
            fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic smoothing
    double target = _controller.cents;
    if (!_controller.isSignalLocked) target = 0.0;
    _displayedCents += (target - _displayedCents) * _controller.smoothingFactor;

    // Responsive Layout
    bool isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    
    // Adjust bottom padding based on control deck height to ensure Tuner doesn't get covered
    double controlsHeight = isPortrait ? 220 : 80;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Grid Background
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(isLightMode: widget.isLightMode),
            ),
          ),
          
          // 2. Main Tuner Display
          Positioned.fill(
            bottom: controlsHeight, 
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomPaint(
                painter: TunerPainter(
                  cents: _displayedCents,
                  isLocked: _controller.isSignalLocked,
                  note: _controller.note,
                  targetNote: _controller.targetNote,
                  isBassMode: _controller.isBassMode,
                ),
              ),
            ),
          ),
          
          // 3. Header Info
          SafeArea(
            child: Align(
              alignment: isPortrait ? Alignment.topCenter : Alignment.topLeft,
              child: Padding(
                padding: isPortrait 
                    ? const EdgeInsets.only(top: 20.0) 
                    : const EdgeInsets.only(top: 20.0, left: 30.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isPortrait ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    Text("L.E.B.T. // SYSTEM ONLINE", 
                        style: TextStyle(
                            color: widget.isLightMode ? Colors.black38 : Colors.white24, 
                            fontFamily: 'Courier', fontSize: 10, letterSpacing: 4
                        )),
                    const SizedBox(height: 5),
                    Text(
                       _controller.isSignalLocked ? "${_controller.pitch.toStringAsFixed(1)} Hz" : "NO SIGNAL",
                       style: TextStyle(
                           color: widget.isLightMode ? const Color(0xFF0055FF) : const Color(0xFF00FFFF), 
                           fontFamily: 'Courier', fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.bold
                       ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Controls (Bottom Deck)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: controlsHeight,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isLightMode ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.8),
                border: Border(top: BorderSide(color: widget.isLightMode ? Colors.black12 : Colors.white12, width: 1)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -10))]
              ),
              child: isPortrait ? _buildPortraitControls() : _buildLandscapeControls(),
            ),
          ),
          
          // Help Button
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: IconButton(
                   icon: Icon(Icons.help_outline, 
                       color: widget.isLightMode ? Colors.black26 : Colors.white24, 
                       size: 24),
                   onPressed: _showHelp,
                ),
              ),
            ),
          ),
          
          // Debug Overlay
           Positioned(
              bottom: 5, left: 0, right: 0,
              child: Center(
                child: Text(
                  _controller.debugStatus,
                  style: TextStyle(
                      color: widget.isLightMode ? Colors.black26 : Colors.white10, 
                      fontSize: 8, fontFamily: 'Courier'
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPortraitControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
                _buildSwitch("MODE", _controller.isBassMode ? "BASS" : "CHROM", _controller.isBassMode, (v) => _controller.isBassMode = v),
                _buildSwitch("THEME", widget.isLightMode ? "LIGHT" : "DARK", !widget.isLightMode, (v) => widget.onThemeChanged(!v)),
            ],
        ),
        _buildSliderRow("SENS", _controller.sensitivity, (v) => _controller.sensitivity = v),
        _buildSliderRow("SPEED", (_controller.smoothingFactor - 0.01)/0.29, (v) => _controller.smoothingFactor = 0.01 + v*0.29),
      ],
    );
  }
  
  Widget _buildLandscapeControls() {
    return Row(
      children: [
        Expanded(child: _buildSwitch("MODE", _controller.isBassMode ? "BASS" : "CHROM", _controller.isBassMode, (v) => _controller.isBassMode = v)),
        const SizedBox(width: 20),
        Expanded(child: _buildSwitch("THEME", widget.isLightMode ? "LIGHT" : "DARK", !widget.isLightMode, (v) => widget.onThemeChanged(!v))),
        const SizedBox(width: 20),
        Expanded(child: _buildSliderRow("SENS", _controller.sensitivity, (v) => _controller.sensitivity = v)),
        const SizedBox(width: 20),
        Expanded(child: _buildSliderRow("SPEED", (_controller.smoothingFactor - 0.01)/0.29, (v) => _controller.smoothingFactor = 0.01 + v*0.29)),
      ],
    );
  }
  
  Widget _buildSwitch(String label, String valueLabel, bool value, ValueChanged<bool> onChanged) {
      return Column(
          children: [
              Text(label, style: TextStyle(
                  color: widget.isLightMode ? const Color(0xFF0055FF) : const Color(0xFF00FFFF), 
                  fontSize: 10, fontFamily: 'Courier', fontWeight: FontWeight.bold
              )),
              const SizedBox(height: 4),
              InkWell(
                  onTap: () => onChanged(!value),
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: widget.isLightMode ? Colors.black12 : Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: widget.isLightMode ? Colors.black26 : Colors.white24)
                      ),
                      child: Text(valueLabel, style: TextStyle(
                          color: widget.isLightMode ? Colors.black87 : Colors.white,
                          fontSize: 12, fontFamily: 'Courier', fontWeight: FontWeight.bold
                      )),
                  ),
              )
          ],
      );
  }

  Widget _buildSliderRow(String label, double value, ValueChanged<double> onChanged) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(label, style: TextStyle(
                color: widget.isLightMode ? const Color(0xFF0055FF) : const Color(0xFF00FFFF), 
                fontSize: 10, fontFamily: 'Courier', fontWeight: FontWeight.bold
            )),
            SizedBox(
              height: 30,
              child: Slider(
                value: value.clamp(0.0, 1.0),
                onChanged: onChanged,
              ),
            ),
        ],
    );
  }
}

class GridPainter extends CustomPainter {
  final bool isLightMode;
  GridPainter({required this.isLightMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isLightMode ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.02)
      ..strokeWidth = 1;

    double step = 50;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => oldDelegate.isLightMode != isLightMode;
}
