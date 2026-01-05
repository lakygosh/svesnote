import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AudioPlaybackService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playEntry(String audioPath) async {
    final url = await Supabase.instance.client.storage
        .from('entries-audio')
        .createSignedUrl(audioPath, 300);
    await _player.setUrl(url);
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  ProcessingState get processingState => _player.processingState;
  bool get isPlaying => _player.playing;
}
