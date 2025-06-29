// lib/common_widgets/task_list_tile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskListTile extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback? onSubmitTap; // For Branch Manager's 'Submit' button

  const TaskListTile({
    super.key,
    required this.task,
    required this.onTap,
    this.onSubmitTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData statusIcon;
    Color statusColor;
    String buttonText = '';
    VoidCallback? buttonAction;

    switch (task.status) {
      case 'Assigned':
        statusIcon = Icons.assignment;
        statusColor = Colors.blue;
        buttonText = 'Start Task'; // Or just 'Submit' if starting is automatic
        buttonAction = onSubmitTap;
        break;
      case 'In Progress':
        statusIcon = Icons.hourglass_empty;
        statusColor = Colors.orange;
        buttonText = 'Submit';
        buttonAction = onSubmitTap;
        break;
      case 'Sent for Approval':
        statusIcon = Icons.pending_actions;
        statusColor = Colors.purple;
        buttonText = 'Pending';
        buttonAction = null;
        break;
      case 'Completed':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        buttonText = 'Completed';
        buttonAction = null;
        break;
      default:
        statusIcon = Icons.info_outline;
        statusColor = Colors.grey;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(task.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Due: ${DateFormat('MMM dd, hh:mm a').format(task.dueTime)}'),
            if (task.description.isNotEmpty)
              Text(task.description, maxLines: 1, overflow: TextOverflow.ellipsis),
            // Show indicators for images/yes-no if relevant
            Row(
              children: [
                if (task.imagesAttached.isNotEmpty) const Icon(Icons.attach_file, size: 16),
                if (task.imagesCaptured.isNotEmpty) const Icon(Icons.camera_alt, size: 16),
                if (task.yesNoResponse != null) Icon(task.yesNoResponse! ? Icons.check_box : Icons.check_box_outline_blank, size: 16),
              ],
            )
          ],
        ),
        trailing: task.status != 'Sent for Approval' && task.status != 'Completed' && onSubmitTap != null
            ? ElevatedButton(
          onPressed: buttonAction,
          child: Text(buttonText),
        )
            : Text(buttonText), // Display status for completed/pending tasks
        onTap: onTap,
      ),
    );
  }
}