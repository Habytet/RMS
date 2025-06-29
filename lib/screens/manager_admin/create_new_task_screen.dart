// lib/screens/manager_admin/create_new_task_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../models/app_user.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_provider.dart';

class CreateNewTaskScreen extends StatefulWidget {
  const CreateNewTaskScreen({super.key});

  @override
  State<CreateNewTaskScreen> createState() => _CreateNewTaskScreenState();
}

class _CreateNewTaskScreenState extends State<CreateNewTaskScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedAssignedToId;
  DateTime _assignedDate = DateTime.now(); // Now includes time component
  DateTime _dueTime = DateTime.now().add(const Duration(hours: 24)); // Default to 24 hours from now
  bool _imageRequired = false;
  bool _yesNoRequired = false;
  bool _isRepeating = false;

  List<AppUser> _assignableUsers = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args != null && args is Map<String, dynamic> && args.containsKey('assignedToId')) {
          setState(() {
            _selectedAssignedToId = args['assignedToId'] as String?;
          });
        }
      }
    });
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
        if (_assignableUsers.isNotEmpty && _selectedAssignedToId == null) {
          _selectedAssignedToId = _assignableUsers.first.email;
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
      // Keep the current time component when updating the date
      setState(() {
        _assignedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, _assignedDate.hour, _assignedDate.minute);
        // If due date becomes before assigned date, adjust due date to assigned date + 24 hours
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
        // If due time becomes before assigned time, adjust due time to assigned time + 1 hour
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
        // Keep the current time component when updating the date
        _dueTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, _dueTime.hour, _dueTime.minute);
      });
    }
  }

  Future<void> _pickDueTime() async {
    // Initial time should be relative to _dueTime, but not before _assignedDate
    final TimeOfDay initialTime = TimeOfDay.fromDateTime(
        _dueTime.isAfter(_assignedDate) ? _dueTime : _assignedDate.add(const Duration(minutes: 1)) // ensure it's strictly after assigned date
    );

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime != null) {
      setState(() {
        final newDueDateTime = DateTime(_dueTime.year, _dueTime.month, _dueTime.day, pickedTime.hour, pickedTime.minute);
        // Ensure the new picked time for due date is not before assigned date
        if (newDueDateTime.isBefore(_assignedDate)) {
          _dueTime = _assignedDate.add(const Duration(minutes: 1)); // Smallest possible time after assigned
        } else {
          _dueTime = newDueDateTime;
        }
      });
    }
  }

  void _createTask() async {
    if (_titleController.text.isEmpty || _selectedAssignedToId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields and select an assignee.')));
      return;
    }
    // Final check to ensure due time is not before assigned time
    if (_dueTime.isBefore(_assignedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Due time cannot be before assigned time.')));
      return;
    }

    final userProvider = context.read<UserProvider>();
    final taskProvider = context.read<TaskProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not logged in.')));
      return;
    }

    final selectedAssignee = _assignableUsers.firstWhere(
          (user) => user.email == _selectedAssignedToId,
      orElse: () => throw Exception('Selected assignee not found.'),
    );

    final taskBranchId = selectedAssignee.branchId;


    final newTask = Task(
      id: '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      assignedDate: _assignedDate,
      dueTime: _dueTime,
      assignedById: currentUser.email,
      assignedToId: _selectedAssignedToId!,
      imagesAttached: [],
      imagesCaptured: [],
      yesNoResponse: null,
      comments: '',
      status: 'Assigned',
      branchId: taskBranchId,
      isRepeating: _isRepeating,
    );

    try {
      await taskProvider.createTask(newTask);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task created successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create task: $e')));
      debugPrint('Error creating task: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Task')),
      body: _isLoadingUsers
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Task Title'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (Optional)'),
              maxLines: 3,
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
              onChanged: (value) {
                setState(() {
                  _selectedAssignedToId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text('Assigned Date: ${DateFormat('MMM dd, yyyy').format(_assignedDate)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickAssignedDate,
            ),
            ListTile(
              title: Text('Assigned Time: ${DateFormat('hh:mm a').format(_assignedDate)}'),
              trailing: const Icon(Icons.access_time),
              onTap: _pickAssignedTime,
            ),
            const Divider(), // Visual separator
            ListTile( // NEW: Due Date picker
              title: Text('Due Date: ${DateFormat('MMM dd, yyyy').format(_dueTime)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDueDate,
            ),
            ListTile(
              title: Text('Due Time: ${DateFormat('hh:mm a').format(_dueTime)}'),
              trailing: const Icon(Icons.access_time),
              onTap: _pickDueTime,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Image Required'),
              value: _imageRequired,
              onChanged: (value) {
                setState(() {
                  _imageRequired = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Only Yes/No Required'),
              value: _yesNoRequired,
              onChanged: (value) {
                setState(() {
                  _yesNoRequired = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Repeat Daily'),
              value: _isRepeating,
              onChanged: (value) {
                setState(() {
                  _isRepeating = value;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createTask,
              child: const Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }
}