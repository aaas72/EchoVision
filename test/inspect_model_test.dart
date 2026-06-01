import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  test('Inspect Lira TFLite Model', () {
    final file = File('assets/models/lira.tflite');
    expect(file.existsSync(), true, reason: 'lira.tflite should exist in assets/models/');
    
    final interpreter = Interpreter.fromFile(file);
    print('==================================================');
    print('TFLITE MODEL DIAGNOSTICS:');
    print('Input tensors length: ${interpreter.getInputTensors().length}');
    for (var i = 0; i < interpreter.getInputTensors().length; i++) {
      final t = interpreter.getInputTensors()[i];
      print('Input #$i: name="${t.name}", shape=${t.shape}, type=${t.type}');
    }
    
    print('Output tensors length: ${interpreter.getOutputTensors().length}');
    for (var i = 0; i < interpreter.getOutputTensors().length; i++) {
      final t = interpreter.getOutputTensors()[i];
      print('Output #$i: name="${t.name}", shape=${t.shape}, type=${t.type}');
    }
    print('==================================================');

    // Test inference with a zero float32 input (shape [1, 224, 224, 3])
    final input = Float32List(1 * 224 * 224 * 3); // all zeros
    final output = Float32List(6).reshape([1, 6]);
    
    try {
      interpreter.run(input.reshape([1, 224, 224, 3]), output);
      print('Inference succeeded with Float32List!');
      print('Output array: ${output[0]}');
    } catch (e) {
      print('Inference failed with Float32List: $e');
    }
    
    interpreter.close();
  });
}
