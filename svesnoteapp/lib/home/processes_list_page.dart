import 'package:flutter/material.dart';
import 'package:svesnoteapp/data/processes_repo.dart';
import 'package:svesnoteapp/models/process.dart';
import 'package:svesnoteapp/home/create_process_page.dart';
import 'package:svesnoteapp/home/process_details_page.dart';

class ProcessesListPage extends StatefulWidget {
  const ProcessesListPage({super.key});

  @override
  State<ProcessesListPage> createState() => _ProcessesListPageState();
}

class _ProcessesListPageState extends State<ProcessesListPage> {
  final ProcessesRepo _repo = ProcessesRepo();
  List<Process> _processes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProcesses();
  }

  Future<void> _loadProcesses() async {
    setState(() => _isLoading = true);
    try {
      final processes = await _repo.fetchProcesses();
      if (!mounted) return;
      setState(() {
        _processes = processes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading processes: $e')),
      );
    }
  }

  Future<void> _toggleProcessStatus(Process process) async {
    final newStatus = process.isActive ? 'paused' : 'active';
    try {
      await _repo.updateProcessStatus(
        processId: process.id,
        status: newStatus,
      );
      _loadProcesses();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating process: $e')),
      );
    }
  }

  Future<void> _navigateToCreateProcess() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateProcessPage()),
    );
    if (result == true) {
      _loadProcesses();
    }
  }

  Future<void> _navigateToProcessDetails(Process process) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProcessDetailsPage(process: process),
      ),
    );
    if (result == true) {
      _loadProcesses();
    }
  }

  Widget _buildProcessCard(Process process) {
    final isExpired = process.isExpired;
    final statusColor = process.isActive
        ? Colors.green
        : Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _navigateToProcessDetails(process),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      process.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          process.isActive ? Icons.play_arrow : Icons.pause,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          process.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                process.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    process.isTimeLimited
                        ? 'Until ${_formatDate(process.endDate!)}'
                        : 'Lifetime',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (isExpired) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'EXPIRED',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      process.isActive ? Icons.pause_circle : Icons.play_circle,
                      color: statusColor,
                    ),
                    onPressed: () => _toggleProcessStatus(process),
                    tooltip: process.isActive ? 'Pause' : 'Resume',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No processes yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Trust the process! Create your first one.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _processes.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadProcesses,
                  child: ListView.builder(
                    itemCount: _processes.length,
                    itemBuilder: (context, index) {
                      return _buildProcessCard(_processes[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateProcess,
        tooltip: 'Create Process',
        child: const Icon(Icons.add),
      ),
    );
  }
}
