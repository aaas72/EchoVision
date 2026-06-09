import 'package:flutter/material.dart';

/// Minimalist, clean Focus Ring with premium rippling animation.
/// - Idle: subtle breathing thin ring and a small center dot.
/// - Scanning: smooth, clean expanding ripples fading out gracefully.
class FocusRing extends StatefulWidget {
  final bool isScanning;
  final double size;

  const FocusRing({
    super.key,
    required this.isScanning,
    this.size = 180,
  });

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> with TickerProviderStateMixin {
  late AnimationController _idleController;
  late Animation<double> _idleAnim;

  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();

    // Idle breathing (slow, subtle)
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _idleAnim = Tween<double>(begin: 0.95, end: 1.02).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    // Ripple scanning (continuous expansion)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.isScanning) {
      _startScanAnimation();
    }
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
    _idleController.stop();
    _rippleController.repeat();
  }

  void _stopScanAnimation() {
    _rippleController.stop();
    _rippleController.reset();
    _idleController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _idleController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idleController, _rippleController]),
      builder: (context, child) {
        return SizedBox(
          width: widget.size * 1.5,
          height: widget.size * 1.5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Show smooth ripples when scanning
              if (widget.isScanning) ...[
                _buildRipple(delay: 0.0),
                _buildRipple(delay: 0.5),
              ] else ...[
                // Show quiet breathing ring when idle
                _buildIdleRing(),
              ],
              
              // Clean glowing center dot
              _buildCenterCore(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRipple({required double delay}) {
    // Calculate progress allowing for the delay offset
    double progress = (_rippleController.value + delay) % 1.0;
    
    // Scale expands from 0.4 to 1.4
    double scale = 0.4 + (progress * 1.0);
    
    // Fade out as it expands (opacity goes from 1.0 to 0.0)
    double opacity = 1.0 - progress;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: opacity * 0.6),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: opacity * 0.15),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleRing() {
    return Transform.scale(
      scale: _idleAnim.value,
      child: Container(
        width: widget.size * 0.75,
        height: widget.size * 0.75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterCore() {
    final isScanning = widget.isScanning;
    
    // Core pulses slightly with the idle animation if not scanning
    final coreScale = isScanning ? 1.0 : _idleAnim.value;
    
    return Transform.scale(
      scale: coreScale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: isScanning ? 20 : 10,
        height: isScanning ? 20 : 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: isScanning ? 1.0 : 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: isScanning ? 0.6 : 0.3),
              blurRadius: isScanning ? 24 : 12,
              spreadRadius: isScanning ? 6 : 2,
            ),
          ],
        ),
      ),
    );
  }
}
