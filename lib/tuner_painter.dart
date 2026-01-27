import 'dart:math';
import 'package:flutter/material.dart';

class TunerPainter extends CustomPainter {
  final double cents; // -50 to +50
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
    final centerX = size.width / 2;
    final isLandscape = size.width > size.height;
    
    // Geometry Calculation
    double radius;
    Offset center;
    
    if (isLandscape) {
       // Landscape: Smaller radius relative to width to fit vertically
       // Pivot point pushed further down
       radius = size.width * 0.55; 
       center = Offset(centerX, size.height + (radius * 0.5));
    } else {
       // Portrait
       radius = size.width * 0.8;
       center = Offset(centerX, size.height + (radius * 0.3));
    }
    
    // Colors
    Color primaryColor;
    if (!isLocked) {
      primaryColor = Colors.white10;
    } else if (cents.abs() < 3) {
      primaryColor = const Color(0xFF00FFFF); // Cyan
    } else if (cents < 0) {
      primaryColor = const Color(0xFFFF0055); // Pink/Red
    } else {
      primaryColor = const Color(0xFF5500FF); // Purple/Blue
    }

    // Track
    final trackPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.butt;

    final double sweepAngle = isLandscape ? (pi * 0.6) : (pi / 2); 
    final double startAngle = -pi / 2 - (sweepAngle / 2);
    final trackRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(trackRect, startAngle, sweepAngle, false, trackPaint);

    // Ticks
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2;
    
    final int totalTicks = 20; 
    final double stepAngle = sweepAngle / totalTicks;
    
    for (int i = 0; i <= totalTicks; i++) {
      double angle = startAngle + (i * stepAngle);
      Offset p1 = center + Offset(cos(angle) * (radius - 10), sin(angle) * (radius - 10));
      Offset p2 = center + Offset(cos(angle) * (radius + 20), sin(angle) * (radius + 20));
      
      // Center Tick
      if (i == totalTicks / 2) {
        tickPaint
          ..color = Colors.white54
          ..strokeWidth = 4;
        p1 = center + Offset(cos(angle) * (radius - 20), sin(angle) * (radius - 20));
        p2 = center + Offset(cos(angle) * (radius + 30), sin(angle) * (radius + 30));
        
        // Target Note at Top of Speedometer
        if (isLocked) {
           final topTextStyle = TextStyle(
             color: primaryColor,
             fontSize: 24,
             fontWeight: FontWeight.bold,
             fontFamily: 'Courier'
           );
           final topSpan = TextSpan(text: targetNote, style: topTextStyle);
           final topPainter = TextPainter(text: topSpan, textDirection: TextDirection.ltr);
           topPainter.layout();
           
           // Position above the center tick
           Offset textPos = center + Offset(cos(angle) * (radius - 50), sin(angle) * (radius - 50)) - Offset(topPainter.width/2, topPainter.height/2);
           topPainter.paint(canvas, textPos);
        }

      } else {
        tickPaint
          ..color = Colors.white24
          ..strokeWidth = 2;
      }
      
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Active Needle / Arc
    if (isLocked) {
      final double normalizedCents = cents.clamp(-50.0, 50.0);
      final double angleOffset = (normalizedCents / 50.0) * (sweepAngle / 2);
      final double needleAngle = -pi / 2 + angleOffset;

      final activeTrackPaint = Paint()
        ..color = primaryColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15;
        
      double fillStart = -pi / 2;
      double fillSweep = angleOffset;
      canvas.drawArc(trackRect, fillStart, fillSweep, false, activeTrackPaint);

      final needlePaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

      final needleLen = 50.0;
      final tipPos = center + Offset(cos(needleAngle) * (radius - 5), sin(needleAngle) * (radius - 5));
      final basePos = center + Offset(cos(needleAngle) * (radius - 5 - needleLen), sin(needleAngle) * (radius - 5 - needleLen));
      
      final perpAngle = needleAngle + pi/2;
      final width = 12.0;
      final pLeft = basePos + Offset(cos(perpAngle)*width, sin(perpAngle)*width);
      final pRight = basePos - Offset(cos(perpAngle)*width, sin(perpAngle)*width);
      
      final needlePath = Path()..moveTo(tipPos.dx, tipPos.dy)..lineTo(pLeft.dx, pLeft.dy)..lineTo(pRight.dx, pRight.dy)..close();
      canvas.drawPath(needlePath, needlePaint);
    }

    // HUD Text
    final textCenter = Offset(centerX, size.height * (isLandscape ? 0.35 : 0.4)); 

    final textStyle = TextStyle(
      color: isLocked ? Colors.white : Colors.white10,
      fontSize: isLandscape ? 140 : 90, 
      fontWeight: FontWeight.w900,
      fontFamily: 'Courier', 
      shadows: isLocked ? [
        Shadow(color: primaryColor, blurRadius: 40),
        Shadow(color: primaryColor, blurRadius: 10),
      ] : [],
    );

    final textSpan = TextSpan(text: isLocked ? note : "--", style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, textCenter - Offset(textPainter.width / 2, textPainter.height / 2));
    
    // Cents Readout
    if (isLocked) {
      final subStyle = TextStyle(
        color: primaryColor,
        fontSize: isLandscape ? 32 : 24,
        fontFamily: 'Courier',
        letterSpacing: 4,
        fontWeight: FontWeight.bold
      );
      
      String centsStr = cents > 0 ? "+${cents.toStringAsFixed(1)}" : cents.toStringAsFixed(1);
      final subSpan = TextSpan(text: "DEV: $centsStr", style: subStyle);
      final subPainter = TextPainter(text: subSpan, textDirection: TextDirection.ltr);
      subPainter.layout();
      subPainter.paint(canvas, textCenter + Offset(-subPainter.width/2, textPainter.height/2 + (isLandscape ? 20 : 10)));
    }
    
    // Mode Indicator (Bottom of visualization)
    final modeStyle = TextStyle(
      color: Colors.white24,
      fontSize: 12,
      fontFamily: 'Courier',
      letterSpacing: 2
    );
    final modeText = isBassMode ? "MODE: BASS (6-STR)" : "MODE: CHROMATIC";
    final modeSpan = TextSpan(text: modeText, style: modeStyle);
    final modePainter = TextPainter(text: modeSpan, textDirection: TextDirection.ltr);
    modePainter.layout();
    modePainter.paint(canvas, Offset(centerX - modePainter.width/2, size.height * 0.85));
  }

  @override
  bool shouldRepaint(covariant TunerPainter oldDelegate) {
    return oldDelegate.cents != cents || 
           oldDelegate.isLocked != isLocked || 
           oldDelegate.note != note ||
           oldDelegate.targetNote != targetNote ||
           oldDelegate.isBassMode != isBassMode;
  }
}
