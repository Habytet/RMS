// lib/models/hall.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:token_manager/models/slot.dart';

// All Hive-related code has been removed.

class HallInfo {
  String name;
  List<Slot> slots;

  HallInfo({required this.name, required this.slots});

  factory HallInfo.fromJson(Map<String, dynamic> json) {
    return HallInfo(
      name: json['name'],
      slots: (json['slots'] as List)
          .map((slot) => Slot.fromMap(slot))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slots': slots.map((s) => s.toMap()).toList(),
    };
  }
}

class Hall {
  // No longer extends HiveObject
  String name;
  bool isSelected;

  Hall({required this.name, this.isSelected = false});

  /// Convert this Hall to a Firestore map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }

  /// Create a Hall from Firestore data
  factory Hall.fromMap(Map<String, dynamic> map) {
    return Hall(
      name: map['name'] ?? '',
    );
  }
}
