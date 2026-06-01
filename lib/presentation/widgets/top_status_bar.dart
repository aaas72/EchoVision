import 'package:flutter/material.dart';

class TopStatusBar extends StatelessWidget {
  final bool isFlashOn;
  final bool isMuted;

  const TopStatusBar({
    super.key,
    required this.isFlashOn,
    required this.isMuted,
  });

  @override
  Widget build(BuildContext context) {
    const kDeepBlack = Color(0xFF0A0A0A);
    const kAccentYellow = Color(0xFFFFD600);

    return Row(
      children: [
        // App Name / Brand Accent
        const Text(
          'ECHOVISION',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
        ),
        const Spacer(),
        // Flash pill
        if (isFlashOn)
          _statusPill(
            icon: Icons.flashlight_on_rounded,
            label: 'Flash',
            color: kAccentYellow,
            backgroundColor: kDeepBlack,
          ),
        if (isFlashOn) const SizedBox(width: 8),
        // Mute pill
        if (isMuted)
          _statusPill(
            icon: Icons.volume_off_rounded,
            label: 'Muted',
            color: Colors.red.shade400,
            backgroundColor: kDeepBlack,
          ),
      ],
    );
  }

  Widget _statusPill({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
