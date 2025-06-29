// lib/screens/branch_manager/branch_manager_tasks_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/task.dart';
import '../../common_widgets/task_list_tile.dart';
import 'branch_manager_task_submit_dialog.dart';
import 'branch_manager_task_detail_screen.dart'; // Import detail screen

class BranchManagerTasksScreen extends StatefulWidget {
  const BranchManagerTasksScreen({super.key});

  @override
  State<BranchManagerTasksScreen> createState() => _BranchManagerTasksScreenState();
}

class _BranchManagerTasksScreenState extends State<BranchManagerTasksScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
          // Force a rebuild to re-evaluate the DateTime.now() condition in filters
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      return const Center(child: Text('User not logged in.'));
    }

    final currentTime = DateTime.now();

    final assignedTasksRaw = taskProvider.getTasksForUserAndStatus(currentUser.email, 'Assigned');
    final inProgressTasksRaw = taskProvider.getTasksForUserAndStatus(currentUser.email, 'In Progress');

    final assignedTasksVisible = assignedTasksRaw.where((task) {
      return task.assignedDate.isBefore(currentTime) || task.assignedDate.isAtSameMomentAs(currentTime);
    }).toList();

    final combinedInProgress = [...assignedTasksVisible, ...inProgressTasksRaw].toList()
      ..sort((a, b) => a.dueTime.compareTo(b.dueTime));

    final completedTasks = taskProvider.getTasksForUserAndStatus(currentUser.email, 'Completed');
    final sentForApprovalTasks = taskProvider.getTasksForUserAndStatus(currentUser.email, 'Sent for Approval');
    final combinedCompleted = [...sentForApprovalTasks, ...completedTasks].toList()
      ..sort((a, b) => b.dueTime.compareTo(a.dueTime));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tasks'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'In Progress'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // In Progress Tab
            taskProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : combinedInProgress.isEmpty
                ? const Center(child: Text('No tasks in progress.'))
                : ListView.builder(
              itemCount: combinedInProgress.length,
              itemBuilder: (context, index) {
                final task = combinedInProgress[index];
                return TaskListTile(
                  task: task,
                  onTap: () async {
                    // If task is still 'Assigned' and its time has hit, update status to 'In Progress'
                    // TaskProvider will set startedAt automatically
                    if (task.status == 'Assigned' && (task.assignedDate.isBefore(currentTime) || task.assignedDate.isAtSameMomentAs(currentTime))) {
                      await taskProvider.updateTask(task.id, {'status': 'In Progress'});
                    }
                    // Navigate to detail screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BranchManagerTaskDetailScreen(task: task),
                      ),
                    );
                  },
                  onSubmitTap: () {
                    // FIX: Removed the immediate update to 'In Progress'.
                    // The submission dialog is now responsible for setting the final status to 'Sent for Approval'.
                    // This prevents a race condition where the admin's view might catch the intermediate 'In Progress' state
                    // but miss the final 'Sent for Approval' state.

                    // Directly show the comments and submission dialog.
                    showDialog(
                      context: context,
                      builder: (dialogContext) => BranchManagerTaskSubmitDialog(
                        task: task,
                        capturedImages: task.imagesCaptured,
                        yesNoResponse: task.yesNoResponse,
                      ),
                    );
                  },
                );
              },
            ),
            // Completed Tab
            taskProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : combinedCompleted.isEmpty
                ? const Center(child: Text('No completed tasks.'))
                : ListView.builder(
              itemCount: combinedCompleted.length,
              itemBuilder: (context, index) {
                final task = combinedCompleted[index];
                return TaskListTile(
                  task: task,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BranchManagerTaskDetailScreen(task: task),
                      ),
                    );
                  },
                  onSubmitTap: null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}