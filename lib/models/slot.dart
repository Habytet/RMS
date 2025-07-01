// lib/models/slot.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// All Hive-related code has been removed.

class Slot {
  // No longer extends HiveObject
  String hallName;
  String label;
  bool isSelected;

  Slot({required this.hallName, required this.label, this.isSelected = false});

  /// Convert this Slot to a Firestore map
  Map<String, dynamic> toMap() {
    return {
      'hallName': hallName,
      'label': label,
    };
  }

  /// Create a Slot from Firestore data
  factory Slot.fromMap(Map<String, dynamic> map) {
    return Slot(
      hallName: map['hallName'] ?? '',
      label: map['label'] ?? '',
    );
  }
}
