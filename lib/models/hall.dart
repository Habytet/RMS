// lib/models/hall.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// All Hive-related code has been removed.

class Hall { // No longer extends HiveObject
  String name;

  Hall({required this.name});

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
