// lib/screens/branch_manager/branch_manager_task_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../providers/task_provider.dart';
import 'branch_manager_task_submit_dialog.dart';

class BranchManagerTaskDetailScreen extends StatefulWidget {
  final Task task;
  const BranchManagerTaskDetailScreen({super.key, required this.task});

  @override
  State<BranchManagerTaskDetailScreen> createState() => _BranchManagerTaskDetailScreenState();
}

class _BranchManagerTaskDetailScreenState extends State<BranchManagerTaskDetailScreen> {
  late Task _currentTask; // To hold local changes
  List<String> _tempImagesCaptured = []; // For new images to be uploaded
  bool? _tempYesNoResponse; // For new Yes/No response

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task; // Initialize with the passed task
    _tempImagesCaptured = List.from(widget.task.imagesCaptured);
    _tempYesNoResponse = widget.task.yesNoResponse;
  }

  void _saveChanges() async {
    // Only save changes to Firestore without changing status
    // Actual submission happens via the dialog
    await context.read<TaskProvider>().updateTask(
      _currentTask.id,
      {
        'imagesCaptured': _tempImagesCaptured,
        'yesNoResponse': _tempYesNoResponse,
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved!')));
  }

  // Placeholder for image capture logic
  Future<void> _captureImage() async {
    // In a real app, this would use image_picker package
    // For now, simulate adding an image
    final newImage = 'https://example.com/image_${DateTime.now().millisecondsSinceEpoch}.png';
    setState(() {
      _tempImagesCaptured.add(newImage);
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image captured (simulated)!')));
  }

  void _removeImage(int index) {
    setState(() {
      _tempImagesCaptured.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_currentTask.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('Description: ${_currentTask.description}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Text('Assigned Date: ${DateFormat('MMM dd, yyyy').format(_currentTask.assignedDate)}'),
            Text('Due Time: ${DateFormat('hh:mm a').format(_currentTask.dueTime)}'),
            Text('Assigned By: ${_currentTask.assignedById}'), // Will show email/ID, can be mapped to username
            Text('Status: ${_currentTask.status}'),
            const SizedBox(height: 20),

            // Images Attached (from assigner)
            if (_currentTask.imagesAttached.isNotEmpty) ...[
              const Text('Images Attached:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _currentTask.imagesAttached.map((url) => Image.network(url, width: 100, height: 100, fit: BoxFit.cover)).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Yes/No Response
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Yes/No Response:'),
                Switch(
                  value: _tempYesNoResponse ?? false, // Default to false if null
                  onChanged: _currentTask.status == 'Completed' || _currentTask.status == 'Sent for Approval'
                      ? null // Disable if task is already submitted/completed
                      : (value) {
                    setState(() {
                      _tempYesNoResponse = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Images Captured (by assignee)
            const Text('Images Captured:', style: TextStyle(fontWeight: FontWeight.bold)),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
              ),
              itemCount: _tempImagesCaptured.length + 1, // +1 for the add button
              itemBuilder: (context, index) {
                if (index == _tempImagesCaptured.length) {
                  // Add button
                  return _currentTask.status == 'Completed' || _currentTask.status == 'Sent for Approval'
                      ? const SizedBox.shrink() // Hide add button if task is submitted/completed
                      : InkWell(
                    onTap: _captureImage, // Implement actual image capture
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: const Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                    ),
                  );
                }
                // Display captured image
                return Stack(
                  children: [
                    Image.network(_tempImagesCaptured[index], width: 100, height: 100, fit: BoxFit.cover),
                    if (_currentTask.status != 'Completed' && _currentTask.status != 'Sent for Approval')
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            color: Colors.black54,
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),

            // Action Buttons (Submit / Save)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: _currentTask.status == 'Completed' || _currentTask.status == 'Sent for Approval'
                      ? null // Disable if already completed or sent for approval
                      : () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => BranchManagerTaskSubmitDialog(
                        task: _currentTask,
                        capturedImages: _tempImagesCaptured,
                        yesNoResponse: _tempYesNoResponse,
                      ),
                    );
                  },
                  child: const Text('Submit'),
                ),
                OutlinedButton(
                  onPressed: _currentTask.status == 'Completed' || _currentTask.status == 'Sent for Approval'
                      ? null // Disable if already completed or sent for approval
                      : _saveChanges,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}