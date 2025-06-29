// lib/screens/branch_manager/branch_manager_task_submit_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NEW: For FieldValue.serverTimestamp()
import '../../models/task.dart';
import '../../providers/task_provider.dart';

class BranchManagerTaskSubmitDialog extends StatefulWidget {
  final Task task;
  final List<String> capturedImages;
  final bool? yesNoResponse;

  const BranchManagerTaskSubmitDialog({
    super.key,
    required this.task,
    required this.capturedImages,
    required this.yesNoResponse,
  });

  @override
  State<BranchManagerTaskSubmitDialog> createState() => _BranchManagerTaskSubmitDialogState();
}

class _BranchManagerTaskSubmitDialogState extends State<BranchManagerTaskSubmitDialog> {
  final TextEditingController _commentsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _commentsController.text = widget.task.comments;
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  void _submitTask() async {
    final taskProvider = context.read<TaskProvider>();
    // Update task status, add comments, and set completedAt timestamp
    await taskProvider.updateTask(
      widget.task.id,
      {
        'status': 'Sent for Approval',
        'comments': _commentsController.text.trim(),
        'imagesCaptured': widget.capturedImages,
        'yesNoResponse': widget.yesNoResponse,
        'completedAt': FieldValue.serverTimestamp(), // NEW: Set completedAt here
      },
    );
    if (mounted) {
      Navigator.pop(context);
      Navigator.pop(context); // Pop the detail screen to go back to list
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task submitted for approval!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Comments & Submit'),
      content: TextField(
        controller: _commentsController,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Comments (Optional)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitTask,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}