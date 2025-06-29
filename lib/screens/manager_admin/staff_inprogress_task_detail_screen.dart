// lib/screens/manager_admin/staff_inprogress_task_detail_screen.dart
import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../providers/user_provider.dart';
import '../../models/app_user.dart'; // Make sure AppUser is imported

class StaffInProgressTaskDetailScreen extends StatefulWidget {
  final Task task;
  const StaffInProgressTaskDetailScreen({super.key, required this.task});

  @override
  State<StaffInProgressTaskDetailScreen> createState() =>
      _StaffInProgressTaskDetailScreenState();
}

class _StaffInProgressTaskDetailScreenState
    extends State<StaffInProgressTaskDetailScreen> {
  Timer? _displayTimer;
  Duration _elapsedDuration = Duration.zero;
  late Task _currentTask;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    _startOrUpdateTimer();
  }

  @override
  void didUpdateWidget(covariant StaffInProgressTaskDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.id != _currentTask.id ||
        widget.task.status != _currentTask.status ||
        widget.task.startedAt != _currentTask.startedAt ||
        widget.task.completedAt != _currentTask.completedAt) {
      setState(() {
        _currentTask = widget.task;
      });
      _startOrUpdateTimer();
    }
  }

  void _startOrUpdateTimer() {
    _displayTimer?.cancel();

    if (_currentTask.status == 'In Progress' &&
        _currentTask.startedAt != null) {
      _displayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _elapsedDuration =
                DateTime.now().difference(_currentTask.startedAt!);
          });
        }
      });
    } else if (_currentTask.startedAt != null &&
        _currentTask.completedAt != null) {
      setState(() {
        _elapsedDuration =
            _currentTask.completedAt!.difference(_currentTask.startedAt!);
      });
    } else {
      setState(() {
        _elapsedDuration = Duration.zero;
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
  void dispose() {
    _displayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    // Fetch assignee and assigner details if needed for display
    // FIX: Provide all required AppUser constructor parameters explicitly in orElse
    final assignedToUser = userProvider.users.firstWhere(
      (u) => u.email == _currentTask.assignedToId,
      orElse: () => AppUser(
        username: 'Unknown User',
        email: _currentTask.assignedToId,
        branchId: '', // Default to empty string for unknown branch
        // Explicitly provide all boolean fields, though they have defaults, for clarity/strictness
        podiumEnabled: false, waiterEnabled: false, customerEnabled: false,
        banquetBookingEnabled: false, banquetReportsEnabled: false,
        queueReportsEnabled: false,
        adminDisplayEnabled: false, banquetSetupEnabled: false,
        userManagementEnabled: false,
        menuManagementEnabled: false, branchManagementEnabled: false,
        canSubmitTasks: false, canViewStaffTasks: false,
        canCreateTasks: false, canEditAssignedTasks: false,
        canReassignTasks: false,
      ),
    );
    final assignedByUser = userProvider.users.firstWhere(
      (u) => u.email == _currentTask.assignedById,
      orElse: () => AppUser(
        username: 'Unknown User',
        email: _currentTask.assignedById,
        branchId: '', // Default to empty string for unknown branch
        // Explicitly provide all boolean fields
        podiumEnabled: false, waiterEnabled: false, customerEnabled: false,
        banquetBookingEnabled: false, banquetReportsEnabled: false,
        queueReportsEnabled: false,
        adminDisplayEnabled: false, banquetSetupEnabled: false,
        userManagementEnabled: false,
        menuManagementEnabled: false, branchManagementEnabled: false,
        canSubmitTasks: false, canViewStaffTasks: false,
        canCreateTasks: false, canEditAssignedTasks: false,
        canReassignTasks: false,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(_currentTask.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Timer display at the top
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              decoration: BoxDecoration(
                color: _currentTask.status == 'In Progress'
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _currentTask.status == 'In Progress'
                        ? 'Time Elapsed:'
                        : 'Total Time:', // Will show 'Total Time' if status changes during view
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    _formatDuration(_elapsedDuration),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _currentTask.status == 'In Progress'
                          ? Colors.blue
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('Description: ${_currentTask.description}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Text(
                'Assigned Date: ${DateFormat('MMM dd,EEEE').format(_currentTask.assignedDate)}'),
            Text(
                'Assigned Time: ${DateFormat('hh:mm a').format(_currentTask.assignedDate)}'),
            Text(
                'Due Time: ${DateFormat('MMM dd,EEEE hh:mm a').format(_currentTask.dueTime)}'),
            Text(
                'Assigned By: ${assignedByUser.username.isEmpty ? assignedByUser.email : assignedByUser.username}'),
            Text(
                'Assigned To: ${assignedToUser.username.isEmpty ? assignedToUser.email : assignedToUser.username}'),
            Text('Status: ${_currentTask.status}'),
            Text('Repeats Daily: ${_currentTask.isRepeating ? 'Yes' : 'No'}'),
            Text(
                'Started At: ${_currentTask.startedAt != null ? DateFormat('MMM dd, hh:mm:ss a').format(_currentTask.startedAt!) : 'N/A'}'),
            const SizedBox(height: 20),

            const Text('Images Attached:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (_currentTask.imagesAttached.isEmpty)
              const Text('No images attached by assigner.')
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _currentTask.imagesAttached
                    .map((url) => Image.network(url,
                        width: 100, height: 100, fit: BoxFit.cover))
                    .toList(),
              ),
            const SizedBox(height: 20),

            const Text('Images Received (from assignee):',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (_currentTask.imagesCaptured.isEmpty)
              const Text('No images captured by assignee yet.')
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _currentTask.imagesCaptured
                    .map((url) => Image.network(url,
                        width: 100, height: 100, fit: BoxFit.cover))
                    .toList(),
              ),
            const SizedBox(height: 20),

            Text(
                'Yes/No Response: ${_currentTask.yesNoResponse == null ? 'Pending' : (_currentTask.yesNoResponse! ? 'Yes' : 'No')}'),
            const SizedBox(height: 10),
            Text(
                'Comments: ${_currentTask.comments.isEmpty ? 'No comments' : _currentTask.comments}'),
          ],
        ),
      ),
    );
  }
}
