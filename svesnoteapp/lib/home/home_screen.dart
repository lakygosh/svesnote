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
import 'package:svesnoteapp/home/calendar_widget.dart';
import 'package:svesnoteapp/home/profile_page.dart';
import 'package:svesnoteapp/home/processes_list_page.dart';
import 'package:svesnoteapp/models/entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
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

  // Calendar state
  DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime? _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  bool _calendarExpanded = true;
  Map<DateTime, int> _entryCountsByDay = {};
  List<Entry> _allMonthEntries = [];
  int _currentPageIndex = 0; // 0: Notes/Analysis, 1: Processes, 2: Statistics

  // Selection mode state
  bool _selectionMode = false;
  Set<String> _selectedEntryIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _loadMonthEntries();
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
    _tabController?.dispose();
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
      List<Entry> entries;
      if (_selectedDate != null) {
        entries = await _repo.fetchEntriesByDate(_selectedDate!);
      } else {
        entries = await _repo.fetchEntries();
      }
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

  Future<void> _loadMonthEntries() async {
    try {
      final startOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      final endOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0, 23, 59, 59);

      final monthEntries = await _repo.fetchEntriesByDateRange(
        startDate: startOfMonth,
        endDate: endOfMonth,
      );

      if (!mounted) return;

      setState(() {
        _allMonthEntries = monthEntries;
        _entryCountsByDay = _calculateEntryCounts(monthEntries);
      });
    } catch (_) {
      if (mounted) setState(() => _entryCountsByDay = {});
    }
  }

  Map<DateTime, int> _calculateEntryCounts(List<Entry> entries) {
    final counts = <DateTime, int>{};

    for (final entry in entries) {
      final dateKey = _normalizeDate(entry.createdAt);
      counts[dateKey] = (counts[dateKey] ?? 0) + 1;
    }

    return counts;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  void _handleDateSelection(DateTime? date) {
    setState(() {
      if (date != null && _selectedDate != null &&
          _selectedDate!.year == date.year &&
          _selectedDate!.month == date.month &&
          _selectedDate!.day == date.day) {
        _selectedDate = null;
      } else {
        _selectedDate = date;
      }
    });
    _loadEntries();
  }

  // Selection mode methods
  void _enterSelectionMode(String entryId) {
    setState(() {
      _selectionMode = true;
      _selectedEntryIds.add(entryId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedEntryIds.clear();
    });
  }

  void _toggleEntrySelection(String entryId) {
    setState(() {
      if (_selectedEntryIds.contains(entryId)) {
        _selectedEntryIds.remove(entryId);
        if (_selectedEntryIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedEntryIds.add(entryId);
      }
    });
  }

  Future<void> _deleteSelectedEntries() async {
    final count = _selectedEntryIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Voice Entries'),
        content: Text(
          count == 1
              ? 'Delete 1 voice entry? This cannot be undone.'
              : 'Delete $count voice entries? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.deleteEntries(_selectedEntryIds.toList());
        if (!mounted) return;

        setState(() {
          _selectionMode = false;
          _selectedEntryIds.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 1
                  ? '1 voice entry deleted'
                  : '$count voice entries deleted',
            ),
          ),
        );

        _loadEntries();
        _loadMonthEntries();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting entries: $e')),
        );
      }
    }
  }

  Future<void> _handleMonthChange(DateTime newMonth) async {
    setState(() {
      _focusedMonth = DateTime(newMonth.year, newMonth.month, 1);
    });
    await _loadMonthEntries();
  }

  void _toggleCalendar() {
    setState(() {
      _calendarExpanded = !_calendarExpanded;
    });
  }

  String _formatDateForDisplay(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  List<int> _calculateAvailableYears() {
    final currentYear = DateTime.now().year;

    if (_entries.isEmpty && _allMonthEntries.isEmpty) {
      return List.generate(5, (i) => currentYear - 2 + i);
    }

    final allEntries = [..._entries, ..._allMonthEntries];
    final years = allEntries.map((e) => e.createdAt.year).toSet();
    final minYear = years.reduce((a, b) => a < b ? a : b);
    final maxYear = years.reduce((a, b) => a > b ? a : b);

    final start = minYear < currentYear ? minYear : currentYear;
    final end = maxYear > currentYear ? maxYear : currentYear + 1;

    return List.generate(end - start + 1, (i) => start + i);
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
      _showRecordingBottomSheet();
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
      await _loadMonthEntries();

      if (mounted) {
        _showSnackBar('Audio uploaded successfully');
      }
    } catch (error) {
      _showSnackBar(_formatErrorMessage(error));
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
      final message = _selectedDate != null
          ? 'No entries for ${_formatDateForDisplay(_selectedDate!)}'
          : 'No entries yet.';

      return RefreshIndicator(
        onRefresh: _loadEntries,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    Widget? selectedDateBanner;
    if (_selectedDate != null) {
      selectedDateBanner = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.blue.shade50,
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              _formatDateForDisplay(_selectedDate!),
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: Column(
        children: [
          if (selectedDateBanner != null) selectedDateBanner,
          Expanded(
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              separatorBuilder: (_, _) => const Divider(height: 24),
              itemBuilder: (context, index) {
          final entry = _entries[index];
          final isSelected = _selectedEntryIds.contains(entry.id);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () {
              if (!_selectionMode) {
                _enterSelectionMode(entry.id);
              }
            },
            onTap: () {
              if (_selectionMode) {
                _toggleEntrySelection(entry.id);
              }
            },
            child: Card(
              color: isSelected ? Colors.blue.shade100 : null,
              elevation: isSelected ? 4 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDateTime(entry.createdAt),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (_selectionMode)
                        Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? Colors.blue : Colors.grey,
                        ),
                    ],
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
                        else if (!_selectionMode)
                          IconButton(
                            icon: Icon(
                              _playingEntryId == entry.id && _isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                            onPressed: () => _togglePlayback(entry),
                          ),
                        if (!_selectionMode)
                          const Text('Audio uploaded ✅'),
                      ],
                    ),
                    if (!_selectionMode)
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
              ),
            ),
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordingBottomSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Recording ${_formatDuration(_recordDuration)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _stopRecording();
              },
              icon: const Icon(Icons.stop),
              label: const Text('Stop Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () {
                Navigator.of(context).pop();
                Supabase.instance.client.auth.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.grey),
              title: const Text('Switch Account'),
              subtitle: const Text('Coming soon'),
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisTab() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Analysis',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Voice note analysis coming soon',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsPage() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Statistics',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Insights and statistics coming soon',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              ),
              title: Text('${_selectedEntryIds.length} selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelectedEntries,
                  tooltip: 'Delete',
                ),
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton.large(
        onPressed: _uploading || !_recorderReady
            ? null
            : (_recording ? null : _startRecording),
        child: _uploading
            ? const CircularProgressIndicator(color: Colors.white)
            : Icon(_recording ? Icons.mic : Icons.mic_none, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(
                Icons.notes,
                color: _currentPageIndex == 0 ? Colors.blue : null,
              ),
              onPressed: () {
                setState(() => _currentPageIndex = 0);
              },
              tooltip: 'Notes',
            ),
            IconButton(
              icon: Icon(
                Icons.sync,
                color: _currentPageIndex == 1 ? Colors.blue : null,
              ),
              onPressed: () {
                setState(() => _currentPageIndex = 1);
              },
              tooltip: 'Processes',
            ),
            const SizedBox(width: 48), // Space for FAB
            IconButton(
              icon: Icon(
                Icons.bar_chart,
                color: _currentPageIndex == 2 ? Colors.blue : null,
              ),
              onPressed: () {
                setState(() => _currentPageIndex = 2);
              },
              tooltip: 'Statistics',
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
              onLongPress: () {
                _showLogoutBottomSheet();
              },
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Icon(Icons.account_circle, size: 28),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _currentPageIndex == 1
            ? const ProcessesListPage()
            : _currentPageIndex == 2
                ? _buildStatisticsPage()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CalendarWidget(
                        focusedMonth: _focusedMonth,
                        selectedDate: _selectedDate,
                        entryCountsByDay: _entryCountsByDay,
                        onDateSelected: _handleDateSelection,
                        onMonthChanged: _handleMonthChange,
                        isExpanded: _calendarExpanded,
                        onToggleExpand: _toggleCalendar,
                        isRecording: _recording,
                        availableYears: _calculateAvailableYears(),
                      ),
                      const Divider(height: 1),
                      if (_tabController != null) ...[
                        TabBar(
                          controller: _tabController!,
                          tabs: const [
                            Tab(text: 'Notes'),
                            Tab(text: 'Analysis'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController!,
                            children: [
                              _buildEntriesList(),
                              _buildAnalysisTab(),
                            ],
                          ),
                        ),
                      ] else
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
      ),
    );
  }
}
