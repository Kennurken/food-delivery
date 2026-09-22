import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapDropPin extends StatelessWidget {
  const MapDropPin({
    super.key,
    required this.color,
    this.lifting = false,
    this.icon = Icons.place,
    this.size = 44,
  });

  final Color color;
  final bool lifting;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final head = size;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 140),
      offset: Offset(0, lifting ? -0.12 : 0),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: lifting ? 1.08 : 1,
        child: SizedBox(
          width: head,
          height: head + 10,
          child: Column(
            children: [
              Container(
                width: head,
                height: head,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: lifting ? 16 : 8,
                      offset: Offset(0, lifting ? 8 : 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: head * 0.48),
              ),
              CustomPaint(
                size: const Size(12, 10),
                painter: _TipPainter(color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipPainter extends CustomPainter {
  _TipPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TipPainter old) => old.color != color;
}

class PlaceMarker {
  static Marker drop({
    required LatLng point,
    required Color color,
    IconData icon = Icons.place,
    double size = 44,
  }) => Marker(
    point: point,
    width: size,
    height: size + 10,
    alignment: Alignment.topCenter,
    child: MapDropPin(color: color, icon: icon, size: size),
  );

  static Marker courier({
    required LatLng point,
    required Color color,
    double? heading,
  }) => Marker(
    point: point,
    width: 40,
    height: 40,
    alignment: Alignment.center,
    child: Transform.rotate(
      angle: ((heading ?? 0) * 3.1415926535 / 180),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.navigation, color: Colors.white, size: 20),
      ),
    ),
  );
}
