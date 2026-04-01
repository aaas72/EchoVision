import 'dart:math';
import 'package:flutter/material.dart';

/// Premium glassmorphic Focus Ring with scanning animations.
/// - Idle: subtle breathing glow
/// - Scanning: pulsing ring + horizontal laser sweep
class FocusRing extends StatefulWidget {
  final bool isScanning;
  final double size;

  const FocusRing({
    super.key,
    required this.isScanning,
    this.size = 220,
  });

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> with TickerProviderStateMixin {
  // Idle breathing animation
  late AnimationController _breatheController;
  late Animation<double> _breatheAnim;

  // Scan pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Laser sweep animation
  late AnimationController _laserController;
  late Animation<double> _laserAnim;

  // Corner rotation animation
  late AnimationController _rotateController;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();

    // Idle breathing: slow scale 0.95 → 1.05
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _breatheAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    // Scan pulse: faster, 1.0 → 1.15
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Laser sweep: top → bottom
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _laserAnim = Tween<double>(begin: -0.5, end: 0.5).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    // Corner rotation for scan mode
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _rotateAnim = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );
  }

  @override
  void didUpdateWidget(FocusRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !oldWidget.isScanning) {
      _startScanAnimation();
    } else if (!widget.isScanning && oldWidget.isScanning) {
      _stopScanAnimation();
    }
  }

  void _startScanAnimation() {
    _breatheController.stop();
    _pulseController.repeat(reverse: true);
    _laserController.repeat();
    _rotateController.repeat();
  }

  void _stopScanAnimation() {
    _pulseController.stop();
    _pulseController.reset();
    _laserController.stop();
    _laserController.reset();
    _rotateController.stop();
    _rotateController.reset();
    _breatheController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _pulseController.dispose();
    _laserController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _breatheAnim,
        _pulseAnim,
        _laserAnim,
        _rotateAnim,
      ]),
      builder: (context, child) {
        final scale = widget.isScanning ? _pulseAnim.value : _breatheAnim.value;
        return SizedBox(
          width: widget.size * 1.3,
          height: widget.size * 1.3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              _buildGlowRing(scale),

              // Corner brackets
              _buildCornerBrackets(scale),

              // Laser sweep line (only during scan)
              if (widget.isScanning) _buildLaserSweep(),

              // Center dot
              _buildCenterDot(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlowRing(double scale) {
    final color = widget.isScanning
        ? const Color(0xFFFFD600) // Neon Yellow
        : Colors.white;
    final glowOpacity = widget.isScanning ? 0.45 : 0.2;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: widget.isScanning ? 0.9 : 0.5),
            width: widget.isScanning ? 3.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: glowOpacity),
              blurRadius: widget.isScanning ? 30 : 15,
              spreadRadius: widget.isScanning ? 8 : 2,
            ),
            BoxShadow(
              color: color.withValues(alpha: glowOpacity * 0.5),
              blurRadius: 60,
              spreadRadius: 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerBrackets(double scale) {
    final color = widget.isScanning
        ? const Color(0xFFFFD600)
        : Colors.white.withValues(alpha: 0.7);
    final bracketSize = widget.size * 0.38;
    final offset = widget.size * 0.43;

    return Transform.scale(
      scale: scale,
      child: Transform.rotate(
        angle: widget.isScanning ? _rotateAnim.value * 0.05 : 0,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              // Top-left
              Positioned(
                left: (widget.size - offset * 2) / 2,
                top: (widget.size - offset * 2) / 2,
                child: _cornerBracket(color, bracketSize, 0),
              ),
              // Top-right
              Positioned(
                right: (widget.size - offset * 2) / 2,
                top: (widget.size - offset * 2) / 2,
                child: _cornerBracket(color, bracketSize, pi / 2),
              ),
              // Bottom-right
              Positioned(
                right: (widget.size - offset * 2) / 2,
                bottom: (widget.size - offset * 2) / 2,
                child: _cornerBracket(color, bracketSize, pi),
              ),
              // Bottom-left
              Positioned(
                left: (widget.size - offset * 2) / 2,
                bottom: (widget.size - offset * 2) / 2,
                child: _cornerBracket(color, bracketSize, 3 * pi / 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cornerBracket(Color color, double size, double rotation) {
    return Transform.rotate(
      angle: rotation,
      child: CustomPaint(
        size: Size(size, size),
        painter: _CornerPainter(color: color, strokeWidth: 2.5),
      ),
    );
  }

  Widget _buildLaserSweep() {
    return ClipOval(
      child: SizedBox(
        width: widget.size * 0.85,
        height: widget.size * 0.85,
        child: Stack(
          children: [
            Positioned(
              top: (widget.size * 0.85) * (0.5 + _laserAnim.value),
              left: 0,
              right: 0,
              child: Container(
                height: 2.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFFFFD600).withValues(alpha: 0.8),
                      const Color(0xFF00E5FF),
                      const Color(0xFFFFD600).withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterDot() {
    final color = widget.isScanning
        ? const Color(0xFFFFD600)
        : Colors.white;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Paints an L-shaped corner bracket.
class _CornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _CornerPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final length = size.width * 0.45;
    final path = Path()
      ..moveTo(0, length)
      ..lineTo(0, 0)
      ..lineTo(length, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}
