// lib/screens/manager_admin/staff_tasks_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/task_provider.dart';
import '../../models/app_user.dart'; // To get staff list
import '../../models/task.dart';
import '../../common_widgets/task_list_tile.dart';

class StaffTasksScreen extends StatefulWidget {
  const StaffTasksScreen({super.key});

  @override
  State<StaffTasksScreen> createState() => _StaffTasksScreenState();
}

class _StaffTasksScreenState extends State<StaffTasksScreen> {
  String? _selectedStaffId; // Stores selected staff user ID
  List<AppUser> _staffUsers = []; // Stores the list of assignable staff
  bool _isStaffLoading = true;

  @override
  void initState() {
    super.initState();
    // No need to call _fetchStaffUsers here as it's watched in build and will update
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final currentUser = userProvider.currentUser;
    // NEW: Watch for changes in all users and their loading state
    final allUsers = userProvider.users;
    final isLoadingAllUsers = userProvider.isLoadingUsers;

    if (currentUser == null) {
      return const Center(child: Text('User not logged in.'));
    }

    // Filter staff users based on current user's branch and capabilities
    // This logic runs every time build is called, which is fine as `allUsers` is reactive
    List<AppUser> currentBrowsableStaff = [];
    if (!isLoadingAllUsers) {
      final currentUserBranchId = userProvider.currentBranchId;
      currentBrowsableStaff = allUsers
          .where((u) =>
                  (currentUser.isAdmin || u.branchId == currentUserBranchId) &&
                  u.email !=
                      currentUser.email && // Exclude current manager/admin
                  u.canViewOwnTasks // Only show users who can view their own tasks (i.e., staff)
              )
          .toList();

      if (currentBrowsableStaff.isNotEmpty && _selectedStaffId == null) {
        _selectedStaffId =
            currentBrowsableStaff.first.email; // Default to first staff member
      } else if (currentBrowsableStaff.isEmpty && _selectedStaffId != null) {
        // If selected staff is no longer in list, clear selection
        _selectedStaffId = null;
      }
    }

    if (isLoadingAllUsers ||
        currentUser == null ||
        _selectedStaffId == null && currentBrowsableStaff.isNotEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (currentBrowsableStaff.isEmpty) {
      return const Center(child: Text('No staff users available to manage.'));
    }

    // Get tasks for the selected staff member
    final assignedTasks = _selectedStaffId != null
        ? taskProvider.getTasksForSelectedStaff(_selectedStaffId!, 'Assigned')
        : [];
    final inProgressTasks = _selectedStaffId != null
        ? taskProvider.getTasksForSelectedStaff(
            _selectedStaffId!, 'In Progress')
        : [];
    final completedTasks = _selectedStaffId != null
        ? taskProvider.getTasksForSelectedStaff(_selectedStaffId!, 'Completed')
        : [];
    final sentForApprovalTasks = _selectedStaffId != null
        ? taskProvider.getTasksForSelectedStaff(
            _selectedStaffId!, 'Sent for Approval')
        : [];

    final combinedAssigned = [...assignedTasks].toList()
      ..sort((a, b) => a.dueTime.compareTo(b.dueTime));
    final combinedInProgress = [...inProgressTasks].toList()
      ..sort((a, b) => a.dueTime.compareTo(b.dueTime));
    final combinedCompleted = [...sentForApprovalTasks, ...completedTasks]
        .toList()
      ..sort((a, b) => b.dueTime.compareTo(a.dueTime)); // Newest first

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Staff\'s Tasks'),
          actions: [
            if (currentUser.canCreateTasks) // Only show if user has permission
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  // Pass the currently selected staff ID to pre-fill the assign-to field
                  Navigator.pushNamed(
                      context, '/tasks/manager_admin/create_task',
                      arguments: {'assignedToId': _selectedStaffId});
                },
                tooltip: 'Create New Task',
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Assigned'),
              Tab(text: 'In Progress'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: DropdownButtonFormField<String>(
                value: _selectedStaffId,
                hint: const Text('Choose User'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: currentBrowsableStaff.map((user) {
                  return DropdownMenuItem(
                    value: user.email, // Use email as unique ID
                    child: Text(
                        user.username.isEmpty ? user.email : user.username),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStaffId = value;
                  });
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Assigned Tab
                  taskProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : combinedAssigned.isEmpty
                          ? const Center(
                              child: Text('No assigned tasks for this user.'))
                          : ListView.builder(
                              itemCount: combinedAssigned.length,
                              itemBuilder: (context, index) {
                                final task = combinedAssigned[index];
                                return TaskListTile(
                                  task: task,
                                  onTap: () {
                                    Navigator.pushNamed(context,
                                        '/tasks/manager_admin/assigned_task_detail',
                                        arguments: {'task': task});
                                  },
                                );
                              },
                            ),
                  // In Progress Tab
                  taskProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : combinedInProgress.isEmpty
                          ? const Center(
                              child:
                                  Text('No in progress tasks for this user.'))
                          : ListView.builder(
                              itemCount: combinedInProgress.length,
                              itemBuilder: (context, index) {
                                final task = combinedInProgress[index];
                                return TaskListTile(
                                  task: task,
                                  onTap: () {
                                    Navigator.pushNamed(context,
                                        '/tasks/manager_admin/inprogress_task_detail',
                                        arguments: {'task': task});
                                  },
                                );
                              },
                            ),
                  // Completed Tab
                  taskProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : combinedCompleted.isEmpty
                          ? const Center(
                              child: Text('No completed tasks for this user.'))
                          : ListView.builder(
                              itemCount: combinedCompleted.length,
                              itemBuilder: (context, index) {
                                final task = combinedCompleted[index];
                                return TaskListTile(
                                  task: task,
                                  onTap: () {
                                    Navigator.pushNamed(context,
                                        '/tasks/manager_admin/completed_task_detail',
                                        arguments: {'task': task});
                                  },
                                );
                              },
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
