import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart' hide PlayerState;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:svesnoteapp/audio/audio_playback_service.dart';
import 'package:svesnoteapp/auth/login_screen.dart';
import 'package:svesnoteapp/data/entries_repo.dart';
import 'package:svesnoteapp/models/entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final EntriesRepo _repo = EntriesRepo();
  final AudioPlaybackService _audio = AudioPlaybackService();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  List<Entry> _entries = [];
  bool _loading = true;
  bool _recording = false;
  bool _uploading = false;
  bool _recorderReady = false;
  bool _isPlaying = false;
  String? _error;
  String? _statusMessage;
  String? _recordingEntryId;
  String? _recordingFilePath;
  String? _playingEntryId;
  String? _playLoadingEntryId;
  Duration _recordDuration = Duration.zero;
  Duration _playPosition = Duration.zero;
  Duration _playDuration = Duration.zero;
  Timer? _recordTimer;
  Timer? _playTimer;
  StreamSubscription<PlayerState>? _playerSub;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _playerSub = _audio.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
      if (state.playing) {
        _startPlayTimer();
      } else {
        _stopPlayTimer();
      }
      if (state.processingState == ProcessingState.completed) {
        _stopPlayTimer();
        setState(() {
          _playingEntryId = null;
          _isPlaying = false;
          _playPosition = Duration.zero;
          _playDuration = Duration.zero;
        });
      }
    });
    _loadEntries();
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
      if (mounted) setState(() => _recorderReady = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Recorder initialization failed.');
      }
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _playTimer?.cancel();
    _recorder.closeRecorder();
    _playerSub?.cancel();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _repo.fetchEntries();
      if (!mounted) return;
      setState(() => _entries = entries);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Failed to load entries.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showSnackBar('Microphone permission is required.');
      return false;
    }
    return true;
  }

  Future<void> _startRecording() async {
    if (_recording || _uploading || !_recorderReady) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('Not authenticated.');
      return;
    }

    if (!await _ensureMicPermission()) return;

    setState(() {
      _error = null;
      _statusMessage = null;
    });

    try {
      final entry = await _repo.createEmptyEntry();
      final dir = await getApplicationDocumentsDirectory();
      final entriesDir = Directory('${dir.path}/svesnote');
      if (!await entriesDir.exists()) {
        await entriesDir.create(recursive: true);
      }
      final filePath = '${entriesDir.path}/${entry.id}.m4a';

      await _recorder.startRecorder(toFile: filePath, codec: Codec.aacMP4);

      _recordingEntryId = entry.id;
      _recordingFilePath = filePath;
      _recordDuration = Duration.zero;
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordDuration += const Duration(seconds: 1));
        }
      });

      if (!mounted) return;
      setState(() => _recording = true);
    } catch (_) {
      _showSnackBar('Failed to start recording.');
      _recordingEntryId = null;
      _recordingFilePath = null;
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('Not authenticated.');
      return;
    }

    final entryId = _recordingEntryId;
    final filePath = _recordingFilePath;
    if (entryId == null || filePath == null) {
      _showSnackBar('Recording is not initialized.');
      return;
    }

    setState(() {
      _recording = false;
      _uploading = true;
      _statusMessage = 'Uploading audio...';
    });

    _recordTimer?.cancel();

    try {
      await _recorder.stopRecorder();
      final durationSeconds = _recordDuration.inSeconds;
      final storagePath =
          '${user.id}/${_formatDateForPath(DateTime.now())}/$entryId.m4a';

      await Supabase.instance.client.storage
          .from('entries-audio')
          .upload(storagePath, File(filePath));

      await _repo.updateEntryAudio(
        entryId: entryId,
        userId: user.id,
        audioPath: storagePath,
        durationSeconds: durationSeconds,
      );

      await _loadEntries();

      if (mounted) {
        setState(() => _statusMessage = 'Audio uploaded ✅');
      }
    } catch (error) {
      _showSnackBar(_formatErrorMessage(error));
      if (mounted) setState(() => _statusMessage = null);
    } finally {
      _recordingEntryId = null;
      _recordingFilePath = null;
      _recordDuration = Duration.zero;
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _togglePlayback(Entry entry) async {
    final path = entry.audioPath;
    if (path == null || _playLoadingEntryId != null) return;

    if (_playingEntryId == entry.id && _isPlaying) {
      try {
        await _audio.pause();
        _stopPlayTimer();
        if (mounted) setState(() => _isPlaying = false);
      } catch (error) {
        _showSnackBar(_formatErrorMessage(error));
      }
      return;
    }

    setState(() {
      _playLoadingEntryId = entry.id;
      _statusMessage = null;
      _playPosition = Duration.zero;
      _playDuration = Duration.zero;
    });

    try {
      if (_playingEntryId != null && _playingEntryId != entry.id) {
        await _audio.stop();
      }
      await _audio.playEntry(path);
      if (!mounted) return;
      setState(() {
        _playingEntryId = entry.id;
        _isPlaying = true;
      });
      _startPlayTimer();
    } catch (error) {
      _showSnackBar(_formatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _playLoadingEntryId = null);
    }
  }

  void _startPlayTimer() {
    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final position = _audio.position;
      final duration = _audio.duration ?? Duration.zero;
      setState(() {
        _playPosition = position;
        _playDuration = duration;
      });

      if (_audio.processingState == ProcessingState.completed ||
          (duration > Duration.zero && position >= duration)) {
        _playTimer?.cancel();
        setState(() {
          _playingEntryId = null;
          _isPlaying = false;
          _playPosition = Duration.zero;
          _playDuration = Duration.zero;
        });
      }
    });
  }

  void _stopPlayTimer() {
    _playTimer?.cancel();
    _playTimer = null;
  }

  String _formatDateForPath(DateTime value) {
    final dt = value.toLocal();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateTime(DateTime value) {
    final dt = value.toLocal();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatSeconds(int seconds) {
    return _formatDuration(Duration(seconds: seconds));
  }

  String _buildTimeLabel(Entry entry) {
    final totalFromEntry = entry.durationSeconds != null
        ? Duration(seconds: entry.durationSeconds!)
        : null;
    final total = _playingEntryId == entry.id && _playDuration > Duration.zero
        ? _playDuration
        : totalFromEntry;
    final current = _playingEntryId == entry.id ? _playPosition : Duration.zero;

    if (total == null || total == Duration.zero) {
      return '--:-- / --:--';
    }
    return '${_formatDuration(current)} / ${_formatDuration(total)}';
  }

  String _previewTranscript(String? transcript) {
    if (transcript == null || transcript.trim().isEmpty) {
      return 'No transcript yet';
    }
    final trimmed = transcript.trim();
    return trimmed.length <= 40 ? trimmed : '${trimmed.substring(0, 40)}...';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatErrorMessage(Object error) {
    if (error is PlayerException) {
      final message = error.message?.trim();
      return message == null || message.isEmpty
          ? 'Audio playback error.'
          : 'Audio playback error: $message';
    }
    if (error is StorageException) {
      final status = error.statusCode != null ? ' (${error.statusCode})' : '';
      final message = error.message?.trim();
      return message == null || message.isEmpty
          ? 'Storage error$status'
          : 'Storage error$status: $message';
    }
    if (error is PostgrestException) {
      final message = error.message.trim();
      return message.isEmpty ? 'Database error.' : 'Database error: $message';
    }
    final text = error.toString().trim();
    return text.isEmpty ? 'Unexpected error.' : text;
  }

  Widget _buildEntriesList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _loadEntries,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [Text(_error!, style: const TextStyle(color: Colors.red))],
        ),
      );
    }

    if (_entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadEntries,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [Text('No entries yet.')],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const Divider(height: 24),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDateTime(entry.createdAt),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(_previewTranscript(entry.transcript)),
              if (entry.audioPath != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (_playLoadingEntryId == entry.id)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          _playingEntryId == entry.id && _isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                        onPressed: () => _togglePlayback(entry),
                      ),
                    const Text('Audio uploaded ✅'),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value:
                              _playingEntryId == entry.id &&
                                  ((_playDuration.inMilliseconds > 0) ||
                                      (entry.durationSeconds ?? 0) > 0)
                              ? (_playPosition.inMilliseconds /
                                        (_playDuration.inMilliseconds > 0
                                            ? _playDuration.inMilliseconds
                                            : (entry.durationSeconds ?? 0) *
                                                  1000))
                                    .clamp(0.0, 1.0)
                              : 0.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_buildTimeLabel(entry)),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '?';
    final usernameRaw = user?.userMetadata?['username'];
    final username = usernameRaw is String && usernameRaw.trim().isNotEmpty
        ? usernameRaw.trim()
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email: $email'),
                  const SizedBox(height: 4),
                  Text('Username: ${username ?? "?"}'),
                  const SizedBox(height: 12),
                  if (_recording)
                    Row(
                      children: [
                        Text('Recording ${_formatDuration(_recordDuration)}'),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _stopRecording,
                          child: const Text('Stop'),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _uploading || !_recorderReady
                            ? null
                            : _startRecording,
                        child: _uploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Record new entry'),
                      ),
                    ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(_statusMessage!),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildEntriesList()),
          ],
        ),
      ),
    );
  }
}
