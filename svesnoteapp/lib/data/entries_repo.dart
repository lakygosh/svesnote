import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:svesnoteapp/models/entry.dart';

class EntriesRepo {
  EntriesRepo({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Entry>> fetchEntries() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    final data = await _client
        .from('entries')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final list = data as List<dynamic>;
    return list
        .map((row) => Entry.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Entry> createEmptyEntry() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    final data = await _client
        .from('entries')
        .insert({
          'user_id': user.id,
          'audio_path': null,
          'transcript': null,
          'duration_seconds': null,
        })
        .select()
        .single();

    return Entry.fromJson(data);
  }

  Future<void> updateEntryAudio({
    required String entryId,
    required String userId,
    required String audioPath,
    required int durationSeconds,
  }) async {
    await _client
        .from('entries')
        .update({'audio_path': audioPath, 'duration_seconds': durationSeconds})
        .eq('id', entryId)
        .eq('user_id', userId);
  }

  Future<List<Entry>> fetchEntriesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    final data = await _client
        .from('entries')
        .select('*')
        .eq('user_id', user.id)
        .gte('created_at', startDate.toUtc().toIso8601String())
        .lte('created_at', endDate.toUtc().toIso8601String())
        .order('created_at', ascending: false);

    final list = data as List<dynamic>;
    return list
        .map((row) => Entry.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Entry>> fetchEntriesByDate(DateTime date) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final data = await _client
        .from('entries')
        .select('*')
        .eq('user_id', user.id)
        .gte('created_at', startOfDay.toUtc().toIso8601String())
        .lte('created_at', endOfDay.toUtc().toIso8601String())
        .order('created_at', ascending: false);

    final list = data as List<dynamic>;
    return list
        .map((row) => Entry.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteEntry(String entryId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    // First, get the entry to find the audio path
    final data = await _client
        .from('entries')
        .select('audio_path')
        .eq('id', entryId)
        .eq('user_id', user.id)
        .maybeSingle();

    // Delete the audio file from storage if it exists
    if (data != null && data['audio_path'] != null) {
      final audioPath = data['audio_path'] as String;
      try {
        await _client.storage.from('entries-audio').remove([audioPath]);
      } catch (e) {
        // Continue even if storage deletion fails
      }
    }

    // Delete the database record
    await _client
        .from('entries')
        .delete()
        .eq('id', entryId)
        .eq('user_id', user.id);
  }

  Future<void> deleteEntries(List<String> entryIds) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    // Get all entries to find audio paths
    final data = await _client
        .from('entries')
        .select('id, audio_path')
        .eq('user_id', user.id)
        .inFilter('id', entryIds);

    // Collect audio paths to delete
    final audioPaths = <String>[];
    for (final row in data as List<dynamic>) {
      final audioPath = row['audio_path'];
      if (audioPath != null) {
        audioPaths.add(audioPath as String);
      }
    }

    // Delete audio files from storage
    if (audioPaths.isNotEmpty) {
      try {
        await _client.storage.from('entries-audio').remove(audioPaths);
      } catch (e) {
        // Continue even if storage deletion fails
      }
    }

    // Delete database records
    await _client
        .from('entries')
        .delete()
        .eq('user_id', user.id)
        .inFilter('id', entryIds);
  }
}
