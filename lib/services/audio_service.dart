import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;

  Future<bool> hasPermission() async {
    return _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    final dir = await getApplicationDocumentsDirectory();
    _recordingPath = p.join(dir.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.wav');
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav),
      path: _recordingPath!,
    );
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    return path;
  }

  Stream<double> get amplitude => _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).map((a) => a.current);

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
