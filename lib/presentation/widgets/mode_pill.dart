import 'package:flutter/material.dart';
import '../../core/enums/detection_mode.dart';

class ModePill extends StatelessWidget {
  final DetectionMode currentMode;
  final Animation<double> animation;

  const ModePill({
    super.key,
    required this.currentMode,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    const kDeepBlack = Color(0xFF0A0A0A);
    const kAccentYellow = Color(0xFFFFD600);

    String label;
    IconData icon;
    switch (currentMode) {
      case DetectionMode.hazard:
        label = 'Hazard Detection';
        icon = Icons.warning_rounded;
        break;
      case DetectionMode.object:
        label = 'Object Scanner';
        icon = Icons.center_focus_strong_rounded;
        break;
      case DetectionMode.currency:
        label = 'Currency Reader';
        icon = Icons.payments_rounded;
        break;
      case DetectionMode.medication:
        label = 'Medication Assistant';
        icon = Icons.medical_services_rounded;
        break;
      case DetectionMode.scene:
        label = 'Scene Description';
        icon = Icons.landscape_rounded;
        break;
      case DetectionMode.light:
        label = 'Light Detector';
        icon = Icons.lightbulb_rounded;
        break;
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: kDeepBlack.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: kAccentYellow.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left swipe hint arrow
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.2),
                size: 24,
              ),
              const SizedBox(width: 10),
              // Mode icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kAccentYellow.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: kAccentYellow, size: 20),
              ),
              const SizedBox(width: 12),
              // Mode label — oversized for AAA contrast
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: kAccentYellow,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  textDirection: TextDirection.ltr,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              // Right swipe hint arrow
              Icon(
                Icons.chevron_left_rounded,
                color: Colors.white.withValues(alpha: 0.2),
                size: 24,
              ),
            ],
          ),
        );
      },
    );
  }
}
