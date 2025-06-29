// lib/providers/task_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';

class TaskProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String branchId;

  late final Query<Map<String, dynamic>> _tasksCollection;

  List<Task> _tasks = [];
  bool _isLoading = false;
  var _taskListener; // To hold the listener subscription

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;

  TaskProvider({required this.branchId}) {
    if (branchId == 'all') {
      _tasksCollection = _firestore.collectionGroup('tasks');
    } else {
      _tasksCollection = _firestore.collection('branches').doc(branchId).collection('tasks');
    }
    _listenToTasks();
  }

  @override
  void dispose() {
    _taskListener?.cancel(); // Cancel the listener when the provider is disposed
    super.dispose();
  }

  void _listenToTasks() {
    _isLoading = true;
    notifyListeners();

    // Cancel any existing listener before starting a new one
    _taskListener?.cancel();

    debugPrint('TaskProvider for branchId "$branchId" listener starting/restarting...');

    if (branchId == 'all') {
      // --- START: MODIFIED ADMIN LISTENER ---
      _taskListener = _tasksCollection.snapshots().listen((snapshot) {
        debugPrint('Admin TaskProvider Snapshot received! Doc changes: ${snapshot.docChanges.length}');

        for (final change in snapshot.docChanges) {
          final doc = change.doc;
          final data = doc.data();
          if (data == null) continue;

          final extractedBranchId = doc.reference.parent.parent?.id ?? 'unknown';
          final mutableData = Map<String, dynamic>.from(data);
          mutableData['branchId'] = extractedBranchId;
          final task = Task.fromMap(mutableData, doc.id);

          final index = _tasks.indexWhere((t) => t.id == task.id);

          switch (change.type) {
            case DocumentChangeType.added:
              if (index == -1) {
                _tasks.add(task);
                debugPrint('  Admin Task Added: ID=${task.id}, Status=${task.status}');
              }
              break;
            case DocumentChangeType.modified:
              if (index != -1) {
                _tasks[index] = task;
                debugPrint('  Admin Task Modified: ID=${task.id}, Status=${task.status}');
              }
              break;
            case DocumentChangeType.removed:
              if (index != -1) {
                _tasks.removeAt(index);
                debugPrint('  Admin Task Removed: ID=${task.id}');
              }
              break;
          }
        }

        _isLoading = false;
        notifyListeners();
      }, onError: (error) {
        debugPrint('Error listening to all tasks: $error');
        _isLoading = false;
        notifyListeners();
      });
      // --- END: MODIFIED ADMIN LISTENER ---
    } else {
      _taskListener = _tasksCollection.snapshots().listen((snapshot) {
        debugPrint('Staff TaskProvider Snapshot received for branch "$branchId"! Docs: ${snapshot.docs.length}');
        _tasks = snapshot.docs.map((doc) => Task.fromMap(doc.data(), doc.id)).toList();
        _isLoading = false;
        notifyListeners();
      }, onError: (error) {
        debugPrint('Error listening to tasks for branch $branchId: $error');
        _isLoading = false;
        notifyListeners();
      });
    }
  }

  Future<void> createTask(Task task) async {
    debugPrint('Attempting to create task: ${task.title} for branch ${task.branchId}');
    try {
      await _firestore.collection('branches').doc(task.branchId).collection('tasks').add(task.toMap());
      debugPrint('Task "${task.title}" created successfully!');
    } catch (e) {
      debugPrint('ERROR: Failed to create task "${task.title}": $e');
      rethrow;
    }
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> updates, {String? taskBranchId}) async {
    debugPrint('Attempting to update task ID: $taskId with updates: $updates');

    String branchIdForUpdate;

    if (taskBranchId != null) {
      branchIdForUpdate = taskBranchId;
    } else {
      final taskToUpdate = _tasks.firstWhere((t) => t.id == taskId, orElse: () {
        throw Exception('Task with ID $taskId not found locally for update. Cannot determine branch.');
      });
      branchIdForUpdate = taskToUpdate.branchId;

      // Logic to add timestamps based on local data
      if (updates.containsKey('status')) {
        final newStatus = updates['status'];
        if (newStatus == 'In Progress' && taskToUpdate.startedAt == null) {
          updates['startedAt'] = FieldValue.serverTimestamp();
        } else if (newStatus == 'Sent for Approval' && taskToUpdate.completedAt == null) {
          updates['completedAt'] = FieldValue.serverTimestamp();
        }
      }
    }

    try {
      await _firestore.collection('branches').doc(branchIdForUpdate).collection('tasks').doc(taskId).update(updates);
      debugPrint('Task ID $taskId updated successfully!');
    } catch (e) {
      debugPrint('ERROR: Failed to update task ID $taskId on branch $branchIdForUpdate: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    debugPrint('Attempting to delete task ID: $taskId');
    final taskToDelete = _tasks.firstWhere((t) => t.id == taskId, orElse: () {
      throw Exception('Task with ID $taskId not found locally for delete. Cannot proceed.');
    });
    try {
      await _firestore.collection('branches').doc(taskToDelete.branchId).collection('tasks').doc(taskId).delete();
      debugPrint('Task ID $taskId deleted successfully!');
    } catch (e) {
      debugPrint('ERROR: Failed to delete task ID $taskId: $e');
      rethrow;
    }
  }

  List<Task> getTasksForUserAndStatus(String userId, String status) {
    return _tasks
        .where((task) => task.assignedToId == userId && task.status == status)
        .toList()
      ..sort((a, b) => a.dueTime.compareTo(b.dueTime));
  }

  List<Task> getAllTasksForUser(String userId) {
    return _tasks
        .where((task) => task.assignedToId == userId)
        .toList()
      ..sort((a, b) => a.dueTime.compareTo(b.dueTime));
  }

  List<Task> getTasksForSelectedStaff(String selectedStaffId, String statusFilter) {
    return _tasks.where((task) {
      bool matchesStaff = (selectedStaffId == 'all' || task.assignedToId == selectedStaffId);
      bool matchesStatus = (task.status == statusFilter);
      return matchesStaff && matchesStatus;
    }).toList();
  }
}