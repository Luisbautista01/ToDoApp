// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';

class FloatingParticles extends StatefulWidget {
  final int numberOfParticles;
  final Color color;

  const FloatingParticles({
    super.key,
    this.numberOfParticles = 60,
    this.color = Colors.white,
  });

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    final rand = Random();

    for (int i = 0; i < widget.numberOfParticles; i++) {
      _particles.add(
        _Particle(
          x: rand.nextDouble(),
          y: rand.nextDouble(),
          radius: rand.nextDouble() * 4 + 2,
          dx: (rand.nextDouble() - 0.5) * 0.0005,
          dy: (rand.nextDouble() - 0.5) * 0.0005,
          scaleDirection: rand.nextBool() ? 1 : -1,
        ),
      );
    }

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 30))
          ..addListener(() {
            setState(() {
              for (var p in _particles) {
                p.x += p.dx;
                p.y += p.dy;

                // Movimiento suave de tamaño (como "respirando")
                p.radius += 0.04 * p.scaleDirection;
                if (p.radius > 9 || p.radius < 4) {
                  p.scaleDirection *= -1;
                }

                // Rebote en bordes
                if (p.x < 0 || p.x > 1) p.dx = -p.dx;
                if (p.y < 0 || p.y > 1) p.dy = -p.dy;
              }
            });
          })
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParticlePainter(_particles),
      size: Size.infinite,
    );
  }
}

class _Particle {
  double x, y, dx, dy;
  double radius;
  int scaleDirection;

  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.dx,
    required this.dy,
    required this.scaleDirection,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final dx = p.x * size.width;
      final dy = p.y * size.height;

      final paint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withOpacity(0.7),
                Colors.cyanAccent.withOpacity(0.2),
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(dx, dy), radius: p.radius),
            )
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dx, dy), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
