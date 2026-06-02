import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  writeWav('assets/sounds/start.wav', [(800, 100)]);
  writeWav('assets/sounds/success.wav', [(1000, 100), (0, 50), (1200, 150)]);
  writeWav('assets/sounds/error.wav', [(300, 400)]);
}

void writeWav(String filename, List<(int freq, int durationMs)> notes) {
  final sampleRate = 44100;
  final numChannels = 1;
  final bitsPerSample = 16;
  
  List<int> samples = [];
  for (final note in notes) {
    final freq = note.$1;
    final durationMs = note.$2;
    final numSamples = (sampleRate * durationMs / 1000).round();
    
    for (int i = 0; i < numSamples; i++) {
      int sample = 0;
      if (freq > 0) {
        sample = (32767.0 * sin(2.0 * pi * freq * i / sampleRate)).round();
      }
      samples.add(sample & 0xFF);
      samples.add((sample >> 8) & 0xFF);
    }
  }

  final dataSize = samples.length;
  final fileSize = 36 + dataSize;
  
  final file = File(filename);
  final builder = BytesBuilder();
  
  builder.add('RIFF'.codeUnits);
  builder.add(_int32ToBytes(fileSize));
  builder.add('WAVE'.codeUnits);
  builder.add('fmt '.codeUnits);
  builder.add(_int32ToBytes(16)); // PCM chunk size
  builder.add([1, 0]); // Audio format (PCM)
  builder.add([numChannels, 0]);
  builder.add(_int32ToBytes(sampleRate));
  builder.add(_int32ToBytes(sampleRate * numChannels * bitsPerSample ~/ 8)); // Byte rate
  builder.add([numChannels * bitsPerSample ~/ 8, 0]); // Block align
  builder.add([bitsPerSample, 0]); // Bits per sample
  
  builder.add('data'.codeUnits);
  builder.add(_int32ToBytes(dataSize));
  builder.add(samples);
  
  file.writeAsBytesSync(builder.toBytes());
  print('Generated $filename');
}

List<int> _int32ToBytes(int value) {
  return [
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ];
}
