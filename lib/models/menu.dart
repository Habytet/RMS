// lib/models/menu.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// All Hive-related code has been removed.

class Menu { // No longer extends HiveObject
  String name;
  double price;

  Menu({
    required this.name,
    required this.price,
  });

  /// Convert this Menu to a Firestore map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
    };
  }

  /// Create a Menu from Firestore data
  factory Menu.fromMap(Map<String, dynamic> map) {
    return Menu(
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
