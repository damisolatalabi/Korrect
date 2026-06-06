import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordedAudio {
  final File? file;
  final Uint8List? bytes;
  final String filename;

  RecordedAudio({this.file, this.bytes, required this.filename});
}

class AudioService {
  static AudioRecorder? _recorder;

  static AudioRecorder _getRecorder() {
    return _recorder ??= AudioRecorder();
  }

  static Future<bool> hasPermission() async {
    return await _getRecorder().hasPermission();
  }

  static Future<void> startRecording() async {
    final String path;
    if (kIsWeb) {
      path = '';
    } else {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/korrect_recording.wav';
    }

    await _getRecorder().start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        androidConfig: AndroidRecordConfig(
          useLegacy: true,
          manageBluetooth: false,
          audioSource: AndroidAudioSource.mic,
        ),
      ),
      path: path,
    );
  }

  static Future<RecordedAudio?> stopRecording() async {
    final path = await _getRecorder().stop();
    if (path == null) return null;

    if (kIsWeb) {
      final response = await http.get(Uri.parse(path));
      if (response.statusCode != 200) return null;
      return RecordedAudio(bytes: response.bodyBytes, filename: 'audio.webm');
    }

    final file = File(path);
    if (!await file.exists()) return null;
    return RecordedAudio(file: file, filename: 'audio.wav');
  }

  static Future<bool> isRecording() async {
    return await _getRecorder().isRecording();
  }

  static Future<void> dispose() async {
    final recorder = _recorder;
    if (recorder == null) return;
    _recorder = null;
    try {
      await recorder.dispose();
    } catch (_) {}
  }
}
