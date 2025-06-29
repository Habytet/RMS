// lib/models/task.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  String id; // Document ID from Firestore
  String title;
  String description;
  DateTime assignedDate; // Stores both date and assigned time
  DateTime dueTime; // Stores both date and due time
  String assignedById; // User ID of the assigner
  String assignedToId; // User ID of the assignee
  List<String> imagesAttached; // URLs of images attached by assigner
  List<String> imagesCaptured; // URLs of images captured by assignee
  bool? yesNoResponse; // Nullable for pending, true/false for response
  String comments; // Comments from assignee during submission
  String status; // 'Assigned', 'In Progress', 'Sent for Approval', 'Completed'
  String branchId; // Branch this task belongs to
  bool isRepeating; // Field for repeat toggle
  DateTime? startedAt; // NEW: When the task officially started being "In Progress"
  DateTime? completedAt; // NEW: When the task was submitted by the assignee

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedDate,
    required this.dueTime,
    required this.assignedById,
    required this.assignedToId,
    this.imagesAttached = const [],
    this.imagesCaptured = const [],
    this.yesNoResponse,
    this.comments = '',
    required this.status,
    required this.branchId,
    this.isRepeating = false,
    this.startedAt, // NEW
    this.completedAt, // NEW
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'assignedDate': Timestamp.fromDate(assignedDate),
      'dueTime': Timestamp.fromDate(dueTime),
      'assignedById': assignedById,
      'assignedToId': assignedToId,
      'imagesAttached': imagesAttached,
      'imagesCaptured': imagesCaptured,
      'yesNoResponse': yesNoResponse,
      'comments': comments,
      'status': status,
      'branchId': branchId,
      'isRepeating': isRepeating,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null, // NEW
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null, // NEW
    };
  }

  factory Task.fromMap(Map<String, dynamic> map, String id) {
    return Task(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      assignedDate: (map['assignedDate'] as Timestamp).toDate(),
      dueTime: (map['dueTime'] as Timestamp).toDate(),
      assignedById: map['assignedById'] ?? '',
      assignedToId: map['assignedToId'] ?? '',
      imagesAttached: List<String>.from(map['imagesAttached'] ?? []),
      imagesCaptured: List<String>.from(map['imagesCaptured'] ?? []),
      yesNoResponse: map['yesNoResponse'],
      comments: map['comments'] ?? '',
      status: map['status'] ?? 'Assigned',
      branchId: map['branchId'] ?? '',
      isRepeating: map['isRepeating'] ?? false,
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(), // NEW
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(), // NEW
    );
  }
}