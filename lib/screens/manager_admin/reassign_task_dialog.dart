// lib/screens/manager_admin/reassign_task_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // FIX: Missing import
import '../../models/task.dart';
import '../../providers/task_provider.dart';

class ReassignTaskDialog extends StatefulWidget {
  final Task task;
  const ReassignTaskDialog({super.key, required this.task});

  @override
  State<ReassignTaskDialog> createState() => _ReassignTaskDialogState();
}

class _ReassignTaskDialogState extends State<ReassignTaskDialog> {
  late DateTime _newAssignedDate;
  late DateTime _newDueTime;
  final TextEditingController _reassignCommentsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _newAssignedDate = DateTime.now(); // Default to today
    _newDueTime = DateTime.now().add(const Duration(hours: 24)); // Default to 24 hours from now
  }

  Future<void> _pickNewAssignedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newAssignedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _newAssignedDate = DateTime(picked.year, picked.month, picked.day, _newAssignedDate.hour, _newAssignedDate.minute);
        if (_newDueTime.isBefore(_newAssignedDate)) {
          _newDueTime = _newAssignedDate.add(const Duration(hours: 24));
        }
      });
    }
  }

  Future<void> _pickNewDueTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_newDueTime),
    );
    if (pickedTime != null) {
      setState(() {
        _newDueTime = DateTime(_newDueTime.year, _newDueTime.month, _newDueTime.day, pickedTime.hour, pickedTime.minute);
        if (_newDueTime.isBefore(_newAssignedDate)) {
          _newDueTime = DateTime(_newAssignedDate.year, _newAssignedDate.month, _newAssignedDate.day, pickedTime.hour, pickedTime.minute);
        }
      });
    }
  }

  void _reassignTask() async {
    final taskProvider = context.read<TaskProvider>();
    try {
      await taskProvider.updateTask(
        widget.task.id,
        {
          'status': 'Assigned', // Or 'In Progress' if you want it to immediately be in progress for the staff
          'assignedDate': Timestamp.fromDate(_newAssignedDate), // FIX: Use Timestamp
          'dueTime': Timestamp.fromDate(_newDueTime), // FIX: Use Timestamp
          'comments': _reassignCommentsController.text.trim(), // Manager's comments on reassign
          'imagesCaptured': [], // Clear captured images on reassign
          'yesNoResponse': null, // Reset Yes/No response
        },
      );
      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context); // Pop the completed detail screen
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task reassigned successfully!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reassign task: $e')));
    }
  }

  @override
  void dispose() {
    _reassignCommentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reassign Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('New Assigned Date: ${DateFormat('MMM dd, yyyy').format(_newAssignedDate)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickNewAssignedDate,
            ),
            ListTile(
              title: Text('New Due Time: ${DateFormat('hh:mm a').format(_newDueTime)}'),
              trailing: const Icon(Icons.access_time),
              onTap: _pickNewDueTime,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reassignCommentsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comments for Reassignment (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _reassignTask,
          child: const Text('Reassign'),
        ),
      ],
    );
  }
}