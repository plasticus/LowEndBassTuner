import 'package:flutter/material.dart';

class TunerPainter extends CustomPainter {
  final double cents;
  final bool isLocked;
  final String note;
  final String targetNote;
  final bool isBassMode;

  TunerPainter({
    required this.cents,
    required this.isLocked,
    required this.note,
    required this.targetNote,
    required this.isBassMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bool isPortrait = size.height > size.width;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Indicator color shifts for tuning, letters stay white
    Color feedbackColor = _getFeedbackColor();

    // 1. Draw the Background Tape/Tower with Hash Marks
    // Increased spacing to 25% of screen height/width for better spread
    final double spacing = isPortrait ? size.height * 0.25 : size.width * 0.3;
    double currentOffsetInSemis = (cents / 100.0);
    _drawTape(canvas, size, isPortrait, currentOffsetInSemis, spacing);

    // 2. The Fixed "Target Bar" (The Crosshair)
    final targetPaint = Paint()
      ..color = feedbackColor
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, isLocked ? 8 : 0);

    if (isPortrait) {
      // Horizontal bar across the vertical tower
      canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), targetPaint);
    } else {
      // Vertical bar across the horizontal tape
      canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), targetPaint);
    }

    // 3. The Massive HUD Note (The only Solid White element)
    _drawCenterNote(canvas, size, isPortrait, feedbackColor);
  }

  void _drawTape(Canvas canvas, Size size, bool isPortrait, double offset, double spacing) {
    final List<String> allNotes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    int centerNoteIdx = allNotes.indexOf(targetNote.replaceAll(RegExp(r'[0-9]'), ''));
    if (centerNoteIdx == -1) centerNoteIdx = 0;

    // Draw a wide range (-5 to +5) to ensure the screen feels full
    for (int i = -5; i <= 5; i++) {
      int currentIdx = (centerNoteIdx + i) % 12;
      if (currentIdx < 0) currentIdx += 12;
      String noteName = allNotes[currentIdx];

      double visualOffset = (i - offset) * spacing;

      // Background notes: Now at 40% opacity so they show in Light/Dark mode
      final textStyle = TextStyle(
        color: Colors.white.withOpacity(0.4),
        fontSize: 32,
        fontWeight: FontWeight.w900,
        fontFamily: 'Courier',
      );

      final span = TextSpan(text: noteName, style: textStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();

      if (isPortrait) {
        // Positioned at 65% width to keep it clear of the big note on the left
        double yPos = (size.height / 2) - visualOffset;
        tp.paint(canvas, Offset(size.width * 0.65 - tp.width / 2, yPos - tp.height / 2));
      } else {
        // Positioned at 65% height to keep it clear of the big note on top
        double xPos = (size.width / 2) + visualOffset;
        tp.paint(canvas, Offset(xPos - tp.width / 2, size.height * 0.65 - tp.height / 2));
      }

      // Draw the quarter-hash marks between the notes
      if (i < 5) {
        _drawHashes(canvas, size, isPortrait, i, offset, spacing);
      }
    }
  }

  void _drawHashes(Canvas canvas, Size size, bool isPortrait, int noteIndex, double offset, double spacing) {
    // Hash marks at 20% opacity
    final hashPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 3;

    for (int h = 1; h <= 3; h++) {
      double fractionalSemi = noteIndex + (h * 0.25);
      double visualOffset = (fractionalSemi - offset) * spacing;

      if (isPortrait) {
        double y = (size.height / 2) - visualOffset;
        // Centered hash marks
        canvas.drawLine(Offset(size.width * 0.45, y), Offset(size.width * 0.65, y), hashPaint);
      } else {
        double x = (size.width / 2) + visualOffset;
        canvas.drawLine(Offset(x, size.height * 0.45), Offset(x, size.height * 0.65), hashPaint);
      }
    }
  }

  void _drawCenterNote(Canvas canvas, Size size, bool isPortrait, Color glowColor) {
    if (!isLocked) return;

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: isPortrait ? 180 : 140,
      fontWeight: FontWeight.w900,
      fontFamily: 'Courier',
      shadows: [
        Shadow(color: glowColor.withOpacity(0.5), blurRadius: 40),
        const Shadow(color: Colors.black, offset: Offset(6, 6)),
      ],
    );

    final span = TextSpan(text: note, style: textStyle);
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();

    // Offset slightly so it's readable from a distance
    Offset pos = isPortrait
        ? Offset(size.width * 0.05, size.height / 2 - tp.height / 2)
        : Offset(size.width / 2 - tp.width / 2, size.height * 0.05);

    tp.paint(canvas, pos);
  }

  Color _getFeedbackColor() {
    if (!isLocked) return Colors.white12;
    if (cents.abs() < 2.5) return const Color(0xFF00FFFF); // Electric Cyan
    return cents < 0 ? const Color(0xFFFF0055) : const Color(0xFFBB00FF); // Hot Pink vs Neon Purple
  }

  @override
  bool shouldRepaint(covariant TunerPainter oldDelegate) => true;
}