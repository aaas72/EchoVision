import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final bool isSpeaking;
  final String? currentSpokenWord;
  final Animation<double> resultFadeAnim;

  const ResultCard({
    super.key,
    required this.isSpeaking,
    required this.currentSpokenWord,
    required this.resultFadeAnim,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSpeaking || currentSpokenWord == null) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: resultFadeAnim,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              currentSpokenWord!.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                height: 1.4,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
