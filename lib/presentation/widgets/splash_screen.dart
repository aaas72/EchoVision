import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  final bool isVoiceDownloading;
  final String voiceDownloadStatus;
  final double voiceDownloadProgress;

  const SplashScreen({
    super.key,
    this.isVoiceDownloading = false,
    this.voiceDownloadStatus = "",
    this.voiceDownloadProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    const kDeepBlack = Color(0xFF0A0A0A);
    const kAccentYellow = Color(0xFFFFD600);

    return Container(
      color: kDeepBlack,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing eye icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kAccentYellow.withValues(alpha: 0.15),
                    kAccentYellow.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.3, 0.7, 1.0],
                ),
                border: Border.all(
                  color: kAccentYellow.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kAccentYellow.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.visibility_rounded,
                color: kAccentYellow,
                size: 42,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'ECHOVISION',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Smart Assistant',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: 2,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 40),
            if (isVoiceDownloading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  voiceDownloadStatus,
                  style: const TextStyle(
                    color: kAccentYellow,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: voiceDownloadProgress >= 0.0 ? voiceDownloadProgress : null,
                    backgroundColor: Colors.white10,
                    color: kAccentYellow,
                    minHeight: 5,
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    backgroundColor: Colors.white10,
                    color: kAccentYellow,
                    minHeight: 3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
