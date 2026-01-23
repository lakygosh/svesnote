import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:svesnoteapp/models/process.dart';

class ProcessesRepo {
  ProcessesRepo({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Process>> fetchProcesses() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    final data = await _client
        .from('processes')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final list = data as List<dynamic>;
    return list
        .map((row) => Process.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Process> createProcess({
    required String name,
    required String description,
    DateTime? endDate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    final data = await _client
        .from('processes')
        .insert({
          'user_id': user.id,
          'name': name,
          'description': description,
          'status': 'active',
          'end_date': endDate?.toUtc().toIso8601String(),
        })
        .select()
        .single();

    return Process.fromJson(data);
  }

  Future<void> updateProcess({
    required String processId,
    required String name,
    required String description,
    DateTime? endDate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    await _client
        .from('processes')
        .update({
          'name': name,
          'description': description,
          'end_date': endDate?.toUtc().toIso8601String(),
        })
        .eq('id', processId)
        .eq('user_id', user.id);
  }

  Future<void> updateProcessStatus({
    required String processId,
    required String status,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    await _client
        .from('processes')
        .update({'status': status})
        .eq('id', processId)
        .eq('user_id', user.id);
  }

  Future<void> deleteProcess(String processId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    await _client
        .from('processes')
        .delete()
        .eq('id', processId)
        .eq('user_id', user.id);
  }

  Future<List<Process>> fetchActiveProcesses() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    final data = await _client
        .from('processes')
        .select('*')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    final list = data as List<dynamic>;
    return list
        .map((row) => Process.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
