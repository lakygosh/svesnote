import 'package:flutter/material.dart';
import 'package:svesnoteapp/data/processes_repo.dart';
import 'package:svesnoteapp/models/process.dart';

class EditProcessPage extends StatefulWidget {
  final Process process;

  const EditProcessPage({
    super.key,
    required this.process,
  });

  @override
  State<EditProcessPage> createState() => _EditProcessPageState();
}

class _EditProcessPageState extends State<EditProcessPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final ProcessesRepo _repo = ProcessesRepo();

  late bool _isTimeLimited;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.process.name);
    _descriptionController = TextEditingController(text: widget.process.description);
    _isTimeLimited = widget.process.isTimeLimited;
    _endDate = widget.process.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 years
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _updateProcess() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isTimeLimited && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an end date')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _repo.updateProcess(
        processId: widget.process.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        endDate: _isTimeLimited ? _endDate : null,
      );

      if (!mounted) return;

      // Return updated process
      final updatedProcess = Process(
        id: widget.process.id,
        userId: widget.process.userId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        status: widget.process.status,
        createdAt: widget.process.createdAt,
        endDate: _isTimeLimited ? _endDate : null,
      );

      Navigator.pop(context, updatedProcess);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating process: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Process'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update your process',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Make changes to keep your process on track.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Process Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Lifetime'),
                            subtitle: const Text('No end date'),
                            value: false,
                            groupValue: _isTimeLimited,
                            onChanged: (value) {
                              setState(() {
                                _isTimeLimited = value!;
                                if (!_isTimeLimited) {
                                  _endDate = null;
                                }
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Time Limited'),
                            subtitle: const Text('Set end date'),
                            value: true,
                            groupValue: _isTimeLimited,
                            onChanged: (value) {
                              setState(() {
                                _isTimeLimited = value!;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    if (_isTimeLimited) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: Text(
                            _endDate != null
                                ? 'End Date: ${_formatDate(_endDate!)}'
                                : 'Select End Date',
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: _selectEndDate,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _updateProcess,
                        child: const Text(
                          'Update Process',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
