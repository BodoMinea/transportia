import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

Future<Uint8List> buildStopMarkerImage(
  Color accentColor, {
  bool isTransfer = false,
}) async {
  final size = isTransfer ? 48.0 : 32.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);

  final outerPaint = Paint()..color = AppColors.black.withValues(alpha: 0.2);
  canvas.drawCircle(center, size / 2, outerPaint);

  final ringPaint = Paint()..color = AppColors.white;
  canvas.drawCircle(center, size / 2 - 2, ringPaint);

  final innerPaint = Paint()..color = accentColor;
  final innerRadius = isTransfer ? size / 2 - 7 : size / 2 - 8;
  canvas.drawCircle(center, innerRadius, innerPaint);

  if (isTransfer) {
    final icon = LucideIcons.arrowLeftRight;
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.36,
          color: AppColors.solidWhite,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - (textPainter.width / 2),
        center.dy - (textPainter.height / 2),
      ),
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// A search result on the map: a white disc ringed in [accentColor] with
/// the place's own [icon], the one the result list draws it with.
///
/// Sized like the stop markers; the map scales it up when selected.
Future<Uint8List> buildResultPinImage(Color accentColor, IconData icon) async {
  const size = 36.0;
  const ring = 2.5;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const center = Offset(size / 2, size / 2);

  canvas.drawCircle(
    center + const Offset(0, 1),
    size / 2 - 1,
    Paint()..color = AppColors.solidBlack.withValues(alpha: 0.2),
  );
  canvas.drawCircle(center, size / 2 - 2, Paint()..color = accentColor);
  canvas.drawCircle(
    center,
    size / 2 - 2 - ring,
    Paint()..color = AppColors.solidWhite,
  );

  final textPainter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.44,
        color: accentColor,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  textPainter.paint(
    canvas,
    center - Offset(textPainter.width / 2, textPainter.height / 2),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// A pin for one chosen place: a disc in [color] with a white [icon], and a
/// point below it. Its anchor is the bottom, where the point is.
///
/// The route's origin and destination on the main map, and a point picked
/// by hand on the picker.
Future<Uint8List> buildBubbleMarkerImage(Color color, IconData icon) async {
  const double width = 72;
  const double height = 96;
  const double pointerHeight = 18;
  const double bubbleRadius = 22;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final bubbleCenter = Offset(width / 2, height - pointerHeight - bubbleRadius);

  final shadowPaint = Paint()
    ..color = const Color(0x33000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  canvas.drawCircle(
    bubbleCenter + const Offset(0, 2),
    bubbleRadius + 3,
    shadowPaint,
  );

  final bodyPaint = Paint()..color = color;
  canvas.drawCircle(bubbleCenter, bubbleRadius, bodyPaint);

  final pointerPath = Path()
    ..moveTo(width / 2, height)
    ..lineTo(width / 2 - 10, height - pointerHeight)
    ..lineTo(width / 2 + 10, height - pointerHeight)
    ..close();
  canvas.drawPath(pointerPath, bodyPaint);

  final borderPaint = Paint()
    ..color = AppColors.solidWhite
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  canvas.drawCircle(bubbleCenter, bubbleRadius - 1, borderPaint);

  final iconPainter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 28,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: AppColors.solidWhite,
      ),
    ),
  )..layout();

  iconPainter.paint(
    canvas,
    bubbleCenter - Offset(iconPainter.width / 2, iconPainter.height / 2),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
