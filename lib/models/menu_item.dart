// lib/models/menu_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// All Hive-related code has been removed.

class MenuItem { // No longer extends HiveObject
  String menuName;
  String categoryName;
  String itemName;

  MenuItem({
    required this.menuName,
    required this.categoryName,
    required this.itemName,
  });

  /// Convert this MenuItem to a Firestore map
  Map<String, dynamic> toMap() {
    return {
      'menuName': menuName,
      'categoryName': categoryName,
      'itemName': itemName,
    };
  }

  /// Create a MenuItem from Firestore data
  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      menuName: map['menuName'] ?? '',
      categoryName: map['categoryName'] ?? '',
      itemName: map['itemName'] ?? '',
    );
  }
}
