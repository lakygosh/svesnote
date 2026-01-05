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

    return Entry.fromJson(data as Map<String, dynamic>);
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
}
