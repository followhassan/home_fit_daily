// Generates the short cue sounds in assets/audio/.
//
// The tones are synthesised sine waves created for this project, so they
// carry no third-party license. Re-run with:
//   dart run tool/generate_tones.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sampleRate = 44100;

void main() {
  final dir = Directory('assets/audio')..createSync(recursive: true);
  _write('${dir.path}/tick.wav', [(1000.0, 0.07)], volume: 0.45);
  _write('${dir.path}/go.wav', [(880.0, 0.09), (1320.0, 0.20)], volume: 0.5);
  _write('${dir.path}/rest.wav', [(660.0, 0.16), (523.25, 0.22)], volume: 0.45);
  _write('${dir.path}/complete.wav', [
    (523.25, 0.14),
    (659.25, 0.14),
    (783.99, 0.14),
    (1046.5, 0.32),
  ], volume: 0.45);
  stdout.writeln('Wrote tones to ${dir.path}');
}

/// Writes consecutive (frequency Hz, duration s) notes as 16-bit mono PCM.
void _write(String path, List<(double, double)> notes, {required double volume}) {
  final samples = <int>[];
  for (final (frequency, duration) in notes) {
    final count = (duration * _sampleRate).round();
    final fade = (0.006 * _sampleRate).round();
    for (var i = 0; i < count; i++) {
      // Short linear fade in/out avoids audible clicks.
      final envelope = math.min(1.0, math.min(i / fade, (count - i) / fade));
      final value = math.sin(2 * math.pi * frequency * i / _sampleRate) * volume * envelope;
      samples.add((value * 32767).round().clamp(-32768, 32767));
    }
  }
  final dataSize = samples.length * 2;
  final bytes = ByteData(44 + dataSize);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, _sampleRate, Endian.little);
  bytes.setUint32(28, _sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  File(path).writeAsBytesSync(bytes.buffer.asUint8List());
}
