// lib/screens/manager_admin/staff_completed_task_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../models/app_user.dart'; // NEW: For UserProvider
import '../../providers/task_provider.dart';
import '../../providers/user_provider.dart'; // NEW: For UserProvider
import 'reassign_task_dialog.dart';

class StaffCompletedTaskDetailScreen extends StatefulWidget { // Changed to StatefulWidget
  final Task task;
  const StaffCompletedTaskDetailScreen({super.key, required this.task});

  @override
  State<StaffCompletedTaskDetailScreen> createState() => _StaffCompletedTaskDetailScreenState();
}

class _StaffCompletedTaskDetailScreenState extends State<StaffCompletedTaskDetailScreen> {
  late Task _currentTask; // To update if task changes via provider
  Duration _totalDuration = Duration.zero; // NEW: To store final duration

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    _calculateDuration();
  }

  @override
  void didUpdateWidget(covariant StaffCompletedTaskDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.id != _currentTask.id ||
        widget.task.startedAt != _currentTask.startedAt ||
        widget.task.completedAt != _currentTask.completedAt) {
      setState(() {
        _currentTask = widget.task;
      });
      _calculateDuration(); // Recalculate if underlying task data changes
    }
  }

  void _calculateDuration() {
    if (_currentTask.startedAt != null && _currentTask.completedAt != null) {
      setState(() {
        _totalDuration = _currentTask.completedAt!.difference(_currentTask.startedAt!);
      });
    } else {
      setState(() {
        _totalDuration = Duration.zero;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final canReassign = userProvider.currentUser?.canReassignTasks ?? false;

    // Fetch assignee and assigner details if needed for display
    final assignedToUser = userProvider.users.firstWhere(
          (u) => u.email == _currentTask.assignedToId,
      orElse: () => AppUser(username: 'Unknown User', email: _currentTask.assignedToId, branchId: ''),
    );
    final assignedByUser = userProvider.users.firstWhere(
          (u) => u.email == _currentTask.assignedById,
      orElse: () => AppUser(username: 'Unknown User', email: _currentTask.assignedById, branchId: ''),
    );

    return Scaffold(
      appBar: AppBar(title: Text(_currentTask.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // NEW: Total Time display at the top
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Time:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    _formatDuration(_totalDuration),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('Description: ${_currentTask.description}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Text('Assigned Date: ${DateFormat('MMM dd,EEEE').format(_currentTask.assignedDate)}'),
            Text('Assigned Time: ${DateFormat('hh:mm a').format(_currentTask.assignedDate)}'),
            Text('Due Time: ${DateFormat('MMM dd,EEEE hh:mm a').format(_currentTask.dueTime)}'),
            Text('Assigned By: ${assignedByUser.username.isEmpty ? assignedByUser.email : assignedByUser.username}'),
            Text('Assigned To: ${assignedToUser.username.isEmpty ? assignedToUser.email : assignedToUser.username}'),
            Text('Status: ${_currentTask.status}'),
            Text('Repeats Daily: ${_currentTask.isRepeating ? 'Yes' : 'No'}'),
            Text('Started At: ${_currentTask.startedAt != null ? DateFormat('MMM dd, hh:mm:ss a').format(_currentTask.startedAt!) : 'N/A'}'), // NEW
            Text('Completed At: ${_currentTask.completedAt != null ? DateFormat('MMM dd, hh:mm:ss a').format(_currentTask.completedAt!) : 'N/A'}'), // NEW
            const SizedBox(height: 20),

            const Text('Images Attached:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_currentTask.imagesAttached.isEmpty)
              const Text('No images attached by assigner.')
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _currentTask.imagesAttached.map((url) => Image.network(url, width: 100, height: 100, fit: BoxFit.cover)).toList(),
              ),
            const SizedBox(height: 20),

            const Text('Images Captured:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_currentTask.imagesCaptured.isEmpty)
              const Text('No images captured by assignee.')
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _currentTask.imagesCaptured.map((url) => Image.network(url, width: 100, height: 100, fit: BoxFit.cover)).toList(),
              ),
            const SizedBox(height: 20),

            Text('Yes/No Response: ${_currentTask.yesNoResponse == null ? 'N/A' : (_currentTask.yesNoResponse! ? 'Yes' : 'No')}'),
            const SizedBox(height: 10),
            Text('Comments: ${_currentTask.comments.isEmpty ? 'No comments' : _currentTask.comments}'),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (canReassign)
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => ReassignTaskDialog(task: _currentTask),
                      );
                    },
                    child: const Text('Reassign'),
                  ),
                ElevatedButton(
                  onPressed: _currentTask.status == 'Completed'
                      ? null // Disable if already genuinely completed
                      : () async {
                    // Mark task as truly completed/approved
                    await context.read<TaskProvider>().updateTask(_currentTask.id, {'status': 'Completed'});
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task marked as completed!')));
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Submit (Final Approve)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}