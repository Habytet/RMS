// lib/screens/manager_admin/staff_assigned_task_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/task.dart';
import '../../models/app_user.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_provider.dart';

class StaffAssignedTaskDetailScreen extends StatefulWidget {
  final Task task;
  const StaffAssignedTaskDetailScreen({super.key, required this.task});

  @override
  State<StaffAssignedTaskDetailScreen> createState() => _StaffAssignedTaskDetailScreenState();
}

class _StaffAssignedTaskDetailScreenState extends State<StaffAssignedTaskDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _selectedAssignedToId;
  late DateTime _assignedDate; // Now includes time component
  late DateTime _dueTime;
  bool _isRepeating = false;

  List<AppUser> _assignableUsers = [];
  bool _isLoadingUsers = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description);
    _selectedAssignedToId = widget.task.assignedToId;
    _assignedDate = widget.task.assignedDate;
    _dueTime = widget.task.dueTime;
    _isRepeating = widget.task.isRepeating;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = context.watch<UserProvider>();
    if (!userProvider.isLoadingUsers && _assignableUsers.isEmpty) {
      final currentUserBranchId = userProvider.currentBranchId;
      final users = userProvider.users
          .where((u) =>
      (userProvider.currentUser!.isAdmin || u.branchId == currentUserBranchId) &&
          u.email != userProvider.currentUser!.email &&
          u.canViewOwnTasks
      )
          .toList();

      setState(() {
        _assignableUsers = users;
        _isLoadingUsers = false;
        if (_selectedAssignedToId != null && !users.any((u) => u.email == _selectedAssignedToId)) {
          _selectedAssignedToId = null;
        }
      });
    } else if (userProvider.isLoadingUsers && !_isLoadingUsers) {
      setState(() {
        _isLoadingUsers = true;
      });
    }
  }

  Future<void> _pickAssignedDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _assignedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (pickedDate != null) {
      setState(() {
        _assignedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, _assignedDate.hour, _assignedDate.minute);
        if (_dueTime.isBefore(_assignedDate)) {
          _dueTime = _assignedDate.add(const Duration(hours: 24));
        }
      });
    }
  }

  Future<void> _pickAssignedTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_assignedDate),
    );
    if (pickedTime != null) {
      setState(() {
        _assignedDate = DateTime(_assignedDate.year, _assignedDate.month, _assignedDate.day, pickedTime.hour, pickedTime.minute);
        if (_dueTime.isBefore(_assignedDate)) {
          _dueTime = _assignedDate.add(const Duration(hours: 1));
        }
      });
    }
  }

  Future<void> _pickDueDate() async { // NEW: Method for picking due date
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueTime.isAfter(_assignedDate) ? _dueTime : _assignedDate, // Initial date should be at least assignedDate
      firstDate: _assignedDate, // Due date cannot be before assigned date
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (pickedDate != null) {
      setState(() {
        _dueTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, _dueTime.hour, _dueTime.minute);
      });
    }
  }

  Future<void> _pickDueTime() async {
    final TimeOfDay initialTime = TimeOfDay.fromDateTime(
        _dueTime.isAfter(_assignedDate) ? _dueTime : _assignedDate.add(const Duration(minutes: 1))
    );

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime != null) {
      setState(() {
        final newDueDateTime = DateTime(_dueTime.year, _dueTime.month, _dueTime.day, pickedTime.hour, pickedTime.minute);
        if (newDueDateTime.isBefore(_assignedDate)) {
          _dueTime = _assignedDate.add(const Duration(minutes: 1));
        } else {
          _dueTime = newDueDateTime;
        }
      });
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _saveChanges() async {
    // Final check to ensure due time is not before assigned time
    if (_dueTime.isBefore(_assignedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Due time cannot be before assigned time.')));
      return;
    }

    final taskProvider = context.read<TaskProvider>();
    final updatedData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'assignedToId': _selectedAssignedToId,
      'assignedDate': Timestamp.fromDate(_assignedDate),
      'dueTime': Timestamp.fromDate(_dueTime),
      'isRepeating': _isRepeating,
    };
    try {
      await taskProvider.updateTask(widget.task.id, updatedData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task updated successfully!')));
        _toggleEdit();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
    }
  }

  void _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text('Are you sure you want to delete "${widget.task.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await context.read<TaskProvider>().deleteTask(widget.task.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted successfully!')));
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final canEdit = userProvider.currentUser?.canEditAssignedTasks ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task.title),
        actions: [
          if (canEdit && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _toggleEdit,
              tooltip: 'Edit Task',
            ),
        ],
      ),
      body: _isLoadingUsers
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Task Title'),
              readOnly: !_isEditing,
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
              readOnly: !_isEditing,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedAssignedToId,
              hint: const Text('Assign To'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _assignableUsers.map((user) {
                return DropdownMenuItem(
                  value: user.email,
                  child: Text(user.username.isEmpty ? user.email : user.username),
                );
              }).toList(),
              onChanged: _isEditing ? (value) {
                setState(() {
                  _selectedAssignedToId = value;
                });
              } : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text('Assigned Date: ${DateFormat('MMM dd, yyyy').format(_assignedDate)}'),
              trailing: canEdit && _isEditing ? const Icon(Icons.calendar_today) : null,
              onTap: canEdit && _isEditing ? _pickAssignedDate : null,
            ),
            ListTile(
              title: Text('Assigned Time: ${DateFormat('hh:mm a').format(_assignedDate)}'),
              trailing: canEdit && _isEditing ? const Icon(Icons.access_time) : null,
              onTap: canEdit && _isEditing ? _pickAssignedTime : null,
            ),
            const Divider(),
            ListTile( // NEW: Due Date picker
              title: Text('Due Date: ${DateFormat('MMM dd, yyyy').format(_dueTime)}'),
              trailing: canEdit && _isEditing ? const Icon(Icons.calendar_today) : null,
              onTap: canEdit && _isEditing ? _pickDueDate : null,
            ),
            ListTile(
              title: Text('Due Time: ${DateFormat('hh:mm a').format(_dueTime)}'),
              trailing: canEdit && _isEditing ? const Icon(Icons.access_time) : null,
              onTap: canEdit && _isEditing ? _pickDueTime : null,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Repeat Daily'),
              value: _isRepeating,
              onChanged: _isEditing ? (value) {
                setState(() {
                  _isRepeating = value;
                });
              } : null,
            ),
            const SizedBox(height: 20),

            if (_isEditing)
              ElevatedButton(
                onPressed: _saveChanges,
                child: const Text('Save Changes'),
              ),
            const SizedBox(height: 10),
            if (canEdit && !_isEditing)
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete Task'),
                onPressed: _deleteTask,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}